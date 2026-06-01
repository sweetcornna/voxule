import Foundation

/// 随 StateDigest 一同上行的**非敏感**上下文（架构文档 §7）。
/// 只含胶囊库元数据与粗粒度地名 —— 不含音频、不含原始体征、不含精确坐标。
public struct AgentContext: Sendable, Codable {
    /// 候选情绪胶囊的元数据（id + 标题 + 标签 + 粗地名）。
    public struct CapsuleMeta: Sendable, Codable {
        public let id: String
        public let title: String
        public let tags: [String]
        public let placeName: String?
        public init(id: String, title: String, tags: [String], placeName: String?) {
            self.id = id; self.title = title; self.tags = tags; self.placeName = placeName
        }
    }
    public let candidates: [CapsuleMeta]
    /// 当前浮现频率档（轻轻地/偶尔/关）。
    public let cadence: String

    public init(candidates: [CapsuleMeta], cadence: String) {
        self.candidates = candidates
        self.cadence = cadence
    }

    public static let empty = AgentContext(candidates: [], cadence: "occasionally")
}

/// serverless 代理客户端。真实现只跟自建代理通信，绝不内嵌大模型 API key。
public protocol RemoteModelClient: Sendable {
    /// 开一轮情绪浮现会话；上行 StateDigest + 非敏感上下文。
    func startSurfacing(digest: StateDigest, context: AgentContext) async throws -> AgentReply
    /// 把上一轮工具结果回传，取 agent 下一轮回复。
    func continueTurn(_ turn: AgentTurn) async throws -> AgentReply
}

public enum RemoteModelError: Error, Sendable {
    case transport(String)
    case badStatus(Int)
    case decoding(String)
    case sessionExhausted   // 假实现脚本用尽
}

/// 真实现 —— 调自建 serverless 代理。
/// 代理地址通过初始化注入；**API key 不在客户端，由代理持有**。
///
/// 鉴权（D2）：每次请求带 `Authorization: Bearer <deviceToken>`；
/// token 由初始化注入，**绝不硬编码**（由 voxuleApp / AppDependencies 装配）。
///
/// 多轮历史（C3）：代理无状态，对话历史由**设备**累积并整轮重发。
/// `startSurfacing` 建初始 user 消息并记下；`continueTurn` 追加上一轮 assistant
/// 回复与本轮 tool-results user 消息，再重发**完整** messages 数组。
public final class HTTPRemoteModelClient: RemoteModelClient, @unchecked Sendable {
    private let proxyURL: URL
    private let session: URLSession
    /// 设备鉴权 token —— 注入，不硬编码。随 `Authorization: Bearer` 头上行。
    private let deviceToken: String
    /// 一次浮现会话的 ID，便于日志关联（代理仍无状态 —— ID 仅由请求体携带）。
    private let sessionID = UUID().uuidString

    /// 跨网络的一条对话消息（对应代理 / Anthropic Messages API 的 {role, content}）。
    private struct Message: Codable {
        let role: String   // "user" | "assistant"
        let content: String
    }

    private struct RequestBody: Codable {
        let sessionID: String
        let messages: [Message]
    }

    /// 设备累积的完整对话历史 —— 每轮整体重发（C3）。
    /// 串行访问：AgentGateway 在 @MainActor 上顺序 await，不会并发改它。
    private var messages: [Message] = []
    /// 上一轮 agent 回复 —— 下一轮要把它作为 assistant 消息回填进历史。
    private var lastReply: AgentReply?

    public init(proxyURL: URL, deviceToken: String, session: URLSession = .shared) {
        self.proxyURL = proxyURL
        self.deviceToken = deviceToken
        self.session = session
    }

    public func startSurfacing(digest: StateDigest, context: AgentContext) async throws -> AgentReply {
        // 建初始 user 消息（digest + 非敏感上下文整形成文本），作为历史第一条。
        let userContent =
            "状态摘要：\(encodeJSONString(digest))\n" +
            "候选胶囊：\(encodeJSONString(context.candidates))\n" +
            "浮现频率档：\(context.cadence)\n" +
            "请决定是否浮现，并按约定 JSON 输出。"
        messages = [Message(role: "user", content: userContent)]
        let reply = try await post(messages)
        lastReply = reply
        return reply
    }

    public func continueTurn(_ turn: AgentTurn) async throws -> AgentReply {
        // 把上一轮 assistant 回复回填进历史（按模型当初输出的 JSON 形态），
        // 再追加本轮 tool-results 的 user 消息 —— 多轮工具循环不再丢上下文（C3）。
        if let prior = lastReply {
            messages.append(Message(role: "assistant", content: encodeJSONString(prior)))
        }
        let userContent =
            "上一轮工具结果：\(encodeJSONString(turn.toolResults))\n" +
            "请给出最终决定，并按约定 JSON 输出。"
        messages.append(Message(role: "user", content: userContent))
        let reply = try await post(messages)
        lastReply = reply
        return reply
    }

    /// 把 Encodable 编码成紧凑 JSON 字符串（嵌进对话消息正文）。失败回退空对象。
    private func encodeJSONString<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    private func post(_ messages: [Message]) async throws -> AgentReply {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        // 后台任务运行时间有限，给代理调用一个较短超时，超时即走 hold 兜底。
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 设备鉴权（D2）：带 Bearer token；大模型 API key 仍由代理持有，客户端不碰。
        request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(sessionID: sessionID, messages: messages)
        )
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RemoteModelError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw RemoteModelError.transport("非 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RemoteModelError.badStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(AgentReply.self, from: data)
        } catch {
            throw RemoteModelError.decoding(error.localizedDescription)
        }
    }
}

/// 假实现 —— 顺序回放脚本化的 AgentReply 序列，供 AgentGateway 闭环端到端测试。
public final class FakeRemoteModelClient: RemoteModelClient, @unchecked Sendable {
    private var replies: [AgentReply]
    private var cursor = 0
    /// 最近一次发出的请求体（编码成 JSON 字符串），供「不泄漏 key」断言。
    public private(set) var lastRequestBody: String?

    public init(replies: [AgentReply]) {
        self.replies = replies
    }

    public func startSurfacing(digest: StateDigest, context: AgentContext) async throws -> AgentReply {
        struct StartBody: Codable { let digest: StateDigest; let context: AgentContext }
        lastRequestBody = String(
            data: (try? JSONEncoder().encode(StartBody(digest: digest, context: context))) ?? Data(),
            encoding: .utf8
        )
        return try next()
    }

    public func continueTurn(_ turn: AgentTurn) async throws -> AgentReply {
        lastRequestBody = String(
            data: (try? JSONEncoder().encode(turn)) ?? Data(), encoding: .utf8
        )
        return try next()
    }

    private func next() throws -> AgentReply {
        guard cursor < replies.count else { throw RemoteModelError.sessionExhausted }
        defer { cursor += 1 }
        return replies[cursor]
    }
}
