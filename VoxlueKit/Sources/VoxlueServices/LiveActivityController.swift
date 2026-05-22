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
@MainActor
public final class LiveActivityController: LiveActivityControlling {

    /// capsuleID → 活跃 Activity 句柄。
    private var activities: [UUID: Activity<DevelopingActivityAttributes>] = [:]

    public init() {}

    public var activeCapsuleIDs: [UUID] { Array(activities.keys) }

    public func start(capsuleID: UUID, title: String) async {
        guard activities[capsuleID] == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DevelopingActivityAttributes(capsuleID: capsuleID, title: title)
        let initialState = DevelopingActivityAttributes.ContentState(developProgress: 0)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            activities[capsuleID] = activity
        } catch {
            // Live Activity 起不来不影响主流程 —— 胶囊状态仍由 SwiftData 持有。
        }
    }

    public func update(capsuleID: UUID, progress: Double) async {
        guard let activity = activities[capsuleID] else { return }
        let state = DevelopingActivityAttributes.ContentState(developProgress: progress)
        await activity.update(.init(state: state, staleDate: nil))
    }

    public func end(capsuleID: UUID) async {
        guard let activity = activities[capsuleID] else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        activities[capsuleID] = nil
    }
}
#endif
