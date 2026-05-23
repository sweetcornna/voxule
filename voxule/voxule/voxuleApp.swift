//
//  voxuleApp.swift
//  voxule
//

import SwiftUI
import SwiftData
import BackgroundTasks
import VoxlueData
import VoxlueServices

@main
struct voxuleApp: App {
    private let modelContainer: ModelContainer
    private let appEnvironment: AppEnvironment
    @State private var dependencies: AppDependencies
    @State private var services: ServiceContainer
    @State private var shareRouter: DeepLinkRouter
    @State private var healthEnv: HealthEnv

    /// serverless 代理地址 —— Task 8 部署后填入真实 Worker 地址。
    static let agentProxyURL = URL(string: "https://voxlue-agent-proxy.example.workers.dev")!

    /// 情绪浮现后台任务标识 —— 须与 Info.plist `BGTaskSchedulerPermittedIdentifiers` 一致。
    static let surfacingTaskID = "com.voxlue.app.agent.surfacing"

    /// 当前 ModelContainer 是否走 CloudKit 镜像 —— DEBUG Dev 工具据此禁用「清空」按钮，
    /// 避免顺手把用户 iCloud 私有库的真胶囊也一并删掉。
    @MainActor static private(set) var isCloudKitMirrored = false

    init() {
        // 优先用生产配置 —— 镜像到 CloudKit 私有库。
        // 若 CloudKit 不可用（未登录 iCloud、缺少能力配置等），降级为纯本地存储。
        let container: ModelContainer
        if let cloudContainer = try? VoxlueModelContainer.make() {
            container = cloudContainer
            Self.isCloudKitMirrored = true
        } else {
            do {
                container = try ModelContainer(
                    for: VoxlueModelContainer.schema,
                    configurations: ModelConfiguration(
                        schema: VoxlueModelContainer.schema,
                        cloudKitDatabase: .none
                    )
                )
            } catch {
                fatalError("无法创建本地 ModelContainer：\(error)")
            }
        }
        modelContainer = container

        // UI 测试用 -uiTestFakeAudio 启动参数注入假音频服务，避开真麦克风与权限弹窗。
        if ProcessInfo.processInfo.arguments.contains("-uiTestFakeAudio") {
            appEnvironment = .preview()
        } else {
            appEnvironment = .live()
        }

        let deps = AppDependencies(modelContainer: container)
        // BGTask launch handler 须在 App 启动完成前注册。
        deps.registerBackgroundTasks()
        _dependencies = State(initialValue: deps)

        let serviceContainer = ServiceContainer(modelContext: container.mainContext)
        _services = State(initialValue: serviceContainer)
        _shareRouter = State(
            initialValue: DeepLinkRouter(circleService: serviceContainer.circleService)
        )
        _healthEnv = State(initialValue: HealthEnv())
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appEnvironment, appEnvironment)
                .environment(dependencies)
                .environment(services)
                .environment(shareRouter)
                .environment(healthEnv)
                .task {
                    await dependencies.bootstrap()
                    // 排第一次浮现唤醒 —— .backgroundTask 只注册处理器、不提交请求，
                    // 没有这一步整条 agent 闭环永不触发。幂等：同标识请求会被替换。
                    await Self.scheduleNextSurfacing()
                }
                // 进站深链：CKShare 邀请 → 声音圈路由；voxlue://capsule → 胶囊路由。
                .onCloudKitShareAccepted { url in
                    shareRouter.handleIncomingShare(url: url)
                }
                .onOpenURL { url in
                    if FakeCircleServicing.looksLikeShareURL(url) {
                        shareRouter.handleIncomingShare(url: url)
                    } else {
                        dependencies.router.handle(url: url)
                    }
                }
                .sheet(isPresented: shareAcceptanceSheetBinding) {
                    AcceptInvitationView()
                        .environment(shareRouter)
                }
        }
        .modelContainer(modelContainer)
        // 安静时段被唤醒 → 跑一轮 agent 情绪浮现闭环。
        .backgroundTask(.appRefresh(Self.surfacingTaskID)) {
            await Self.runSurfacingTask(modelContainer: modelContainer)
        }
    }

    /// 接受流程进行中或已出结果时，弹落地页。
    private var shareAcceptanceSheetBinding: Binding<Bool> {
        Binding(
            get: { shareRouter.acceptance != .idle },
            set: { if !$0 { shareRouter.reset() } }
        )
    }

    /// 后台唤醒处理 —— 整段在 MainActor 上跑，避免 ModelContext 跨隔离传递。
    @MainActor
    private static func runSurfacingTask(modelContainer: ModelContainer) async {
        let container = AgentContainer(
            modelContext: modelContainer.mainContext, proxyURL: agentProxyURL
        )
        await container.handleBackgroundSurfacing()
        await scheduleNextSurfacing()
    }

    /// 排下一次浮现唤醒。频率按 cadence 设置调整（轻轻地/偶尔/关）。
    @MainActor
    static func scheduleNextSurfacing() async {
        let cadence = CadenceSetting.current
        guard cadence != .off else { return }   // 「关」则不再排。
        let request = BGAppRefreshTaskRequest(identifier: surfacingTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: cadence.interval)
        try? BGTaskScheduler.shared.submit(request)
    }
}

/// SwiftUI 把进站 CKShare 链接交给 App 的修饰符封装。
/// 用 `onContinueUserActivity` 接 CloudKit 共享元数据 activity，统一回吐 share URL。
private struct CloudKitShareAcceptedModifier: ViewModifier {
    let handler: (URL) -> Void

    func body(content: Content) -> some View {
        content.onContinueUserActivity(
            "com.apple.coredata.cloudkit.share"
        ) { activity in
            if let url = activity.webpageURL {
                handler(url)
            }
        }
    }
}

private extension View {
    func onCloudKitShareAccepted(_ handler: @escaping (URL) -> Void) -> some View {
        modifier(CloudKitShareAcceptedModifier(handler: handler))
    }
}
