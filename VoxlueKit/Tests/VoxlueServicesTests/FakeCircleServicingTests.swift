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

// D24: 精确 host 校验 —— 子串钓鱼域名必须被拒，合法 icloud 域名通过。
@Test func looksLikeShareURLRejectsLookalikeHosts() {
    // 钓鱼：host 含 "icloud.com" 子串但并非 icloud 域。
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://icloud.com.attacker.test/share/x")!))
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://evil-icloud.com/share/x")!))
    // 非 https 拒。
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "http://www.icloud.com/share/x")!))
    // 合法。
    #expect(FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://www.icloud.com/share/0ABC")!))
    #expect(FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://icloud.com/share/0ABC")!))
}
