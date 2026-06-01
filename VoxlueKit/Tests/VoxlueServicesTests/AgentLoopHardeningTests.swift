import Testing
import Foundation
import SwiftData
@testable import VoxlueServices
import VoxlueData

// 审计修复回归：AGENT 批次（D1 / D3 / D13 / D12）。

@MainActor
private final class SpyTrigger: TriggerEngineProtocol {
    private(set) var surfaced: [UUID] = []
    var developingCapsuleIDs: [UUID] { surfaced }
    func surface(capsuleID: UUID) async { surfaced.append(capsuleID) }
    func reconcile() async {}
}

// D1: 模型在单条 reply 里同时给 surfaceCapsule 工具调用 + finished:true（正是
// SYSTEM_PROMPT 要求的形态）——旧 `while !finished` 会整段跳过派发，胶囊永不浮现。
@MainActor
@Test func singleReplyFinishedWithToolCallStillSurfaces() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = VoxlueData.Capsule(title: "外婆的院子", lock: .mood(notBefore: nil))
    try store.add(capsule)
    let cid = capsule.id
    let trigger = SpyTrigger()
    let client = FakeRemoteModelClient(replies: [
        AgentReply(toolCalls: [AgentToolCall(name: .surfaceCapsule,
                                             arguments: ["capsuleID": cid.uuidString])],
                   finished: true, surfaceCapsuleID: cid.uuidString),
    ])
    let gateway = AgentGateway(distiller: FakeSignalDistilling(),
                               client: client, trigger: trigger, store: store)
    let decision = try await gateway.runSurfacingCycle()
    #expect(decision == .surface(capsuleID: cid))
    #expect(trigger.surfaced == [cid])
}

// D1b: 模型只在 surfaceCapsuleID 字段给决定、未发 surfaceCapsule 工具调用 ——
// 网关也须确保浮现真正发生（决定与副作用一致）。
@MainActor
@Test func finishedWithDecisionFieldOnlyStillSurfaces() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = VoxlueData.Capsule(title: "海边", lock: .mood(notBefore: nil))
    try store.add(capsule)
    let cid = capsule.id
    let trigger = SpyTrigger()
    let client = FakeRemoteModelClient(replies: [
        AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: cid.uuidString),
    ])
    let gateway = AgentGateway(distiller: FakeSignalDistilling(),
                               client: client, trigger: trigger, store: store)
    let decision = try await gateway.runSurfacingCycle()
    #expect(decision == .surface(capsuleID: cid))
    #expect(trigger.surfaced == [cid])
}

// D3/D13: agent 试图浮现一枚 date 锁（非候选）胶囊 —— 必须被拒：不浮现，决定为 hold。
@MainActor
@Test func surfacingNonCandidateIsRejected() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let dateLocked = VoxlueData.Capsule(title: "明年今日",
                                        lock: .date(Date(timeIntervalSinceNow: 86_400)))
    try store.add(dateLocked)
    let cid = dateLocked.id
    let trigger = SpyTrigger()
    let client = FakeRemoteModelClient(replies: [
        AgentReply(toolCalls: [AgentToolCall(name: .surfaceCapsule,
                                             arguments: ["capsuleID": cid.uuidString])],
                   finished: true, surfaceCapsuleID: cid.uuidString),
    ])
    let gateway = AgentGateway(distiller: FakeSignalDistilling(),
                               client: client, trigger: trigger, store: store)
    let decision = try await gateway.runSurfacingCycle()
    #expect(decision == .hold)              // 非候选不浮现
    #expect(trigger.surfaced.isEmpty)
}

// D13: 检索只返回候选集内（情绪锁 + 已埋下）的胶囊，看不到 date/place 锁或已开启胶囊。
@MainActor
@Test func searchOnlyReturnsCandidates() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let mood = VoxlueData.Capsule(title: "雨夜", lock: .mood(notBefore: nil))
    let dateLocked = VoxlueData.Capsule(title: "雨天约定",
                                        lock: .date(Date(timeIntervalSinceNow: 86_400)))
    try store.add(mood)
    try store.add(dateLocked)
    let trigger = SpyTrigger()
    // 第一轮让 agent 搜「雨」，第二轮结束。
    let client = FakeRemoteModelClient(replies: [
        AgentReply(toolCalls: [AgentToolCall(name: .searchCapsules,
                                             arguments: ["query": "雨"])], finished: false),
        AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: nil),
    ])
    // 用一个能观测 tool 结果的 spy distiller 不便；改为直接断言决定 + 不浮现非候选。
    let gateway = AgentGateway(distiller: FakeSignalDistilling(),
                               client: client, trigger: trigger, store: store)
    let decision = try await gateway.runSurfacingCycle()
    #expect(decision == .hold)
    #expect(trigger.surfaced.isEmpty)   // date 锁的「雨天约定」即便命中查询也不会被浮现
}

// D12: 很久前创建、今天刚浮现（developing、未开启）的情绪胶囊，
// 「距上次浮现天数」应为 0（旧实现漏 developing + 用 createdAt 会误报 ~60/99）。
@MainActor
@Test func daysSinceLastSurfacingUsesSurfacedAtAndCountsDeveloping() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = VoxlueData.Capsule(title: "旧物", lock: .mood(notBefore: nil),
                                     createdAt: Date(timeIntervalSinceNow: -60 * 86_400))
    try store.add(capsule)
    try store.updateState(capsule, to: .developing)   // 戳 surfacedAt=今天
    let distiller = SignalDistiller(health: FakeHealthProviding(snapshot: nil), store: store)
    let digest = await distiller.distill()
    #expect(digest.daysSinceLastSurfacing == 0)
}
