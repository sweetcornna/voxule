// CLAuthorizationStatus.authorizedWhenInUse 等 API 在 macOS 不可用 ——
// 整个文件用 #if os(iOS) 守卫；真实现只在 App（iOS）构建时编译。
#if os(iOS)
import Foundation
import CoreLocation

/// `LocationProviding` 的 CoreLocation 真实现。
///
/// 关键约束（spec §6）：iOS 一个 App 最多同时监听 20 个 `CLCircularRegion`。
/// `monitor(regions:)` 内部用当前用户位置跑 `GeofenceScheduler.nearest` 裁出最近 20 个；
/// 监听 significant location change，用户位置显著变化时自动重排轮换。
public final class CLLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager = CLLocationManager()
    private let continuation: AsyncStream<GeofenceEvent>.Continuation
    public let events: AsyncStream<GeofenceEvent>

    /// 当前申请权限的回调（一次性）。
    private var permissionContinuation: CheckedContinuation<Bool, Never>?
    /// 全量候选围栏 —— 用户移动时据此重排。
    private var allRegions: [GeofenceRegion] = []
    /// 当前正在被系统监听的围栏数（测试可读）。
    public private(set) var monitoredRegionCount = 0

    public override init() {
        var captured: AsyncStream<GeofenceEvent>.Continuation!
        events = AsyncStream { captured = $0 }
        continuation = captured
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - LocationProviding

    public func requestPermission() async -> Bool {
        if manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse {
            return true
        }
        return await withCheckedContinuation { continuation in
            permissionContinuation = continuation
            manager.requestAlwaysAuthorization()
        }
    }

    public func monitor(regions: [GeofenceRegion]) async {
        allRegions = regions
        manager.startMonitoringSignificantLocationChanges()
        applyNearestRegions()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = permissionContinuation else { return }
        permissionContinuation = nil
        let granted = manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse
        continuation.resume(returning: granted)
    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        // significant location change 触发 —— 重新排序轮换围栏。
        applyNearestRegions()
    }

    public func locationManager(
        _ manager: CLLocationManager, didEnterRegion region: CLRegion
    ) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        continuation.yield(.entered(capsuleID: id))
    }

    // MARK: - 私有

    /// 用当前用户位置裁出最近 20 个围栏，替换系统监听集。
    private func applyNearestRegions() {
        let user = manager.location.map {
            (latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        } ?? (latitude: 0, longitude: 0)

        let nearest = GeofenceScheduler.nearest(to: user, from: allRegions)

        // 先停掉旧的，再装新的 —— 永不越过 20 上限。
        for monitored in manager.monitoredRegions {
            manager.stopMonitoring(for: monitored)
        }
        for region in nearest {
            let circular = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: region.latitude, longitude: region.longitude
                ),
                radius: region.radius,
                identifier: region.capsuleID.uuidString
            )
            circular.notifyOnEntry = true
            circular.notifyOnExit = false
            manager.startMonitoring(for: circular)
        }
        monitoredRegionCount = nearest.count
    }
}
#endif
