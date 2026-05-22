import Foundation
import SwiftData
import UserNotifications
import VoxlueData
import VoxlueServices

/// App 壳层依赖装配 —— 一处构造全部触发引擎相关服务的真实现，注入到视图树。
/// MV 模式：服务是 @Observable 具体类型，视图经 .environment 取用。
/// 音频服务（录音/播放）见独立的 `AppEnvironment`。
@MainActor
@Observable
final class AppDependencies {
    let store: CapsuleStore
    let engine: TriggerEngine
    let backgroundTasks: BackgroundTaskCoordinator
    let router: CapsuleRouter
    /// 通知中心 delegate —— 须强引用保活（`UNUserNotificationCenter.delegate` 为 weak）。
    let notificationDelegate: NotificationDelegate

    init(modelContainer: ModelContainer) {
        let store = CapsuleStore(context: modelContainer.mainContext)
        let engine = TriggerEngine(
            store: store,
            location: CLLocationProvider(),
            notifications: UNNotificationService(),
            liveActivity: LiveActivityController()
        )
        let router = CapsuleRouter()
        let notificationDelegate = NotificationDelegate(router: router)
        self.store = store
        self.engine = engine
        self.backgroundTasks = BackgroundTaskCoordinator(engine: engine)
        self.router = router
        self.notificationDelegate = notificationDelegate
        // 接住时间锁通知的点击 —— delegate 须在 App 启动完成前设好。
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    /// 须在 App 启动完成前调用（`voxuleApp.init` 里）——
    /// BGTaskScheduler 的 launch handler 必须在启动结束前注册，否则系统拒绝。
    func registerBackgroundTasks() {
        backgroundTasks.register()
    }

    /// App 启动后调用：排下一次后台重扫、订阅围栏、首次兜底重扫。
    func bootstrap() async {
        backgroundTasks.scheduleNext()
        await engine.start()
        await engine.reconcile()
    }
}
