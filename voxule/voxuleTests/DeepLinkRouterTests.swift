import Testing
import Foundation
import VoxlueServices
@testable import voxule

// DeepLinkRouter 编排 CircleServicing —— 用 FakeCircleServicing 注入，全程不触网。

@MainActor
@Test func routerStartsIdle() {
    let router = DeepLinkRouter(circleService: FakeCircleServicing())
    #expect(router.acceptance == .idle)
}

@MainActor
@Test func routerAcceptsValidShareURL() async {
    let fake = FakeCircleServicing()
    let router = DeepLinkRouter(circleService: fake)
    router.handleIncomingShare(url: URL(string: "https://www.icloud.com/share/0ABC")!)

    // handleIncomingShare 内是 Task，轮询等待终态。
    try? await waitUntilSettled(router)
    #expect(router.acceptance == .accepted)
    #expect(try! await fake.circles().count == 1)
}

@MainActor
@Test func routerRejectsInvalidShareURL() async {
    let router = DeepLinkRouter(circleService: FakeCircleServicing())
    router.handleIncomingShare(url: URL(string: "https://example.com/not-a-share")!)
    try? await waitUntilSettled(router)
    if case .failed = router.acceptance {
        #expect(Bool(true))
    } else {
        Issue.record("应停在 .failed，实际为 \(router.acceptance)")
    }
}

@MainActor
@Test func routerResetReturnsToIdle() async {
    let router = DeepLinkRouter(circleService: FakeCircleServicing())
    router.handleIncomingShare(url: URL(string: "https://www.icloud.com/share/0ABC")!)
    try? await waitUntilSettled(router)
    router.reset()
    #expect(router.acceptance == .idle)
}

/// 轮询直到 router 离开 .accepting（最多约 1 秒）。
@MainActor
private func waitUntilSettled(_ router: DeepLinkRouter) async throws {
    for _ in 0..<100 {
        if router.acceptance != .accepting && router.acceptance != .idle { return }
        try await Task.sleep(for: .milliseconds(10))
    }
}
