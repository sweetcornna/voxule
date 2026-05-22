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
public final class HTTPRemoteModelClient: RemoteModelClient, @unchecked Sendable {
    private let proxyURL: URL
    private let session: URLSession
    /// 一次浮现会话的 ID，让代理把多轮请求串起来（代理仍无状态 —— ID 仅由请求体携带）。
    private let sessionID = UUID().uuidString

    public init(proxyURL: URL, session: URLSession = .shared) {
        self.proxyURL = proxyURL
        self.session = session
    }

    public func startSurfacing(digest: StateDigest, context: AgentContext) async throws -> AgentReply {
        struct StartBody: Codable {
            let sessionID: String
            let phase: String
            let digest: StateDigest
            let context: AgentContext
        }
        return try await post(StartBody(
            sessionID: sessionID, phase: "start", digest: digest, context: context
        ))
    }

    public func continueTurn(_ turn: AgentTurn) async throws -> AgentReply {
        struct ContinueBody: Codable {
            let sessionID: String
            let phase: String
            let turn: AgentTurn
        }
        return try await post(ContinueBody(
            sessionID: sessionID, phase: "continue", turn: turn
        ))
    }

    private func post<Body: Encodable>(_ body: Body) async throws -> AgentReply {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 注意：这里没有 Authorization 头 —— key 由代理持有，客户端不碰。
        request.httpBody = try JSONEncoder().encode(body)
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
