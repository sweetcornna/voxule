import Testing
import Foundation
import SwiftData
import VoxlueData
@testable import VoxlueServices

// 说明：CircleService 的 CKShare 生成 / 接受需要真 iCloud 账号，
// 无法在 headless CI 跑通 —— 见计划 Task 15 的真机验证清单。
// 本文件只测不依赖网络的纯域逻辑。

@MainActor
@Test func circleServiceRejectsEmptyName() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let service = CircleService(modelContext: container.mainContext)
    await #expect(throws: CircleServiceError.emptyCircleName) {
        _ = try await service.createCircle(name: "  \n ")
    }
}

@MainActor
@Test func circlesReadsBackInsertedCirclesNewestFirst() async throws {
    // circles() 只读本地 SwiftData 库，不触网 —— 可测。
    let container = try VoxlueModelContainer.make(inMemory: true)
    let context = container.mainContext
    let older = Circle(name: "旧圈", ownerID: "me", createdAt: Date(timeIntervalSince1970: 1000))
    let newer = Circle(name: "新圈", ownerID: "me", createdAt: Date(timeIntervalSince1970: 2000))
    context.insert(older)
    context.insert(newer)
    try context.save()

    let service = CircleService(modelContext: context)
    let all = try await service.circles()
    #expect(all.map(\.name) == ["新圈", "旧圈"])
}

@Test func shareURLRecognitionAcceptsICloudShareLinks() {
    #expect(FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://www.icloud.com/share/0ABCDEF")!))
    #expect(FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://www.icloud.com/share/fake-1234")!))
}

@Test func shareURLRecognitionRejectsNonShareLinks() {
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://example.com/share/abc")!))
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://www.icloud.com/photos/0ABC")!))
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "voxlue://capsule/123")!))
}
