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

extension Lock {
    /// payload 损坏时按 kind 回退到一把「绝不自动浮现」的安全锁（D11）。
    /// 定时锁回退到 distantFuture、地点锁回退到半径 0（围栏不监听）、情绪锁回退到
    /// notBefore distantFuture —— 任何回退都只会让锁更难触发，绝不更易触发。
    static func safeFallback(forKindRaw kindRaw: String) -> Lock {
        switch Kind(rawValue: kindRaw) {
        case .date:
            return .date(.distantFuture)
        case .place:
            return .place(latitude: 0, longitude: 0, radius: 0, placeName: "")
        case .mood, .none:
            return .mood(notBefore: .distantFuture)
        }
    }
}
