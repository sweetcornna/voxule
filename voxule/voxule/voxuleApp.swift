//
//  voxuleApp.swift
//  voxule
//

import SwiftUI
import SwiftData
import VoxlueData

@main
struct voxuleApp: App {
    private let modelContainer: ModelContainer
    private let appEnvironment: AppEnvironment
    @State private var dependencies: AppDependencies

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
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appEnvironment, appEnvironment)
                .environment(dependencies)
                .task { await dependencies.bootstrap() }
                .onOpenURL { url in
                    dependencies.router.handle(url: url)
                }
        }
        .modelContainer(modelContainer)
    }
}
