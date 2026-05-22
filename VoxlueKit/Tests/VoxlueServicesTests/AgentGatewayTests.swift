import Testing
import Foundation
import SwiftData
@testable import VoxlueServices
import VoxlueData

/// 测试用最小 TriggerEngine 替身 —— 记录被 surface 的胶囊。
@MainActor
final class SpyTriggerEngine: TriggerEngineProtocol {
    private(set) var surfaced: [UUID] = []
    var developingCapsuleIDs: [UUID] { surfaced }
    func surface(capsuleID: UUID) async { surfaced.append(capsuleID) }
    func reconcile() async {}
}

@MainActor
@Test func surfacingCycleDispatchesScriptedToolCallsAndSurfaces() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = VoxlueData.Capsule(title: "外婆的院子", lock: .mood(notBefore: nil))
    try store.add(capsule)
    let cid = capsule.id

    let trigger = SpyTriggerEngine()
    let client = FakeRemoteModelClient(replies: [
        AgentReply(toolCalls: [AgentToolCall(name: .searchCapsules,
                                             arguments: ["query": "院子"])], finished: false),
        AgentReply(toolCalls: [AgentToolCall(name: .surfaceCapsule,
                                             arguments: ["capsuleID": cid.uuidString])], finished: false),
        AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: cid.uuidString),
    ])
    let gateway = AgentGateway(
        distiller: FakeSignalDistilling(),
        client: client,
        trigger: trigger,
        store: store
    )

    let decision = try await gateway.runSurfacingCycle()

    #expect(decision == .surface(capsuleID: cid))
    // surfaceCapsule 工具调用确实被派发给了 TriggerEngine。
    #expect(trigger.surfaced == [cid])
}

@MainActor
@Test func surfacingCycleHoldsWhenAgentDecidesNotToSurface() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let trigger = SpyTriggerEngine()
    let client = FakeRemoteModelClient(replies: [
        AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: nil),
    ])
    let gateway = AgentGateway(
        distiller: FakeSignalDistilling(),
        client: client, trigger: trigger, store: store
    )
    let decision = try await gateway.runSurfacingCycle()
    #expect(decision == .hold)
    #expect(trigger.surfaced.isEmpty)
}

@MainActor
@Test func surfacingCycleStopsAtMaxTurnsWithoutInfiniteLoop() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    // 一个永不 finished 的脚本 —— 网关须在 maxTurns 处止损并返回 hold。
    let neverEnding = Array(repeating:
        AgentReply(toolCalls: [AgentToolCall(name: .searchCapsules,
                                             arguments: [:])], finished: false),
        count: 50)
    let gateway = AgentGateway(
        distiller: FakeSignalDistilling(),
        client: FakeRemoteModelClient(replies: neverEnding),
        trigger: SpyTriggerEngine(), store: store
    )
    let decision = try await gateway.runSurfacingCycle()
    #expect(decision == .hold)
}

@MainActor
@Test func fakeAgentGatewayReturnsScriptedDecision() async throws {
    let cid = UUID()
    let gateway = FakeAgentGateway(decision: .surface(capsuleID: cid))
    #expect(try await gateway.runSurfacingCycle() == .surface(capsuleID: cid))
}
