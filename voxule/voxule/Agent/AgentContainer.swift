import Foundation
import SwiftData
import VoxlueData
import VoxlueServices

/// agent 闭环的依赖装配点（App 壳层）。
/// MV 模式：直接持有具体服务，不套 ViewModel。
@MainActor
@Observable
final class AgentContainer {
    let gateway: any AgentGatewaying
    let intelligence: any IntelligenceServicing
    /// HealthKit wrapper —— 给设置页授权请求复用同一实例。
    let health: any HealthProviding

    /// 生产装配 —— 真服务 + 真代理。
    /// - Parameter proxyURL: serverless 代理地址（Task 8 部署后得到）。
    init(modelContext: ModelContext, proxyURL: URL) {
        let store = CapsuleStore(context: modelContext)
        #if os(iOS)
        let health: any HealthProviding = HealthKitHealthProvider()
        #else
        let health: any HealthProviding = FakeHealthProviding(snapshot: nil)
        #endif
        self.health = health
        let distiller = SignalDistiller(health: health, store: store)
        let client = HTTPRemoteModelClient(proxyURL: proxyURL)
        // 后台轮里现装一个 TriggerEngine —— 它读 SwiftData、surface() 只更新
        // 胶囊状态并起 Live Activity，无需复用壳层那个实例。
        let trigger = TriggerEngine(
            store: store,
            location: CLLocationProvider(),
            notifications: UNNotificationService(),
            liveActivity: LiveActivityController()
        )
        self.gateway = AgentGateway(
            distiller: distiller, client: client, trigger: trigger, store: store,
            cadence: CadenceSetting.current.rawValue
        )
        self.intelligence = IntelligenceService()
    }

    /// 预览/测试装配 —— 全假实现。
    init(previewDecision: SurfacingDecision = .hold) {
        self.gateway = FakeAgentGateway(decision: previewDecision)
        self.intelligence = FakeIntelligenceServicing(title: "窗外的雨声")
        self.health = FakeHealthProviding(snapshot: nil)
    }

    /// 后台唤醒入口 —— BGTaskScheduler 在安静时段调它。
    /// 跑一轮情绪浮现闭环；浮现决定已在闭环内派发给 TriggerEngine。
    func handleBackgroundSurfacing() async {
        do {
            let decision = try await gateway.runSurfacingCycle()
            switch decision {
            case .surface:
                break   // surface 已在闭环内调用 TriggerEngine.surface，灵动岛随即起。
            case .hold:
                break   // 本轮不打扰。
            }
        } catch {
            // 后台任务失败静默 —— 不打扰用户，下次唤醒再试。
        }
    }
}
