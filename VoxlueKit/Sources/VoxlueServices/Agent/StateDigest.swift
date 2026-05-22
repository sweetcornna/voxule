import Foundation

/// 端侧脱敏后越过网络边界的抽象摘要 —— 唯一出设备的健康相关数据。
///
/// 合规铁律（架构文档 §7 / §10）：原始健康数据（心率、HRV、睡眠时长、
/// `HKStateOfMind` 心情分值）永不进入此结构。这里只存抽象的 `Level` 枚举
/// 与计数，无法回指到具体个人或具体体征读数。
public struct StateDigest: Sendable, Codable {
    /// 紧绷度。
    public let tension: Level
    /// 睡眠质量。
    public let sleep: Level
    /// 当前可用的「平静」类胶囊数量。
    public let calmCapsulesAvailable: Int
    /// 距上一次情绪浮现的天数。
    public let daysSinceLastSurfacing: Int

    /// 三档抽象等级 —— 不是分数、不是读数。
    public enum Level: String, Sendable, Codable {
        case low, medium, high
    }

    public init(
        tension: Level,
        sleep: Level,
        calmCapsulesAvailable: Int,
        daysSinceLastSurfacing: Int
    ) {
        self.tension = tension
        self.sleep = sleep
        self.calmCapsulesAvailable = calmCapsulesAvailable
        self.daysSinceLastSurfacing = daysSinceLastSurfacing
    }
}
