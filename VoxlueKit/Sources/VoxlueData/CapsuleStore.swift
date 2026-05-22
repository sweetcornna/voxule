import Foundation
import SwiftData

/// 胶囊写操作的唯一入口，封装 ModelContext。
/// UI 读取仍可直接用 @Query；写操作统一走这里。
@MainActor
public final class CapsuleStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// 新增一枚胶囊。
    public func add(_ capsule: Capsule) throws {
        context.insert(capsule)
        try context.save()
    }

    /// 删除一枚胶囊（「划掉这张」）。
    public func delete(_ capsule: Capsule) throws {
        context.delete(capsule)
        try context.save()
    }

    /// 推进胶囊的显影状态。
    public func updateState(_ capsule: Capsule, to state: CapsuleState) throws {
        capsule.state = state
        if state == .opened {
            capsule.openedAt = Date()
        }
        try context.save()
    }

    /// 全部胶囊，按创建时间倒序。
    public func allCapsules() throws -> [Capsule] {
        try context.fetch(
            FetchDescriptor<Capsule>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
    }
}
