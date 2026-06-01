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
        // 浮现即取消该胶囊待发的时间锁通知 —— 否则系统仍会到点再弹一次，指向一枚
        // 已显影 / 已被看到的胶囊（D10）。非时间锁胶囊无待发通知，cancel 为无操作。
        await notifications.cancel(capsuleID: capsule.id)
        await liveActivity.start(capsuleID: capsule.id, title: displayTitle(capsule))
    }

    /// 胶囊被开启 / 播放后调用：结束其灵动岛 Live Activity（否则永驻、永久占用系统
    /// 活动槽，D9），并取消任何残留的待发通知。`TriggerEngineProtocol` 是冻结契约
    /// （路线图 §3.2），故这些生命周期收尾作为具体类型的附加方法提供，由持有具体
    /// `TriggerEngine` 的 App 壳层（AppDependencies）调用。
    public func markOpened(capsuleID: UUID) async {
        await liveActivity.end(capsuleID: capsuleID)
        await notifications.cancel(capsuleID: capsuleID)
    }

    /// 胶囊被删除后调用：取消待发通知、结束 Live Activity，并按剩余胶囊重建围栏 ——
    /// 否则被删胶囊的通知仍会到点弹出（指向一枚已不存在的胶囊），其地点围栏也继续
    /// 占用系统监听槽（D10）。须在 `store.delete` 之后调用（重建围栏会读当前库）。
    public func discard(capsuleID: UUID) async {
        await notifications.cancel(capsuleID: capsuleID)
        await liveActivity.end(capsuleID: capsuleID)
        let remaining = (try? store.allCapsules()) ?? []
        await refreshGeofences(from: remaining)
    }

    /// 申请本地通知权限 —— 不申请则时间锁「重逢」通知永远被系统抑制、永不显示（D4）。
    /// 作为具体类型的附加方法（冻结协议 §3.2 不变），由 App 壳层 bootstrap 时调用。
    @discardableResult
    public func requestNotificationPermission() async -> Bool {
        await notifications.requestPermission()
    }

    /// 申请定位权限 —— 不申请则地点锁围栏无从监听、永不触发。与通知权限一并在 bootstrap 申请。
    @discardableResult
    public func requestLocationPermission() async -> Bool {
        await location.requestPermission()
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
                // 近未来（本分钟内）的时间锁直接即时浮现：UNCalendarNotificationTrigger
                // 只精确到分钟，本分钟内的 fireAt 永不 fire，会留下空档（D26）。
                if Self.shouldSurfaceNow(fireAt: fireAt, now: now) {
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

    /// 时间锁是否应即时浮现（而非交给本地通知）。纯函数，便于测试（D26）。
    /// 规则：fireAt 已过 → 即时；或 fireAt 落在「本分钟内」（早于下一分钟整点）——
    /// 因为日历通知只精确到分钟，本分钟内的触发时间不会再 fire。
    nonisolated static func shouldSurfaceNow(fireAt: Date, now: Date, calendar: Calendar = .current) -> Bool {
        if fireAt <= now { return true }
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        guard let startOfThisMinute = calendar.date(from: comps) else { return false }
        let startOfNextMinute = startOfThisMinute.addingTimeInterval(60)
        return fireAt < startOfNextMinute
    }
}
