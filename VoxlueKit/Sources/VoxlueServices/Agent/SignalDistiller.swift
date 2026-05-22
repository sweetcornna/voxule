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
        let calm = await calmCapsuleCount()
        let days = await daysSinceLastSurfacing()
        return StateDigest(
            tension: tension,
            sleep: sleep,
            calmCapsulesAvailable: calm,
            daysSinceLastSurfacing: days
        )
    }

    // MARK: - 原始读数 → 抽象 Level（映射只在设备内）

    /// 紧绷度：综合负心情、低 HRV、高静息心率。无数据时取 medium。
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

    @MainActor
    private func calmCapsuleCount() async -> Int {
        let all = (try? store.allCapsules()) ?? []
        let calmTags: Set<String> = ["平静", "calm", "安心", "海", "雨"]
        return all.filter { capsule in
            capsule.lock.kind == .mood
                && !Set(capsule.tags).isDisjoint(with: calmTags)
        }.count
    }

    @MainActor
    private func daysSinceLastSurfacing() async -> Int {
        let all = (try? store.allCapsules()) ?? []
        // 最近一次「已显影/已开启」的情绪胶囊的 openedAt（或 createdAt）。
        let surfaced = all
            .filter { $0.lock.kind == .mood && ($0.state == .developed || $0.state == .opened) }
            .compactMap { $0.openedAt ?? $0.createdAt }
            .max()
        guard let last = surfaced else { return 99 }
        return max(0, Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0)
    }
}
