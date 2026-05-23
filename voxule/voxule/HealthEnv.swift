import Foundation
import VoxlueServices

/// 壳层 HealthKit wrapper holder —— 仅供「陪伴授权」设置页复用同一份 provider。
/// 不揽 agent gateway / trigger / location 等重资源，避免与 `AppDependencies`、
/// `AgentContainer` 重复持有 `CLLocationManager` 之类的进程级单例。
@MainActor
@Observable
final class HealthEnv {
    let provider: any HealthProviding

    init() {
        #if os(iOS)
        self.provider = HealthKitHealthProvider()
        #else
        self.provider = FakeHealthProviding(snapshot: nil)
        #endif
    }

    /// 预览 / 测试用 —— 传入假实现。
    init(provider: any HealthProviding) {
        self.provider = provider
    }
}
