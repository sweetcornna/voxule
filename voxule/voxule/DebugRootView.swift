//
//  DebugRootView.swift
//  voxule
//
//  临时调试视图，验证数据层端到端可用。计划 02 替换为样片墙。
//

import SwiftUI
import SwiftData
import VoxlueData

// 数据模型 `Capsule` 与 SwiftUI 内置形状 `SwiftUI.Capsule` 同名，
// 在同时 import SwiftUI 与 VoxlueData 的文件里须写全 `VoxlueData.Capsule` 消歧义。
struct DebugRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    var body: some View {
        NavigationStack {
            List(capsules) { capsule in
                VStack(alignment: .leading) {
                    Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                    Text(capsule.state.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("胶囊：\(capsules.count)")
            .toolbar {
                Button("加一枚样本") {
                    let store = CapsuleStore(context: context)
                    try? store.add(VoxlueData.Capsule(title: "样本 \(capsules.count + 1)"))
                }
            }
        }
    }
}

#Preview {
    DebugRootView()
        .modelContainer(for: VoxlueData.Capsule.self, inMemory: true)
}
