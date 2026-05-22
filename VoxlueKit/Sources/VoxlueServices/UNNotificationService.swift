import Foundation
import UserNotifications

/// `NotificationScheduling` 的 UserNotifications 真实现。
///
/// 时间锁机制（spec §6）：注册本地日历通知 `UNCalendarNotificationTrigger`，
/// 保证 App 没开也能在到点提醒。通知 `userInfo` 带 `capsuleID`，供点击后深链到详情。
/// 兜底：App 启动 / 后台刷新由 `TriggerEngine.reconcile()` 再扫一遍过期胶囊。
public final class UNNotificationService: NotificationScheduling, @unchecked Sendable {

    /// 通知 `userInfo` 里 capsuleID 的键名 —— 深链路由按此读取。
    public static let capsuleIDKey = "capsuleID"

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func scheduleDateLock(capsuleID: UUID, fireAt date: Date) async throws {
        let request = Self.makeRequest(capsuleID: capsuleID, fireAt: date)
        try await center.add(request)
    }

    public func cancel(capsuleID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [capsuleID.uuidString])
    }

    /// 构建一条时间锁通知请求 —— 纯函数，便于单元测试。
    public static func makeRequest(capsuleID: UUID, fireAt date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "有一张相显影了"
        content.body = "你埋下的声音，到了重逢的时候。"
        content.sound = .default
        content.userInfo = [capsuleIDKey: capsuleID.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: capsuleID.uuidString, content: content, trigger: trigger
        )
    }
}
