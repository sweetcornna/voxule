import Foundation
import CoreLocation

/// 地理围栏调度器 —— spec §6 的核心约束所在。
///
/// iOS 一个 App 最多同时监听 20 个 `CLCircularRegion`。当地点锁胶囊多于 20 枚时，
/// 必须只把「离用户最近的 20 个」装进系统监听；用户位置显著变化时重新排序轮换。
///
/// 本类型是**无状态纯函数**，不持有定位、不持有系统监听句柄 —— 便于直接用假围栏与
/// 假用户坐标做单元测试。
public enum GeofenceScheduler {

    /// iOS 系统允许的同时监听围栏上限。
    public static let systemLimit = 20

    /// 从一批围栏里裁出离用户最近的至多 20 个，按距离升序返回。
    /// - Parameters:
    ///   - userLocation: 用户当前经纬度。
    ///   - regions: 全部候选围栏（私有与圈内胶囊一视同仁）。
    /// - Returns: 最近的至多 `systemLimit` 个，最近的在前。
    public static func nearest(
        to userLocation: (latitude: Double, longitude: Double),
        from regions: [GeofenceRegion]
    ) -> [GeofenceRegion] {
        let origin = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let sorted = regions.sorted { lhs, rhs in
            distance(from: origin, to: lhs) < distance(from: origin, to: rhs)
        }
        return Array(sorted.prefix(systemLimit))
    }

    /// 用户位置变化是否大到需要重排（significant location change 粒度，约 500 米）。
    public static let resortThresholdMeters: Double = 500

    /// 判断两个用户位置之间是否值得触发一次重排。
    public static func shouldResort(
        from old: (latitude: Double, longitude: Double),
        to new: (latitude: Double, longitude: Double)
    ) -> Bool {
        let a = CLLocation(latitude: old.latitude, longitude: old.longitude)
        let b = CLLocation(latitude: new.latitude, longitude: new.longitude)
        return a.distance(from: b) >= resortThresholdMeters
    }

    private static func distance(from origin: CLLocation, to region: GeofenceRegion) -> Double {
        origin.distance(from: CLLocation(latitude: region.latitude, longitude: region.longitude))
    }

    /// 决定应把哪批围栏交给系统监听。
    /// - 有定位：按最近裁出至多 20 个。
    /// - 无定位且能全装下（≤20）：全装。
    /// - 无定位且超额：返回 `nil` 表示「维持现状」—— 绝不按 (0,0) 乱排选错的 20 个，
    ///   等首次定位到达再裁（D16）。
    public static func regionsToMonitor(
        userLocation: (latitude: Double, longitude: Double)?,
        from regions: [GeofenceRegion]
    ) -> [GeofenceRegion]? {
        if let userLocation {
            return nearest(to: userLocation, from: regions)
        }
        if regions.count <= systemLimit {
            return regions
        }
        return nil
    }

    /// 把围栏半径夹到系统可监听区间 `[1, maxRadius]`（D17）。
    /// 超过 `CLLocationManager.maximumRegionMonitoringDistance` 时系统会静默不监听；
    /// 半径 ≤ 0 同样非法。夹紧保证围栏一定被系统接受。
    public static func clampedRadius(_ radius: Double, max maxRadius: Double) -> Double {
        min(Swift.max(radius, 1), maxRadius)
    }
}
