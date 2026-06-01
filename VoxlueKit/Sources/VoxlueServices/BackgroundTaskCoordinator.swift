// BackgroundTasks（BGTaskScheduler）仅在 iOS 等移动平台可用 ——
// 整个文件用 #if os(iOS) 守卫；macOS（swift test 宿主）不编译它。
#if os(iOS)
import Foundation
import BackgroundTasks

/// BGTaskScheduler 接入 —— 后台唤醒入口。
///
/// 注册一个 `BGAppRefreshTask`，系统在安静时段唤醒后调用 `TriggerEngine.reconcile()`：
/// 既是时间锁的兜底重扫，也是情绪锁浮现的入口（`reconcile` 内会触发 `moodSurfacingHook`，
/// 真 agent 闭环在计划 06 接上）。
///
/// 注册标识符须同时写进 App 的 Info.plist `BGTaskSchedulerPermittedIdentifiers`。
@MainActor
public final class BackgroundTaskCoordinator {

    /// 后台重扫任务标识符 —— 须与 Info.plist 中登记一致。
    public static let reconcileTaskIdentifier = "com.voxlue.app.reconcile"

    /// 两次后台重扫之间的最短间隔。
    public static let minimumInterval: TimeInterval = 4 * 3600

    private let engine: TriggerEngineProtocol

    public init(engine: TriggerEngineProtocol) {
        self.engine = engine
    }

    /// App 启动时调用一次 —— 向系统注册后台任务处理器。
    public func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.reconcileTaskIdentifier, using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // 系统在后台线程调用本 handler；runReconcileTask 是 @MainActor，
            // 必须显式 hop 到主 actor，不能在后台线程上同步进入（D20）。
            Task { @MainActor in self.runReconcileTask(refreshTask) }
        }
    }

    /// 排下一次后台重扫 —— 每次任务跑完都要重新排，否则只跑一次。
    public func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: Self.reconcileTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.minimumInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// 跑一轮重扫 —— 围栏唤醒、后台任务、手动重扫都汇到这里。
    public func handleReconcile() async {
        await engine.reconcile()
    }

    // MARK: - 私有

    private func runReconcileTask(_ task: BGAppRefreshTask) {
        scheduleNext()  // 先排下一次，保证持续唤醒。
        let work = Task {
            await handleReconcile()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
#endif
