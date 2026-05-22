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
