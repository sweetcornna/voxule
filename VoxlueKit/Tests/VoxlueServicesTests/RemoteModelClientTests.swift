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
