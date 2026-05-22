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
    private let appEnvironment = AppEnvironment.live()

    init() {
        // 优先用生产配置 —— 镜像到 CloudKit 私有库。
        // 若 CloudKit 不可用（未登录 iCloud、缺少能力配置等），降级为纯本地存储。
        if let cloudContainer = try? VoxlueModelContainer.make() {
            modelContainer = cloudContainer
        } else {
            do {
                modelContainer = try ModelContainer(
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
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appEnvironment, appEnvironment)
        }
        .modelContainer(modelContainer)
    }
}
