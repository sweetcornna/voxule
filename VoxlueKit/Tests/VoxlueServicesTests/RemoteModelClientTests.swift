import Testing
import Foundation
@testable import VoxlueServices

@Test func toolCallDecodesSurfaceCapsule() throws {
    let json = """
    { "name": "surfaceCapsule", "arguments": { "capsuleID": "\(UUID().uuidString)" } }
    """
    let call = try JSONDecoder().decode(AgentToolCall.self, from: Data(json.utf8))
    #expect(call.name == .surfaceCapsule)
    #expect(call.arguments["capsuleID"] != nil)
}

@Test func toolCallDecodesAdjustCadence() throws {
    let json = #"{ "name": "adjustCadence", "arguments": { "cadence": "rarely" } }"#
    let call = try JSONDecoder().decode(AgentToolCall.self, from: Data(json.utf8))
    #expect(call.name == .adjustCadence)
    #expect(call.arguments["cadence"] == "rarely")
}

@Test func agentTurnEncodesToolResults() throws {
    let turn = AgentTurn(
        toolResults: [ToolResult(name: .searchCapsules, output: #"["a","b"]"#)],
        finished: false
    )
    let data = try JSONEncoder().encode(turn)
    let decoded = try JSONDecoder().decode(AgentTurn.self, from: data)
    #expect(decoded.toolResults.first?.name == .searchCapsules)
    #expect(decoded.finished == false)
}

@Test func fakeClientReplaysScriptedReplies() async throws {
    let cid = UUID().uuidString
    let scripted: [AgentReply] = [
        AgentReply(toolCalls: [AgentToolCall(name: .searchCapsules,
                                             arguments: ["query": "calm"])], finished: false),
        AgentReply(toolCalls: [AgentToolCall(name: .surfaceCapsule,
                                             arguments: ["capsuleID": cid])], finished: false),
        AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: cid),
    ]
    let client = FakeRemoteModelClient(replies: scripted)
    let digest = StateDigest(tension: .high, sleep: .low,
                             calmCapsulesAvailable: 2, daysSinceLastSurfacing: 9)

    let r0 = try await client.startSurfacing(digest: digest, context: AgentContext.empty)
    #expect(r0.toolCalls.first?.name == .searchCapsules)
    let r1 = try await client.continueTurn(AgentTurn(toolResults: [], finished: false))
    #expect(r1.toolCalls.first?.name == .surfaceCapsule)
    let r2 = try await client.continueTurn(AgentTurn(toolResults: [], finished: false))
    #expect(r2.finished)
    #expect(r2.surfaceCapsuleID == cid)
}

@Test func fakeClientRecordsRequestForKeyLeakAssertion() async throws {
    let client = FakeRemoteModelClient(replies: [AgentReply(toolCalls: [], finished: true)])
    _ = try await client.startSurfacing(
        digest: StateDigest(tension: .low, sleep: .high,
                            calmCapsulesAvailable: 1, daysSinceLastSurfacing: 1),
        context: AgentContext.empty
    )
    // 客户端绝不内嵌 API key —— 发出的请求体里不得出现任何疑似 key 的字段。
    let body = client.lastRequestBody ?? ""
    for suspicious in ["sk-", "api_key", "apiKey", "authorization", "Bearer"] {
        #expect(!body.contains(suspicious))
    }
}

// MARK: - HTTPRemoteModelClient（D2 鉴权 / badStatus 映射 / C3 多轮历史）

/// 拦截 URLSession 请求的桩 —— 记录每次请求（含头与正文），按脚本回响应。
/// 串行单测里用进程级静态状态简单可控。
private final class StubURLProtocol: URLProtocol {
    /// 每次请求的快照：Authorization 头 + 正文 JSON 串。
    struct Captured {
        let authorization: String?
        let bodyJSON: String
    }
    nonisolated(unsafe) static var captured: [Captured] = []
    /// 桩响应：HTTP 状态码 + 返回正文（每次请求消费一条；不足则复用最后一条）。
    nonisolated(unsafe) static var responses: [(status: Int, body: Data)] = []
    nonisolated(unsafe) static var cursor = 0

    static func reset() {
        captured = []
        responses = []
        cursor = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // URLSession 把 httpBody 搬进 httpBodyStream，需从流里读回正文。
        let bodyData: Data
        if let stream = request.httpBodyStream {
            stream.open()
            var collected = Data()
            let bufSize = 4096
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
            defer { buf.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buf, maxLength: bufSize)
                if read <= 0 { break }
                collected.append(buf, count: read)
            }
            stream.close()
            bodyData = collected
        } else {
            bodyData = request.httpBody ?? Data()
        }
        Self.captured.append(Captured(
            authorization: request.value(forHTTPHeaderField: "Authorization"),
            bodyJSON: String(data: bodyData, encoding: .utf8) ?? ""
        ))

        let idx = min(Self.cursor, Self.responses.count - 1)
        let resp = Self.responses.isEmpty ? (status: 200, body: Data()) : Self.responses[idx]
        Self.cursor += 1

        let httpResp = HTTPURLResponse(
            url: request.url!, statusCode: resp.status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: httpResp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: resp.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeStubbedClient(deviceToken: String) -> HTTPRemoteModelClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: config)
    return HTTPRemoteModelClient(
        proxyURL: URL(string: "https://proxy.test/agent")!,
        deviceToken: deviceToken,
        session: session
    )
}

private func replyJSON(_ reply: AgentReply) -> Data {
    try! JSONEncoder().encode(reply)
}

/// 这组用进程级 `URLProtocol` 桩状态，故必须串行（`.serialized`）跑，
/// 避免并发测试互相污染 `StubURLProtocol.captured` / `responses`。
@Suite(.serialized)
struct HTTPRemoteModelClientTests {
    /// (a) 每次请求都带 `Authorization: Bearer <token>` —— token 来自注入，非硬编码（D2）。
    @Test func sendsAuthorizationBearerHeader() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.responses = [(200, replyJSON(AgentReply(toolCalls: [], finished: true)))]
        let client = makeStubbedClient(deviceToken: "tok-abc-123")

        _ = try await client.startSurfacing(
            digest: StateDigest(tension: .low, sleep: .high,
                                calmCapsulesAvailable: 1, daysSinceLastSurfacing: 1),
            context: AgentContext.empty
        )

        #expect(StubURLProtocol.captured.count == 1)
        #expect(StubURLProtocol.captured.first?.authorization == "Bearer tok-abc-123")
    }

    /// (b) 上游非 2xx → 映射为 RemoteModelError.badStatus（D23 脱敏后仍是非 2xx）。
    @Test func mapsNon2xxToBadStatus() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.responses = [(502, Data(#"{"error":"service unavailable"}"#.utf8))]
        let client = makeStubbedClient(deviceToken: "tok")

        await #expect(throws: RemoteModelError.self) {
            _ = try await client.startSurfacing(
                digest: StateDigest(tension: .high, sleep: .low,
                                    calmCapsulesAvailable: 0, daysSinceLastSurfacing: 3),
                context: AgentContext.empty
            )
        }
    }

    /// (c) continueTurn 重发**累积的完整历史**：首轮 user 消息 + 上一轮 assistant 回复
    /// + 本轮 tool-results user 消息（C3）。修复前 continue 只发 tool-results、丢上下文。
    @Test func continueResendsAccumulatedHistory() async throws {
        StubURLProtocol.reset()
        let firstReply = AgentReply(
            toolCalls: [AgentToolCall(name: .searchCapsules, arguments: ["query": "calm"])],
            finished: false
        )
        let secondReply = AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: nil)
        StubURLProtocol.responses = [(200, replyJSON(firstReply)), (200, replyJSON(secondReply))]
        let client = makeStubbedClient(deviceToken: "tok")

        _ = try await client.startSurfacing(
            digest: StateDigest(tension: .high, sleep: .low,
                                calmCapsulesAvailable: 2, daysSinceLastSurfacing: 9),
            context: AgentContext(candidates: [
                AgentContext.CapsuleMeta(id: "cap-1", title: "窗外的雨声",
                                         tags: ["calm"], placeName: "家")
            ], cadence: "occasionally")
        )
        _ = try await client.continueTurn(AgentTurn(
            toolResults: [ToolResult(name: .searchCapsules, output: #"["cap-1"]"#)],
            finished: false
        ))

        #expect(StubURLProtocol.captured.count == 2)

        // 首轮请求体只含初始 user 消息（候选元数据在其中）。
        let firstBody = StubURLProtocol.captured[0].bodyJSON
        #expect(firstBody.contains("窗外的雨声"))

        // 第二轮请求体须保留首轮上下文 + 回填上一轮 assistant 回复 + 本轮 tool-results。
        let secondBody = StubURLProtocol.captured[1].bodyJSON
        #expect(secondBody.contains("窗外的雨声"))           // 首轮 user 上下文未丢
        #expect(secondBody.contains("searchCapsules"))       // 上一轮 assistant 工具调用回填
        #expect(secondBody.contains("assistant"))            // 含 assistant 角色消息
        #expect(secondBody.contains("cap-1"))                // 本轮 tool-results 的胶囊 ID
        #expect(secondBody.contains("上一轮工具结果"))         // 本轮 tool-results user 消息
        // 历史累积到三条消息（user / assistant / user）。
        #expect(secondBody.components(separatedBy: "\"role\"").count - 1 == 3)
    }
}
