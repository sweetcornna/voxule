import Testing
import Foundation
import SwiftData
@testable import VoxlueData
@testable import VoxlueServices

@MainActor
private func makeEngine() throws -> (TriggerEngine, CapsuleStore, FakeNotificationScheduling, FakeLiveActivityControlling, FakeLocationProviding, ModelContainer) {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let notifications = FakeNotificationScheduling()
    let liveActivity = FakeLiveActivityControlling()
    let location = FakeLocationProviding()
    let engine = TriggerEngine(store: store, location: location,
                               notifications: notifications, liveActivity: liveActivity)
    return (engine, store, notifications, liveActivity, location, container)
}

// D9: 开启后必须结束 Live Activity —— 否则灵动岛永驻、占用系统活动槽。
@MainActor
@Test func markOpenedEndsLiveActivity() async throws {
    let (engine, store, _, liveActivity, _, container) = try makeEngine()
    let capsule = VoxlueData.Capsule(title: "雨", lock: .date(.now))
    try store.add(capsule)
    await engine.surface(capsuleID: capsule.id)
    #expect(liveActivity.activeCapsuleIDs == [capsule.id])   // 浮现后活动起
    await engine.markOpened(capsuleID: capsule.id)
    #expect(liveActivity.activeCapsuleIDs.isEmpty)            // 开启后活动结束
    _ = container
}

// D10: 浮现即取消该胶囊待发的时间锁通知，避免到点重复弹出。
@MainActor
@Test func surfaceCancelsPendingDateLockNotification() async throws {
    let (engine, store, notifications, _, _, container) = try makeEngine()
    let fireAt = Date(timeIntervalSinceNow: 86_400)
    let capsule = VoxlueData.Capsule(title: "明年的信", lock: .date(fireAt))
    try store.add(capsule)
    await engine.reconcile()
    #expect(notifications.scheduled[capsule.id] == fireAt)   // 先排了通知
    await engine.surface(capsuleID: capsule.id)
    #expect(notifications.scheduled[capsule.id] == nil)      // 浮现后通知被取消
    _ = container
}

// D10: 删除后 discard 取消通知 + 重建围栏（被删的地点锁围栏不再监听）。
@MainActor
@Test func discardCancelsNotificationAndDropsGeofence() async throws {
    let (engine, store, notifications, liveActivity, location, container) = try makeEngine()
    let place = VoxlueData.Capsule(
        title: "武康路",
        lock: .place(latitude: 31.21, longitude: 121.43, radius: 80, placeName: "武康路")
    )
    let dateLock = VoxlueData.Capsule(title: "明年的信", lock: .date(Date(timeIntervalSinceNow: 86_400)))
    try store.add(place)
    try store.add(dateLock)
    await engine.reconcile()
    #expect(location.monitoredRegions.map(\.capsuleID) == [place.id])

    // 删 place，再 discard —— 围栏应清空。
    try store.delete(place)
    await engine.discard(capsuleID: place.id)
    #expect(location.monitoredRegions.isEmpty)

    // discard date 锁应取消其待发通知 + 结束可能的 Live Activity。
    try store.delete(dateLock)
    await engine.discard(capsuleID: dateLock.id)
    #expect(notifications.scheduled[dateLock.id] == nil)
    #expect(liveActivity.activeCapsuleIDs.isEmpty)
    _ = container
}

// D26: 本分钟内的时间锁应即时浮现（日历通知精确到分钟，本分钟内永不 fire）。
@Test func shouldSurfaceNowCoversSubMinuteFutures() {
    let cal = Calendar(identifier: .gregorian)
    // 固定一个分钟整点 + 10 秒作为 now。
    var comps = DateComponents()
    comps.year = 2026; comps.month = 6; comps.day = 1
    comps.hour = 9; comps.minute = 30; comps.second = 10
    let now = cal.date(from: comps)!

    let alreadyPast = now.addingTimeInterval(-120)
    let sameMinuteFuture = now.addingTimeInterval(20)   // 9:30:30 —— 本分钟内
    let nextMinute = now.addingTimeInterval(60)         // 9:31:10 —— 下一分钟

    #expect(TriggerEngine.shouldSurfaceNow(fireAt: alreadyPast, now: now, calendar: cal))
    #expect(TriggerEngine.shouldSurfaceNow(fireAt: sameMinuteFuture, now: now, calendar: cal))
    #expect(!TriggerEngine.shouldSurfaceNow(fireAt: nextMinute, now: now, calendar: cal))
}
