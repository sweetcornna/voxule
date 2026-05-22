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
