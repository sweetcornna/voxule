import SwiftUI
import SwiftData
import VoxlueData

/// App 根骨架 —— 三标签：样片墙 / 地图 / 我。
/// 「我」在本计划仅占位，由计划 05 充实。
/// 深链 / 通知 / 灵动岛点击经 `CapsuleRouter` 落到一张详情 sheet。
struct RootTabView: View {
    /// 触发引擎依赖容器；预览未注入时为 nil（不影响渲染）。
    @Environment(AppDependencies.self) private var dependencies: AppDependencies?

    var body: some View {
        TabView {
            Tab("样片墙", systemImage: "rectangle.stack") {
                ShelfView()
            }
            Tab("地图", systemImage: "map") {
                NavigationStack { CapsuleMapView() }
            }
            Tab("我", systemImage: "person.crop.circle") {
                CircleListView()
            }
        }
        .sheet(isPresented: routedSheetBinding) {
            if let id = dependencies?.router.routedCapsuleID {
                NavigationStack { RoutedCapsuleDetailView(capsuleID: id) }
            }
        }
    }

    /// 把 `router.routedCapsuleID` 是否非空映射成 sheet 的 isPresented。
    private var routedSheetBinding: Binding<Bool> {
        Binding(
            get: { dependencies?.router.routedCapsuleID != nil },
            set: { presented in
                if !presented { dependencies?.router.routedCapsuleID = nil }
            }
        )
    }
}

/// 深链落地页 —— 按 capsuleID 现查胶囊，命中则展示详情。
struct RoutedCapsuleDetailView: View {
    let capsuleID: UUID
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    var body: some View {
        if let capsule = capsules.first(where: { $0.id == capsuleID }) {
            CapsuleDetailView(capsule: capsule)
        } else {
            ContentUnavailableView(
                "找不到这枚胶囊",
                systemImage: "questionmark.circle",
                description: Text("它可能已被划掉。")
            )
        }
    }
}

#Preview {
    RootTabView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
