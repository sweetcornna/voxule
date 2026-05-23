//
//  voxuleApp.swift
//  voxule
//

import SwiftUI
import SwiftData
import BackgroundTasks
import VoxlueData
import VoxlueDesign
import VoxlueServices

@main
struct voxuleApp: App {
    private let modelContainer: ModelContainer
    private let appEnvironment: AppEnvironment
    @State private var dependencies: AppDependencies
    @State private var services: ServiceContainer
    @State private var shareRouter: DeepLinkRouter
    @State private var healthEnv: HealthEnv

    /// 首次启动引导是否已看过。@AppStorage 走 UserDefaults，CloudKit 不同步 —— 每台设备各看一次。
    @AppStorage("voxlue.hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    /// serverless 代理地址 —— Task 8 部署后填入真实 Worker 地址。
    static let agentProxyURL = URL(string: "https://voxlue-agent-proxy.example.workers.dev")!

    /// 情绪浮现后台任务标识 —— 须与 Info.plist `BGTaskSchedulerPermittedIdentifiers` 一致。
    static let surfacingTaskID = "com.voxlue.app.agent.surfacing"

    /// 当前 ModelContainer 是否走 CloudKit 镜像 —— DEBUG Dev 工具据此禁用「清空」按钮，
    /// 避免顺手把用户 iCloud 私有库的真胶囊也一并删掉。
    @MainActor static private(set) var isCloudKitMirrored = false

    /// 自定义字体（Crimson Pro · 思源宋 · Space Mono · Caveat）注册一次性副作用。
    /// 用 static let 而不是在 init 里调 —— 进程级状态归进程级初始化，
    /// SwiftUI Preview / 单测重新实例化 App 时也不会重复跑。
    private static let _fontsRegistered: Void = {
        VoxlueFontRegistrar.registerAll()
    }()

    init() {
        _ = Self._fontsRegistered

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

        // 测试环境（-uiTestFakeAudio 或 XCTest 注入）直接当作「已看过引导」，
        // sheet 永不弹起，免得挡住 testRecordBuryPlayMainLoop 的第一帧点击。
        // 注意：这里要走 _hasSeenOnboarding 的底层 storage —— @AppStorage 的 wrapper
        // 在 init 阶段还没绑 SwiftUI scene，直接赋值会被 wrapper 拦住。改写 UserDefaults
        // 是最稳的做法。
        if Self.isRunningTests {
            UserDefaults.standard.set(true, forKey: "voxlue.hasSeenOnboarding")
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
                .tint(VoxlueColor.vermillion)
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
                // 首次启动 3 页引导 —— 仅当 hasSeenOnboarding 为 false 时弹一次；
                // 用 .task 起手代替直接 isPresented 绑定，避开与 fullScreenCover、
                // shareAcceptanceSheet 同帧抢演的边界。
                .task {
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
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

    /// 测试环境判定 —— UI 测试用 `-uiTestFakeAudio` 启动参数；单测靠
    /// `XCTestSessionIdentifier` 环境变量。两条任一成立都视作测试，
    /// 跳过首次启动引导，免得挡住 sheet/cover 主路径。
    private static var isRunningTests: Bool {
        if ProcessInfo.processInfo.arguments.contains("-uiTestFakeAudio") {
            return true
        }
        if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil {
            return true
        }
        return false
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
