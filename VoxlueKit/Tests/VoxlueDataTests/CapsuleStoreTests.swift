import Testing
import Foundation
import SwiftData
@testable import VoxlueData

// 注意：容器必须留在每个测试函数自己的作用域里。
// ModelContext 不强引用它的 ModelContainer —— 若把容器创建放进一个
// 返回后即出栈的 helper，容器会被释放，后续 context.insert 会崩溃。

@MainActor
@Test func addThenAllCapsulesReturnsIt() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    try store.add(Capsule(title: "咖啡馆的雨"))
    let all = try store.allCapsules()
    #expect(all.count == 1)
    #expect(all.first?.title == "咖啡馆的雨")
}

@MainActor
@Test func allCapsulesSortedByCreatedAtDescending() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let older = Capsule(title: "旧", createdAt: Date(timeIntervalSince1970: 1000))
    let newer = Capsule(title: "新", createdAt: Date(timeIntervalSince1970: 2000))
    try store.add(older)
    try store.add(newer)
    let all = try store.allCapsules()
    #expect(all.map(\.title) == ["新", "旧"])
}

@MainActor
@Test func deleteRemovesCapsule() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = Capsule(title: "划掉这张")
    try store.add(capsule)
    try store.delete(capsule)
    #expect(try store.allCapsules().isEmpty)
}

@MainActor
@Test func updateStatePersists() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = Capsule(title: "显影测试")
    try store.add(capsule)
    try store.updateState(capsule, to: .developing)
    #expect(try store.allCapsules().first?.state == .developing)
}

@MainActor
@Test func updateStateToOpenedSetsOpenedAt() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = Capsule(title: "回放测试")
    try store.add(capsule)
    #expect(capsule.openedAt == nil)
    try store.updateState(capsule, to: .opened)
    let fetched = try store.allCapsules().first
    #expect(fetched?.state == .opened)
    #expect(fetched?.openedAt != nil)
}

@MainActor
@Test func buriedCapsulesReturnsOnlyBuriedSortedDescending() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let buriedOld = Capsule(title: "潜伏·旧", state: .buried,
                            createdAt: Date(timeIntervalSince1970: 1000))
    let buriedNew = Capsule(title: "潜伏·新", state: .buried,
                            createdAt: Date(timeIntervalSince1970: 2000))
    let developed = Capsule(title: "已显影", state: .developed,
                            createdAt: Date(timeIntervalSince1970: 3000))
    try store.add(buriedOld)
    try store.add(buriedNew)
    try store.add(developed)

    let buried = try store.buriedCapsules()
    #expect(buried.map(\.title) == ["潜伏·新", "潜伏·旧"])
}

@MainActor
@Test func capsulesInStateFiltersByGivenState() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    try store.add(Capsule(title: "a", state: .opened))
    try store.add(Capsule(title: "b", state: .buried))
    #expect(try store.capsules(in: .opened).map(\.title) == ["a"])
    #expect(try store.capsules(in: .buried).map(\.title) == ["b"])
}
