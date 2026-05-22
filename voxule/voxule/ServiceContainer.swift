import Foundation
import SwiftData
import VoxlueData
import VoxlueServices

/// App 壳层的声音圈服务容器 —— 装配 `CircleServicing`，注入 SwiftUI 环境。
/// 与 `AppEnvironment`（音频）、`AppDependencies`（触发引擎）并列，各管一摊。
@MainActor
@Observable
final class ServiceContainer {

    /// 声音圈服务（计划 05）。
    let circleService: any CircleServicing

    init(modelContext: ModelContext) {
        self.circleService = CircleService(modelContext: modelContext)
    }

    private init(circleService: any CircleServicing) {
        self.circleService = circleService
    }

    /// 预览 / UI 测试用 —— 服务走假实现，预置两个圈。
    static func preview() -> ServiceContainer {
        ServiceContainer(circleService: FakeCircleServicing(circles: [
            Circle(name: "家", ownerID: "me"),
            Circle(name: "大学室友", ownerID: "me"),
        ]))
    }

    /// 预览用 —— 没有任何圈的空状态。
    static func previewEmpty() -> ServiceContainer {
        ServiceContainer(circleService: FakeCircleServicing())
    }
}
