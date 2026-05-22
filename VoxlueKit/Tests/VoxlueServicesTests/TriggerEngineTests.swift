import Testing
import Foundation
import SwiftData
@testable import VoxlueData
@testable import VoxlueServices

@MainActor
private func makeStore() throws -> (CapsuleStore, ModelContainer) {
    let container = try VoxlueModelContainer.make(inMemory: true)
    return (CapsuleStore(context: container.mainContext), container)
}

@MainActor
@Test func fakeEngineSurfaceTracksDevelopingID() async {
    let engine = FakeTriggerEngine()
    let id = UUID()
    await engine.surface(capsuleID: id)
    #expect(engine.developingCapsuleIDs == [id])
}

@MainActor
@Test func surfaceMovesCapsuleToDeveloping() async throws {
    let (store, container) = try makeStore()
    let capsule = VoxlueData.Capsule(title: "咖啡馆的雨", lock: .date(.now))
    try store.add(capsule)

    let location = FakeLocationProviding()
    let notifications = FakeNotificationScheduling()
    let liveActivity = FakeLiveActivityControlling()
    let engine = TriggerEngine(
        store: store, location: location,
        notifications: notifications, liveActivity: liveActivity
    )
    await engine.surface(capsuleID: capsule.id)

    #expect(capsule.state == .developing)
    #expect(engine.developingCapsuleIDs == [capsule.id])
    #expect(liveActivity.activeCapsuleIDs == [capsule.id])
    _ = container
}

@MainActor
@Test func surfaceIsIdempotentForAlreadyDeveloping() async throws {
    let (store, container) = try makeStore()
    let capsule = VoxlueData.Capsule(title: "雨", lock: .date(.now))
    try store.add(capsule)
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    await engine.surface(capsuleID: capsule.id)
    await engine.surface(capsuleID: capsule.id)
    #expect(engine.developingCapsuleIDs == [capsule.id])
    _ = container
}

@MainActor
@Test func reconcileSurfacesExpiredDateLock() async throws {
    let (store, container) = try makeStore()
    let past = VoxlueData.Capsule(title: "去年的信", lock: .date(Date(timeIntervalSince1970: 1)))
    let future = VoxlueData.Capsule(
        title: "明年的信", lock: .date(Date(timeIntervalSinceNow: 86_400))
    )
    try store.add(past)
    try store.add(future)
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    await engine.reconcile()

    #expect(past.state == .developing)
    #expect(future.state == .buried)
    _ = container
}

@MainActor
@Test func reconcileSchedulesNotificationForFutureDateLock() async throws {
    let (store, container) = try makeStore()
    let fireAt = Date(timeIntervalSinceNow: 86_400)
    let future = VoxlueData.Capsule(title: "明年的信", lock: .date(fireAt))
    try store.add(future)
    let notifications = FakeNotificationScheduling()
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: notifications, liveActivity: FakeLiveActivityControlling()
    )
    await engine.reconcile()
    #expect(notifications.scheduled[future.id] == fireAt)
    _ = container
}

@MainActor
@Test func reconcileMonitorsBuriedPlaceLocks() async throws {
    let (store, container) = try makeStore()
    let place = VoxlueData.Capsule(
        title: "武康路",
        lock: .place(latitude: 31.21, longitude: 121.43, radius: 80, placeName: "武康路")
    )
    try store.add(place)
    let location = FakeLocationProviding()
    let engine = TriggerEngine(
        store: store, location: location,
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    await engine.reconcile()
    #expect(location.monitoredRegions.map(\.capsuleID) == [place.id])
    _ = container
}

@MainActor
@Test func geofenceEntryEventSurfacesCapsule() async throws {
    let (store, container) = try makeStore()
    let place = VoxlueData.Capsule(
        title: "武康路",
        lock: .place(latitude: 31.21, longitude: 121.43, radius: 80, placeName: "武康路")
    )
    try store.add(place)
    let location = FakeLocationProviding()
    let engine = TriggerEngine(
        store: store, location: location,
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    await engine.start()
    location.simulateEntry(capsuleID: place.id)
    // 让事件流处理一轮。
    try await Task.sleep(for: .milliseconds(50))
    #expect(place.state == .developing)
    _ = container
}

@MainActor
@Test func moodHookFiresOnReconcile() async throws {
    let (store, container) = try makeStore()
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    var hookFired = false
    engine.moodSurfacingHook = { hookFired = true }
    await engine.reconcile()
    #expect(hookFired)
    _ = container
}
