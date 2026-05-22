//
//  voxuleApp.swift
//  voxule
//

import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

@main
struct voxuleApp: App {
    private let modelContainer: ModelContainer
    private let appEnvironment: AppEnvironment
    @State private var dependencies: AppDependencies
    @State private var services: ServiceContainer
    @State private var shareRouter: DeepLinkRouter

    init() {
        // 优先用生产配置 —— 镜像到 CloudKit 私有库。
        // 若 CloudKit 不可用（未登录 iCloud、缺少能力配置等），降级为纯本地存储。
        let container: ModelContainer
        if let cloudContainer = try? VoxlueModelContainer.make() {
            container = cloudContainer
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
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appEnvironment, appEnvironment)
                .environment(dependencies)
                .environment(services)
                .environment(shareRouter)
                .task { await dependencies.bootstrap() }
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
    }

    /// 接受流程进行中或已出结果时，弹落地页。
    private var shareAcceptanceSheetBinding: Binding<Bool> {
        Binding(
            get: { shareRouter.acceptance != .idle },
            set: { if !$0 { shareRouter.reset() } }
        )
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
