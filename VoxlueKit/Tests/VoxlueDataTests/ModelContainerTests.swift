import Testing
import Foundation
import SwiftData
@testable import VoxlueData

@MainActor
@Test func inMemoryContainerHoldsAllThreeModels() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let context = container.mainContext

    context.insert(Capsule(title: "测试胶囊"))
    context.insert(Circle(name: "家"))
    context.insert(CircleMember(name: "奶奶"))
    try context.save()

    #expect(try context.fetch(FetchDescriptor<Capsule>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<Circle>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<CircleMember>()).count == 1)
}
