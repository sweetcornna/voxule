// BackgroundTaskCoordinator 是 iOS 专有（BGTaskScheduler）——
// 整个测试文件用 #if os(iOS) 守卫，macOS swift test 下不编译。
#if os(iOS)
import Testing
import Foundation
import SwiftData
@testable import VoxlueData
@testable import VoxlueServices

@MainActor
@Test func backgroundTaskIdentifierIsStable() {
    #expect(BackgroundTaskCoordinator.reconcileTaskIdentifier == "com.voxlue.app.reconcile")
}

@MainActor
@Test func handleReconcileRunsEngineReconcile() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    var moodHookFired = false
    engine.moodSurfacingHook = { moodHookFired = true }

    let coordinator = BackgroundTaskCoordinator(engine: engine)
    await coordinator.handleReconcile()

    // reconcile 跑过 → 情绪锁 hook 被触发。
    #expect(moodHookFired)
    _ = container
}

@MainActor
@Test func handleReconcileSurfacesExpiredDateLockInBackground() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let past = VoxlueData.Capsule(title: "去年", lock: .date(Date(timeIntervalSince1970: 1)))
    try store.add(past)
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    let coordinator = BackgroundTaskCoordinator(engine: engine)
    await coordinator.handleReconcile()
    #expect(past.state == .developing)
    _ = container
}
#endif
