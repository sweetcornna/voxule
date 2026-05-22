import Foundation
import Observation
import VoxlueData

/// 显影触发引擎真实现 —— 三把锁判定 + 显影状态机。
///
/// 它在三种执行上下文里都要正确工作：前台、被地理围栏唤醒、BGTask 后台任务。
/// 故引擎不持有任何 UI 状态：所有真相落回 SwiftData（经 `CapsuleStore`），
/// `developingCapsuleIDs` 只是给灵动岛/UI 读的内存投影，由状态机推导。
@MainActor
@Observable
public final class TriggerEngine: TriggerEngineProtocol {

    private let store: CapsuleStore
    private let location: LocationProviding
    private let notifications: NotificationScheduling
    private let liveActivity: LiveActivityControlling

    /// 情绪锁浮现钩子 —— BGTask 唤醒时调用。
    /// 真闭环（脱敏闸门 → agent → 浮现）在计划 06 接入，这里只留入口。
    public var moodSurfacingHook: (@MainActor () -> Void)?

    private var eventTask: Task<Void, Never>?

    public init(
        store: CapsuleStore,
        location: LocationProviding,
        notifications: NotificationScheduling,
        liveActivity: LiveActivityControlling
    ) {
        self.store = store
        self.location = location
        self.notifications = notifications
        self.liveActivity = liveActivity
    }

    // 不设 deinit 取消 eventTask：Swift 6 的 deinit 无法访问 @MainActor 隔离属性。
    // eventTask 内用 [weak self]，引擎释放后任务在下一次事件即自行退出，无保留环。

    // MARK: - TriggerEngineProtocol

    public var developingCapsuleIDs: [UUID] {
        let capsules = (try? store.allCapsules()) ?? []
        return capsules.filter { $0.state == .developing }.map(\.id)
    }

    /// 让某枚胶囊进入 developing。围栏命中、通知点击、agent 调用都汇到这里。
    /// 已是 developing / developed / opened 的胶囊不重复显影（幂等）。
    public func surface(capsuleID: UUID) async {
        guard let capsule = capsule(id: capsuleID) else { return }
        guard capsule.state == .buried else { return }
        try? store.updateState(capsule, to: .developing)
        await liveActivity.start(capsuleID: capsule.id, title: displayTitle(capsule))
    }

    /// 全量重扫 —— App 启动 / 后台刷新时调用，是时间锁与地点锁的兜底。
    /// 1. 过期时间锁直接显影；2. 未过期时间锁补登记通知；
    /// 3. 全部已埋下地点锁重新交给围栏调度；4. 触发情绪锁浮现钩子。
    public func reconcile() async {
        let capsules = (try? store.allCapsules()) ?? []
        let now = Date()

        for capsule in capsules where capsule.state == .buried {
            switch capsule.lock {
            case .date(let fireAt):
                if fireAt <= now {
                    await surface(capsuleID: capsule.id)
                } else {
                    try? await notifications.scheduleDateLock(
                        capsuleID: capsule.id, fireAt: fireAt
                    )
                }
            case .place, .mood:
                break
            }
        }

        await refreshGeofences(from: capsules)
        moodSurfacingHook?()
    }

    // MARK: - 生命周期

    /// 开始订阅围栏事件流。App 启动与围栏唤醒时调用一次。
    public func start() async {
        guard eventTask == nil else { return }
        let stream = location.events
        eventTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                switch event {
                case .entered(let capsuleID):
                    await self.surface(capsuleID: capsuleID)
                }
            }
        }
        let capsules = (try? store.allCapsules()) ?? []
        await refreshGeofences(from: capsules)
    }

    // MARK: - 私有

    /// 把全部已埋下地点锁裁成最近 20 个交给系统监听。
    private func refreshGeofences(from capsules: [VoxlueData.Capsule]) async {
        var regions: [GeofenceRegion] = []
        for capsule in capsules where capsule.state == .buried {
            if case .place(let lat, let lon, let radius, _) = capsule.lock {
                regions.append(GeofenceRegion(
                    capsuleID: capsule.id, latitude: lat, longitude: lon, radius: radius
                ))
            }
        }
        // 把全量地点锁围栏交给 wrapper —— 「最近 20 个」裁剪由 LocationProviding
        // 真实现在能拿到用户实时坐标时跑 GeofenceScheduler 完成（见 CLLocationProvider）。
        await location.monitor(regions: regions)
    }

    private func capsule(id: UUID) -> VoxlueData.Capsule? {
        ((try? store.allCapsules()) ?? []).first { $0.id == id }
    }

    private func displayTitle(_ capsule: VoxlueData.Capsule) -> String {
        capsule.title.isEmpty ? "一张待显影的相" : capsule.title
    }
}
