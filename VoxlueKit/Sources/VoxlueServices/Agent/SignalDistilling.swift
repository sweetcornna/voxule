import Foundation

/// 端侧脱敏闸门：HealthKit 原始数据 → StateDigest。原始数据永不出设备。
public protocol SignalDistilling: Sendable {
    func distill() async -> StateDigest
}

/// 假实现 —— 返回脚本化摘要，供预览与单元测试。
public struct FakeSignalDistilling: SignalDistilling {
    private let scripted: StateDigest

    public init(digest: StateDigest) {
        self.scripted = digest
    }

    /// 一个中性默认值，便于预览。
    public init() {
        self.scripted = StateDigest(
            tension: .medium, sleep: .medium,
            calmCapsulesAvailable: 3, daysSinceLastSurfacing: 5
        )
    }

    public func distill() async -> StateDigest { scripted }
}
