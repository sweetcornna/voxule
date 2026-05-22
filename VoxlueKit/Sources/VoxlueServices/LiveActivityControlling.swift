import Foundation

/// 灵动岛 Live Activity 控制 wrapper（平台能力层）。
/// 真实现见 `LiveActivityController`（ActivityKit），假实现见下。
@MainActor public protocol LiveActivityControlling: AnyObject {
    /// 当前活跃的 Live Activity 对应胶囊。
    var activeCapsuleIDs: [UUID] { get }
    /// 为一枚进入显影的胶囊起 Live Activity。已存在则无操作（幂等）。
    func start(capsuleID: UUID, title: String) async
    /// 推进显影进度（驱动霜化动效）。
    func update(capsuleID: UUID, progress: Double) async
    /// 结束某枚胶囊的 Live Activity。
    func end(capsuleID: UUID) async
}

/// 假 Live Activity 控制 —— 不碰 ActivityKit，记录调用供断言与预览。
@MainActor public final class FakeLiveActivityControlling: LiveActivityControlling {
    public private(set) var activeCapsuleIDs: [UUID] = []
    public private(set) var startedTitles: [UUID: String] = [:]
    public private(set) var progress: [UUID: Double] = [:]

    public init() {}

    public func start(capsuleID: UUID, title: String) async {
        guard !activeCapsuleIDs.contains(capsuleID) else { return }
        activeCapsuleIDs.append(capsuleID)
        startedTitles[capsuleID] = title
        progress[capsuleID] = 0
    }

    public func update(capsuleID: UUID, progress value: Double) async {
        progress[capsuleID] = value
    }

    public func end(capsuleID: UUID) async {
        activeCapsuleIDs.removeAll { $0 == capsuleID }
        startedTitles[capsuleID] = nil
        progress[capsuleID] = nil
    }
}
