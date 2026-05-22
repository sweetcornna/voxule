import Testing
import Foundation
import VoxlueData
@testable import VoxlueServices

@Test func shareInvitationCarriesURL() {
    let url = URL(string: "https://www.icloud.com/share/0ABC")!
    let invitation = ShareInvitation(url: url)
    #expect(invitation.url == url)
}

@MainActor
@Test func fakeCreateCircleAppendsToCircles() async throws {
    let service = FakeCircleServicing()
    #expect(try await service.circles().isEmpty)

    let circle = try await service.createCircle(name: "家")
    #expect(circle.name == "家")

    let all = try await service.circles()
    #expect(all.count == 1)
    #expect(all.first?.id == circle.id)
}

@MainActor
@Test func fakeCreateCircleRejectsEmptyName() async {
    let service = FakeCircleServicing()
    await #expect(throws: CircleServiceError.emptyCircleName) {
        _ = try await service.createCircle(name: "   ")
    }
}

@MainActor
@Test func fakeMakeInvitationReturnsStableURL() async throws {
    let service = FakeCircleServicing()
    let circle = try await service.createCircle(name: "挚友")
    let invitation = try await service.makeInvitation(for: circle)
    #expect(invitation.url.scheme == "https")
    // 同一个圈再要一次邀请，URL 稳定（同一个 CKShare）。
    let again = try await service.makeInvitation(for: circle)
    #expect(again.url == invitation.url)
}

@MainActor
@Test func fakeAcceptShareAppendsACircle() async throws {
    let service = FakeCircleServicing()
    try await service.acceptShare(from: URL(string: "https://www.icloud.com/share/0XYZ")!)
    let all = try await service.circles()
    #expect(all.count == 1)
    #expect(all.first?.name == "（受邀加入的圈）")
}

@MainActor
@Test func fakeAcceptShareRejectsNonShareURL() async {
    let service = FakeCircleServicing()
    await #expect(throws: CircleServiceError.invalidInvitationURL) {
        try await service.acceptShare(from: URL(string: "https://example.com/hello")!)
    }
}
