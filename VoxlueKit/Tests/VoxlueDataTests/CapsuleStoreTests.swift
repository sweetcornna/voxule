import Testing
import Foundation
import SwiftData
@testable import VoxlueData

@MainActor
private func makeStore() throws -> CapsuleStore {
    let container = try VoxlueModelContainer.make(inMemory: true)
    return CapsuleStore(context: container.mainContext)
}

@MainActor
@Test func addThenAllCapsulesReturnsIt() throws {
    let store = try makeStore()
    try store.add(Capsule(title: "咖啡馆的雨"))
    let all = try store.allCapsules()
    #expect(all.count == 1)
    #expect(all.first?.title == "咖啡馆的雨")
}

@MainActor
@Test func allCapsulesSortedByCreatedAtDescending() throws {
    let store = try makeStore()
    let older = Capsule(title: "旧", createdAt: Date(timeIntervalSince1970: 1000))
    let newer = Capsule(title: "新", createdAt: Date(timeIntervalSince1970: 2000))
    try store.add(older)
    try store.add(newer)
    let all = try store.allCapsules()
    #expect(all.map(\.title) == ["新", "旧"])
}

@MainActor
@Test func deleteRemovesCapsule() throws {
    let store = try makeStore()
    let capsule = Capsule(title: "划掉这张")
    try store.add(capsule)
    try store.delete(capsule)
    #expect(try store.allCapsules().isEmpty)
}

@MainActor
@Test func updateStatePersists() throws {
    let store = try makeStore()
    let capsule = Capsule(title: "显影测试")
    try store.add(capsule)
    try store.updateState(capsule, to: .developing)
    #expect(try store.allCapsules().first?.state == .developing)
}
