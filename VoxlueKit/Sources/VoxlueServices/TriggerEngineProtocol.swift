import Foundation

/// 显影触发引擎 —— App 的心脏，纯后台、不依赖 UI。
/// 路线图 §3.2 冻结契约，签名不可改。
@MainActor public protocol TriggerEngineProtocol: AnyObject {
    /// 让某枚胶囊进入 developing（被围栏 / 通知 / agent 调用）。
    func surface(capsuleID: UUID) async
    /// App 启动 / 后台刷新时全量重扫过期时间锁与命中地点锁。
    func reconcile() async
    /// 当前正在显影中的胶囊（驱动灵动岛 UI）。
    var developingCapsuleIDs: [UUID] { get }
}

/// 假触发引擎 —— 供预览与 UI 测试，`surface` 即记一笔，不碰任何平台能力。
@MainActor public final class FakeTriggerEngine: TriggerEngineProtocol {
    public private(set) var developingCapsuleIDs: [UUID] = []
    public private(set) var reconcileCount = 0

    public init(developingCapsuleIDs: [UUID] = []) {
        self.developingCapsuleIDs = developingCapsuleIDs
    }

    public func surface(capsuleID: UUID) async {
        guard !developingCapsuleIDs.contains(capsuleID) else { return }
        developingCapsuleIDs.append(capsuleID)
    }

    public func reconcile() async {
        reconcileCount += 1
    }
}
