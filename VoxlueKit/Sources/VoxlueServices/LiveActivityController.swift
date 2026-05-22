// ActivityKit 仅在 iOS 等移动平台可用 —— 整个文件用 #if os(iOS) 守卫。
// macOS（swift test 宿主）不编译它；真实现由 App（iOS）构建覆盖。
#if os(iOS)
import Foundation
import ActivityKit

/// `LiveActivityControlling` 的 ActivityKit 真实现。
///
/// 胶囊进入 `developing` 时起一个「显影中」Live Activity（灵动岛 + 锁屏卡片），
/// 显影动效进度经 `update` 推进，胶囊被看到 / 播放后 `end`。
/// Live Activity 的 UI 在 Widget Extension（Task 10）里渲染，本类型只管生命周期。
///
/// 注意：`Activity` 是非 Sendable 的 class。不能把它存进 `@MainActor` 状态后再调用其
/// `nonisolated async` 方法（Swift 6 区域隔离会报「sending」错）。因此本类型只记
/// `activeCapsuleIDs`，update / end 时从 `Activity.activities` 静态列表现查句柄。
@MainActor
public final class LiveActivityController: LiveActivityControlling {

    public private(set) var activeCapsuleIDs: [UUID] = []

    public init() {}

    public func start(capsuleID: UUID, title: String) async {
        guard !activeCapsuleIDs.contains(capsuleID) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DevelopingActivityAttributes(capsuleID: capsuleID, title: title)
        let initialState = DevelopingActivityAttributes.ContentState(developProgress: 0)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            activeCapsuleIDs.append(capsuleID)
        } catch {
            // Live Activity 起不来不影响主流程 —— 胶囊状态仍由 SwiftData 持有。
        }
    }

    public func update(capsuleID: UUID, progress: Double) async {
        guard let activity = Self.liveActivity(for: capsuleID) else { return }
        let content = ActivityContent(
            state: DevelopingActivityAttributes.ContentState(developProgress: progress),
            staleDate: nil
        )
        await activity.update(content)
    }

    public func end(capsuleID: UUID) async {
        if let activity = Self.liveActivity(for: capsuleID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeCapsuleIDs.removeAll { $0 == capsuleID }
    }

    /// 从系统当前活跃的 Live Activity 里按 capsuleID 现查句柄。
    /// `nonisolated` —— 返回值不绑 MainActor 区域，可安全跨隔离调用其 async 方法。
    nonisolated private static func liveActivity(
        for capsuleID: UUID
    ) -> Activity<DevelopingActivityAttributes>? {
        Activity<DevelopingActivityAttributes>.activities.first {
            $0.attributes.capsuleID == capsuleID
        }
    }
}
#endif
