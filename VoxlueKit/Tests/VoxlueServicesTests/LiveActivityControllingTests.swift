import Testing
import Foundation
@testable import VoxlueServices

@MainActor
@Test func fakeLiveActivityStartsAndTracksActive() async {
    let controller = FakeLiveActivityControlling()
    let id = UUID()
    await controller.start(capsuleID: id, title: "咖啡馆的雨")
    #expect(controller.activeCapsuleIDs == [id])
    #expect(controller.startedTitles[id] == "咖啡馆的雨")
}

@MainActor
@Test func fakeLiveActivityEndRemovesActive() async {
    let controller = FakeLiveActivityControlling()
    let id = UUID()
    await controller.start(capsuleID: id, title: "雨")
    await controller.end(capsuleID: id)
    #expect(controller.activeCapsuleIDs.isEmpty)
}

@MainActor
@Test func fakeLiveActivityStartIsIdempotent() async {
    let controller = FakeLiveActivityControlling()
    let id = UUID()
    await controller.start(capsuleID: id, title: "雨")
    await controller.start(capsuleID: id, title: "雨")
    #expect(controller.activeCapsuleIDs == [id])
}

// LiveActivityController 是 iOS 专有真实现（ActivityKit），其测试同样守卫。
#if os(iOS)
@MainActor
@Test func liveActivityControllerConformsToProtocol() {
    let controller: LiveActivityControlling = LiveActivityController()
    #expect(type(of: controller) == LiveActivityController.self)
}

@MainActor
@Test func liveActivityControllerStartsEmpty() {
    let controller = LiveActivityController()
    #expect(controller.activeCapsuleIDs.isEmpty)
}
#endif
