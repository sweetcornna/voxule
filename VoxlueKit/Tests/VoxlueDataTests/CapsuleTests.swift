import Testing
import Foundation
import SwiftData
@testable import VoxlueData

@MainActor
@Test func capsuleInsertAndFetch() throws {
    let container = try ModelContainer(
        for: Capsule.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let capsule = Capsule(title: "咖啡馆的雨", lock: .date(Date(timeIntervalSince1970: 1_800_000_000)))
    context.insert(capsule)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Capsule>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.title == "咖啡馆的雨")
    #expect(fetched.first?.state == .buried)
    #expect(fetched.first?.lock.kind == .date)
}

@MainActor
@Test func capsuleDefaultsAreSafeForCloudKit() throws {
    let capsule = Capsule()
    // CloudKit 镜像要求非可选属性全部有默认值。
    #expect(capsule.title == "")
    #expect(capsule.state == .buried)
    #expect(capsule.recipient == .me)
    #expect(capsule.waveform.isEmpty)
    #expect(capsule.tags.isEmpty)
}
