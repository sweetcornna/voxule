import Testing
import Foundation
import SwiftData
@testable import VoxlueData

@MainActor
@Test func circleWithMembersInsertAndFetch() throws {
    let container = try ModelContainer(
        for: Circle.self, CircleMember.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let circle = Circle(name: "家", ownerID: "user-1")
    let nana = CircleMember(name: "奶奶", userRecordID: "user-2", role: .member)
    circle.members = [nana]
    context.insert(circle)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Circle>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.name == "家")
    #expect(fetched.first?.members?.first?.name == "奶奶")
}
