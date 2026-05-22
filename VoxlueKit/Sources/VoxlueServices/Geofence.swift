import Foundation

/// 一个地理围栏 —— 对应一枚地点锁胶囊的解锁圈。
/// 路线图 §3.2 冻结契约，签名不可改。
public struct GeofenceRegion: Sendable, Hashable {
    public let capsuleID: UUID
    public let latitude, longitude, radius: Double

    public init(capsuleID: UUID, latitude: Double, longitude: Double, radius: Double) {
        self.capsuleID = capsuleID
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}

/// 进入围栏事件。路线图 §3.2 冻结契约。
public enum GeofenceEvent: Sendable, Equatable {
    case entered(capsuleID: UUID)
}
