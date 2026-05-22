import Testing
import Foundation
import SwiftData
import VoxlueData
@testable import VoxlueServices

@Test func fakeHealthProviderReturnsScriptedSnapshot() async {
    let provider = FakeHealthProviding(
        snapshot: HealthSnapshot(
            moodValence: -0.4, hrvSDNN: 28, restingHeartRate: 72, sleepHours: 5.1
        ),
        authorized: true
    )
    let granted = await provider.requestAuthorization()
    #expect(granted)
    let snapshot = await provider.snapshot()
    #expect(snapshot?.sleepHours == 5.1)
}

@Test func fakeHealthProviderDeniedReturnsNilSnapshot() async {
    let provider = FakeHealthProviding(snapshot: nil, authorized: false)
    let granted = await provider.requestAuthorization()
    #expect(!granted)
    #expect(await provider.snapshot() == nil)
}

@Test func fakeSignalDistillingReturnsScriptedDigest() async {
    let scripted = StateDigest(tension: .high, sleep: .low,
                               calmCapsulesAvailable: 1, daysSinceLastSurfacing: 12)
    let distiller = FakeSignalDistilling(digest: scripted)
    let digest = await distiller.distill()
    #expect(digest.tension == .high)
    #expect(digest.daysSinceLastSurfacing == 12)
}

@MainActor
@Test func distillerMapsPoorSleepToLowLevel() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let health = FakeHealthProviding(
        snapshot: HealthSnapshot(moodValence: -0.5, hrvSDNN: 18,
                                 restingHeartRate: 80, sleepHours: 4.0)
    )
    let distiller = SignalDistiller(health: health, store: store)
    let digest = await distiller.distill()
    // 4 小时睡眠 → low；低 HRV + 高静息心率 + 负心情 → tension high。
    #expect(digest.sleep == .low)
    #expect(digest.tension == .high)
}

@MainActor
@Test func distillerCountsCalmCapsules() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    // 两枚带「平静」标签的情绪锁胶囊。
    try store.add(VoxlueData.Capsule(title: "海", lock: .mood(notBefore: nil)).tagged("平静"))
    try store.add(VoxlueData.Capsule(title: "雨", lock: .mood(notBefore: nil)).tagged("平静"))
    try store.add(VoxlueData.Capsule(title: "闹市", lock: .mood(notBefore: nil)))
    let distiller = SignalDistiller(
        health: FakeHealthProviding(snapshot: nil), store: store
    )
    let digest = await distiller.distill()
    #expect(digest.calmCapsulesAvailable == 2)
}

// 合规铁律：脱敏闸门的产物里不得残留任何原始读数。
@MainActor
@Test func distilledDigestCarriesNoRawHealthValues() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let rawSleep = 4.0
    let distiller = SignalDistiller(
        health: FakeHealthProviding(
            snapshot: HealthSnapshot(moodValence: -0.5, hrvSDNN: 18,
                                     restingHeartRate: 80, sleepHours: rawSleep)
        ),
        store: store
    )
    let digest = await distiller.distill()
    let json = String(data: try JSONEncoder().encode(digest), encoding: .utf8)!
    // 原始睡眠 4.0 这个数值绝不应出现在越过边界的摘要里。
    #expect(!json.contains("4.0"))
    #expect(!json.contains("18"))
    #expect(!json.contains("80"))
}

private extension VoxlueData.Capsule {
    func tagged(_ tag: String) -> VoxlueData.Capsule { self.tags = [tag]; return self }
}
