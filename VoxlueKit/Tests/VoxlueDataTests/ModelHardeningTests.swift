import Testing
import Foundation
import SwiftData
@testable import VoxlueData

// 审计修复回归：MODEL 批次（D11 / D12 / D25 / D27 / D7-rel）。

// MARK: - D11 锁解码失败不静默降级

@Test func corruptLockDataDoesNotDowngradeDateLockToMood() {
    // payload 损坏/为空（迁移默认、CloudKit 同步缺字段）时，定时锁绝不能被静默
    // 降级成随时可浮现的情绪锁 —— 否则锁形同虚设。
    let fallback = Capsule.decodeLock(from: Data(), kindRaw: Lock.Kind.date.rawValue)
    #expect(fallback.kind == .date)
    if case .date(let d) = fallback {
        #expect(d == .distantFuture)   // 安全锁：永不到点。
    } else {
        Issue.record("应回退为 .date 安全锁，而非 .mood")
    }
}

@Test func corruptLockDataKeepsPlaceKindAndUnmonitorableRadius() {
    let fallback = Capsule.decodeLock(from: Data(), kindRaw: Lock.Kind.place.rawValue)
    #expect(fallback.kind == .place)
    if case .place(_, _, let radius, _) = fallback {
        #expect(radius == 0)   // 半径 0 → 围栏不监听（配合 D17），永不触发。
    } else {
        Issue.record("应回退为 .place 安全锁")
    }
}

@Test func validLockDataStillDecodesEvenIfKindRawDisagrees() throws {
    let data = try JSONEncoder().encode(Lock.date(Date(timeIntervalSince1970: 1_800_000_000)))
    // 正常 payload 优先按 payload 解码，kindRaw 只在解码失败时兜底。
    let decoded = Capsule.decodeLock(from: data, kindRaw: Lock.Kind.mood.rawValue)
    #expect(decoded == .date(Date(timeIntervalSince1970: 1_800_000_000)))
}

// MARK: - D25 lockKind 廉价读取

@MainActor
@Test func lockKindMatchesLockAndTracksSetter() throws {
    let capsule = Capsule(lock: .place(latitude: 1, longitude: 2, radius: 50, placeName: "x"))
    #expect(capsule.lockKind == .place)
    #expect(capsule.lockKind == capsule.lock.kind)
    capsule.lock = .date(Date(timeIntervalSince1970: 1_800_000_000))
    #expect(capsule.lockKind == .date)
    #expect(capsule.lock == .date(Date(timeIntervalSince1970: 1_800_000_000)))
}

// MARK: - D27 状态机只许前进

@MainActor
@Test func updateStateRejectsBackwardTransition() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = Capsule(title: "回退测试")
    try store.add(capsule)
    try store.updateState(capsule, to: .opened)
    #expect(capsule.openedAt != nil)
    #expect(throws: CapsuleStoreError.self) {
        try store.updateState(capsule, to: .buried)
    }
    // 回退被拒，状态仍是 opened、openedAt 仍在。
    #expect(capsule.state == .opened)
    #expect(capsule.openedAt != nil)
}

@MainActor
@Test func updateStateForwardToOpenedStillWorks() throws {
    // 文档化的 v1 主循环：埋下后可直接回放（buried → opened 前进合法）。
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = Capsule(title: "主循环")
    try store.add(capsule)
    try store.updateState(capsule, to: .opened)
    #expect(capsule.state == .opened)
}

// MARK: - D12 surfacedAt 戳浮现时刻

@MainActor
@Test func updateStateToDevelopingStampsSurfacedAt() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = Capsule(title: "浮现时刻")
    try store.add(capsule)
    #expect(capsule.surfacedAt == nil)
    try store.updateState(capsule, to: .developing)
    #expect(capsule.surfacedAt != nil)
    let stamped = capsule.surfacedAt
    // 再次进入 developing 不应重置浮现时刻。
    try store.updateState(capsule, to: .developing)
    #expect(capsule.surfacedAt == stamped)
}

// MARK: - D7 Capsule ↔ Circle 关系

@MainActor
@Test func capsuleCircleRelationshipLinksBothSides() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let context = container.mainContext
    let circle = Circle(name: "家人")
    let capsule = Capsule(title: "外婆的钟")
    context.insert(circle)
    context.insert(capsule)
    capsule.circle = circle
    try context.save()
    #expect(capsule.circle?.id == circle.id)
    #expect(circle.capsules?.contains(where: { $0.id == capsule.id }) == true)
}

@MainActor
@Test func assignCircleWritesBothKeyAndRelationship() throws {
    // D7: assignCircle 同写 circleID（查询键）与 circle 关系（CKShare 父子树前提）。
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let circle = Circle(name: "大学室友")
    container.mainContext.insert(circle)
    let capsule = Capsule(title: "宿舍夜谈")
    try store.add(capsule)

    try store.assignCircle(capsule, circleID: circle.id)
    #expect(capsule.circleID == circle.id)
    #expect(capsule.circle?.id == circle.id)
    #expect(capsule.recipient == .circle)
    #expect(circle.capsules?.contains(where: { $0.id == capsule.id }) == true)

    // 移回「自己」：两者一并清空。
    try store.assignCircle(capsule, circleID: nil)
    #expect(capsule.circleID == nil)
    #expect(capsule.circle == nil)
    #expect(capsule.recipient == .me)
}
