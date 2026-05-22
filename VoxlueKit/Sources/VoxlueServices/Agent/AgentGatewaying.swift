import Foundation

/// 云端 agent 网关：构建请求、接收工具调用、派发、循环。
@MainActor public protocol AgentGatewaying: AnyObject {
    /// 跑一轮情绪浮现闭环；返回 agent 是否决定浮现及浮现哪枚。
    func runSurfacingCycle() async throws -> SurfacingDecision
}

/// 一轮闭环的最终决定。
public enum SurfacingDecision: Sendable, Equatable {
    case surface(capsuleID: UUID)
    case hold
}

/// 假实现 —— 返回脚本化决定，供前端预览浮现卡。
@MainActor
public final class FakeAgentGateway: AgentGatewaying {
    private let scripted: SurfacingDecision

    public init(decision: SurfacingDecision = .hold) {
        self.scripted = decision
    }

    public func runSurfacingCycle() async throws -> SurfacingDecision { scripted }
}
