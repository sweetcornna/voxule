import Foundation
import VoxlueData

/// 端侧脱敏闸门真实现。
///
/// 职责：把 `HealthSnapshot` 原始读数 + `CapsuleStore` 上下文映射为抽象
/// `StateDigest`。**原始读数只在本类内部存在，函数返回时只剩 `Level` 与计数。**
///
/// 注意（架构文档 §6）：这里不是在「打分」或做规则判断 —— 它只是把
/// 连续读数收敛到三档抽象，真正决定是否浮现的是云端 agent，不是这些阈值。
public struct SignalDistiller: SignalDistilling {
    private let health: HealthProviding
    private let store: CapsuleStore

    public init(health: HealthProviding, store: CapsuleStore) {
        self.health = health
        self.store = store
    }

    public func distill() async -> StateDigest {
        let snapshot = await health.snapshot()
        let tension = Self.tensionLevel(from: snapshot)
        let sleep = Self.sleepLevel(from: snapshot?.sleepHours)
        // 单次取全表，派生两个上下文指标 —— 避免一轮 distill 多次全表 fetch（D21）。
        let (calm, days) = await capsuleContext()
        return StateDigest(
            tension: tension,
            sleep: sleep,
            calmCapsulesAvailable: calm,
            daysSinceLastSurfacing: days
        )
    }

    // MARK: - 原始读数 → 抽象 Level（映射只在设备内）

    /// 紧绷度：综合负心情、低 HRV、高静息心率。无数据时取 medium。
    /// 阈值刻意偏「不打扰」：`.high` 需两个负向信号，`.low` 一个正向信号即可 ——
    /// 宁可少判定紧绷，也不轻易催 agent 浮现。
    static func tensionLevel(from snapshot: HealthSnapshot?) -> StateDigest.Level {
        guard let snapshot else { return .medium }
        var score = 0
        if let v = snapshot.moodValence { score += v < -0.2 ? 1 : (v > 0.2 ? -1 : 0) }
        if let hrv = snapshot.hrvSDNN { score += hrv < 25 ? 1 : (hrv > 55 ? -1 : 0) }
        if let rhr = snapshot.restingHeartRate { score += rhr > 75 ? 1 : (rhr < 58 ? -1 : 0) }
        if score >= 2 { return .high }
        if score <= -1 { return .low }
        return .medium
    }

    /// 睡眠质量。无数据时取 medium。
    static func sleepLevel(from hours: Double?) -> StateDigest.Level {
        guard let hours else { return .medium }
        if hours < 5.5 { return .low }
        if hours >= 7.0 { return .high }
        return .medium
    }

    // MARK: - App 上下文（非健康，可粗粒度参与摘要）

    /// 单次取全表，在 MainActor 上派生「平静胶囊数」与「距上次浮现天数」（D21）。
    @MainActor
    private func capsuleContext() -> (calm: Int, days: Int) {
        let all = (try? store.allCapsules()) ?? []
        return (Self.calmCapsuleCount(from: all), Self.daysSinceLastSurfacing(from: all))
    }

    static func calmCapsuleCount(from all: [Capsule]) -> Int {
        let calmTags: Set<String> = ["平静", "calm", "安心", "海", "雨"]
        return all.filter { capsule in
            capsule.lockKind == .mood
                && !Set(capsule.tags).isDisjoint(with: calmTags)
        }.count
    }

    static func daysSinceLastSurfacing(from all: [Capsule]) -> Int {
        // 最近一次「浮现过」的情绪胶囊的浮现时刻。纳入 .developing（已浮现未开启）——
        // 旧实现漏了 developing、且用 createdAt 兜底，会把「刚浮现」误报成几个月前，
        // 致 agent 误判很久没浮现而过度打扰（D12）。优先用真实浮现时刻 surfacedAt。
        let lastSurfaced = all
            .filter {
                $0.lockKind == .mood
                    && ($0.state == .developing || $0.state == .developed || $0.state == .opened)
            }
            .compactMap { $0.surfacedAt ?? $0.openedAt }
            .max()
        guard let last = lastSurfaced else { return 99 }
        return max(0, Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0)
    }
}
