import Foundation

/// 胶囊的锁 —— 解锁条件。三选一。
/// 作为一个属性存在 Capsule 上，不单独建表。
public enum Lock: Codable, Hashable, Sendable {
    /// 地点锁：经纬度 + 半径（米）+ 地名。
    case place(latitude: Double, longitude: Double, radius: Double, placeName: String)
    /// 时间锁：未来某一天。
    case date(Date)
    /// 情绪锁：主动浮现。notBefore 之前不浮现。
    case mood(notBefore: Date?)

    /// 锁的种类，便于不取关联值时判断。
    public enum Kind: String, Sendable {
        case place, date, mood
    }

    public var kind: Kind {
        switch self {
        case .place: .place
        case .date: .date
        case .mood: .mood
        }
    }
}
