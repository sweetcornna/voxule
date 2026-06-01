import Foundation
import SwiftData

/// 胶囊写操作可能抛出的错误。
public enum CapsuleStoreError: Error, Equatable {
    /// 非法的状态回退（如 opened → buried）。显影状态机只许前进（D27）。
    case illegalStateTransition(from: CapsuleState, to: CapsuleState)
}

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
    ///
    /// 显影状态机只许前进（buried → developing → developed → opened）：
    /// 拒绝回退（如 opened → buried），避免产生 state/openedAt 不一致的记录（D27）。
    /// - Throws: `CapsuleStoreError.illegalStateTransition` 当目标状态比当前状态更靠前。
    public func updateState(_ capsule: Capsule, to state: CapsuleState) throws {
        let current = capsule.state
        guard state.progressRank >= current.progressRank else {
            throw CapsuleStoreError.illegalStateTransition(from: current, to: state)
        }
        capsule.state = state
        // 进入 developing 记录浮现时刻（D12，蒸馏「距上次浮现天数」用）。
        if state == .developing, capsule.surfacedAt == nil {
            capsule.surfacedAt = Date()
        }
        // 进入 opened 记录开启时刻；非 opened 态清空 openedAt，双保险防不一致（D27）。
        if state == .opened {
            if capsule.openedAt == nil { capsule.openedAt = Date() }
        } else {
            capsule.openedAt = nil
        }
        try context.save()
    }

    /// 把胶囊归入某个声音圈（`circleID` 为 nil 表示移回「自己」）。
    /// 同时维护 `circleID`（@Query/#Predicate 查询键）与 `circle` 关系 —— 关系是
    /// CKShare 把胶囊记录挂到 Circle 共享树下、受邀方才看得到的前提（D7）。
    public func assignCircle(_ capsule: Capsule, circleID: UUID?) throws {
        capsule.circleID = circleID
        if let circleID {
            capsule.circle = try context.fetch(
                FetchDescriptor<Circle>(predicate: #Predicate { $0.id == circleID })
            ).first
            capsule.recipient = .circle
        } else {
            capsule.circle = nil
            capsule.recipient = .me
        }
        try context.save()
    }

    /// 全部胶囊，按创建时间倒序。
    public func allCapsules() throws -> [Capsule] {
        try context.fetch(
            FetchDescriptor<Capsule>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
    }

    /// 按指定显影状态查询，按创建时间倒序。
    /// SwiftData 谓词无法可靠转译枚举属性比较（`state` 与 `state.rawValue` 均报错），
    /// 故取全部后在内存里过滤 —— v1 规模下无性能顾虑。
    public func capsules(in state: CapsuleState) throws -> [Capsule] {
        try allCapsules().filter { $0.state == state }
    }

    /// 全部「已埋下·潜伏」状态的胶囊，按创建时间倒序。
    public func buriedCapsules() throws -> [Capsule] {
        try capsules(in: .buried)
    }
}
