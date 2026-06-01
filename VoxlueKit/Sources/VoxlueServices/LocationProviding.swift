import Foundation

/// 定位 wrapper（平台能力层）。路线图 §3.2 冻结契约，签名不可改。
/// 真实现见 `CLLocationProvider`，假实现见下。
public protocol LocationProviding: Sendable {
    func requestPermission() async -> Bool
    /// 把这批围栏交给系统监听（内部已按「最近 20 个」裁剪）。
    func monitor(regions: [GeofenceRegion]) async
    /// 进入围栏事件流。
    var events: AsyncStream<GeofenceEvent> { get }
}

/// 假定位 —— 不碰 CoreLocation，供预览、单元测试与引擎注入。
/// 测试可用 `simulateEntry` 手动注入进入围栏事件。
public final class FakeLocationProviding: LocationProviding, @unchecked Sendable {
    public private(set) var monitoredRegions: [GeofenceRegion] = []
    public var permissionGranted = true

    private let continuation: AsyncStream<GeofenceEvent>.Continuation
    public let events: AsyncStream<GeofenceEvent>

    public init() {
        var captured: AsyncStream<GeofenceEvent>.Continuation!
        events = AsyncStream { captured = $0 }
        continuation = captured
    }

    deinit {
        // 与真实现一致：释放时收尾事件流，消费者的 `for await` 才会正常结束（D15）。
        continuation.finish()
    }

    public func requestPermission() async -> Bool { permissionGranted }

    public func monitor(regions: [GeofenceRegion]) async {
        monitoredRegions = regions
    }

    /// 测试钩子：模拟用户走进某枚胶囊的围栏。
    public func simulateEntry(capsuleID: UUID) {
        continuation.yield(.entered(capsuleID: capsuleID))
    }
}
