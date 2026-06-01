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

    /// 可变状态由 `stateLock` 串行化 —— CL 代理回调来自系统线程，monitor() 来自调用方
    /// 线程，二者并发读写 allRegions / permissionContinuation / count 会数据竞争（D14）。
    private let stateLock = NSLock()
    /// 当前申请权限的回调（一次性）。stateLock 保护。
    private var permissionContinuation: CheckedContinuation<Bool, Never>?
    /// 全量候选围栏 —— 用户移动时据此重排。stateLock 保护。
    private var allRegions: [GeofenceRegion] = []
    /// 当前正在被系统监听的围栏数（测试可读）。stateLock 保护。
    private var _monitoredRegionCount = 0
    public var monitoredRegionCount: Int { stateLock.withLock { _monitoredRegionCount } }

    public override init() {
        var captured: AsyncStream<GeofenceEvent>.Continuation!
        events = AsyncStream { captured = $0 }
        continuation = captured
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    deinit {
        // 流必须显式收尾 —— 否则消费者的 `for await` 永不结束、任务泄漏挂起（D15）。
        continuation.finish()
    }

    // MARK: - LocationProviding

    public func requestPermission() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .denied, .restricted:
            // iOS 此时既不弹窗也不再回调 didChangeAuthorization —— 必须立即返回，
            // 否则 continuation 永不 resume、调用方永久挂起（D5）。
            return false
        default:
            break   // .notDetermined：走申请流程。
        }
        // 防重入：已有等待中的申请就不再覆盖（旧实现会泄漏首个 continuation）（D5）。
        let alreadyWaiting = stateLock.withLock { permissionContinuation != nil }
        if alreadyWaiting { return false }
        return await withCheckedContinuation { continuation in
            stateLock.withLock { permissionContinuation = continuation }
            manager.requestAlwaysAuthorization()
        }
    }

    public func monitor(regions: [GeofenceRegion]) async {
        stateLock.withLock { allRegions = regions }
        manager.startMonitoringSignificantLocationChanges()
        applyNearestRegions()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let continuation = stateLock.withLock {
            let c = permissionContinuation
            permissionContinuation = nil
            return c
        }
        guard let continuation else { return }
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
        // 无定位（冷启动常见）时不按 (0,0) 乱排：能全装下就全装，超额则维持现状，
        // 等首次定位到达再裁（D16）。
        let user: (latitude: Double, longitude: Double)? = manager.location.map {
            (latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        let snapshot = stateLock.withLock { allRegions }
        guard let nearest = GeofenceScheduler.regionsToMonitor(userLocation: user, from: snapshot) else {
            return   // 无定位且超额 —— 保持当前监听集不动。
        }

        // 先停掉旧的，再装新的 —— 永不越过 20 上限。
        for monitored in manager.monitoredRegions {
            manager.stopMonitoring(for: monitored)
        }
        let maxRadius = manager.maximumRegionMonitoringDistance
        for region in nearest {
            let circular = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: region.latitude, longitude: region.longitude
                ),
                // 半径夹到系统可监听区间，否则超限会被静默忽略、围栏永不触发（D17）。
                radius: GeofenceScheduler.clampedRadius(region.radius, max: maxRadius),
                identifier: region.capsuleID.uuidString
            )
            circular.notifyOnEntry = true
            circular.notifyOnExit = false
            manager.startMonitoring(for: circular)
        }
        stateLock.withLock { _monitoredRegionCount = nearest.count }
    }
}
#endif
