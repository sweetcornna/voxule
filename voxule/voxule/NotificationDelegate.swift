import Foundation
import UserNotifications
import VoxlueServices

/// 接住时间锁通知的点击 —— 解析 userInfo 里的 capsuleID，交给 `CapsuleRouter` 跳详情。
/// `UNNotificationService` 调度通知时把 capsuleID 写进 userInfo（见其 `capsuleIDKey`）。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: CapsuleRouter

    init(router: CapsuleRouter) {
        self.router = router
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // userInfo 非 Sendable —— 在此 nonisolated 上下文里取出 Sendable 的字符串，
        // 再跨 hop 到 MainActor 设置路由。
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo[UNNotificationService.capsuleIDKey] as? String,
              let id = UUID(uuidString: idString) else { return }
        await MainActor.run { router.routedCapsuleID = id }
    }
}
