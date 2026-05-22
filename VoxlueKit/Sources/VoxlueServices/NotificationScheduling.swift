import Foundation

/// 本地通知调度（时间锁兜底）。路线图 §3.2 冻结契约，签名不可改。
/// 真实现见 `UNNotificationService`，假实现见下。
public protocol NotificationScheduling: Sendable {
    func requestPermission() async -> Bool
    /// 为一枚时间锁胶囊注册到点通知。
    func scheduleDateLock(capsuleID: UUID, fireAt date: Date) async throws
    /// 取消某枚胶囊的待发通知。
    func cancel(capsuleID: UUID) async
}

/// 假通知调度 —— 不碰 UserNotifications，记录被调度的胶囊供断言。
public final class FakeNotificationScheduling: NotificationScheduling, @unchecked Sendable {
    public private(set) var scheduled: [UUID: Date] = [:]
    public var permissionGranted = true

    public init() {}

    public func requestPermission() async -> Bool { permissionGranted }

    public func scheduleDateLock(capsuleID: UUID, fireAt date: Date) async throws {
        scheduled[capsuleID] = date
    }

    public func cancel(capsuleID: UUID) async {
        scheduled[capsuleID] = nil
    }
}
