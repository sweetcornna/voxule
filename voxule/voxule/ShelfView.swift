import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign

/// 样片墙 —— 全部胶囊按埋下时间倒序排开，存储与浏览中心。
/// 录音入口已搬到首页（HomeView）巨型 mic 键，这里不再放浮动入口，避免重复 chrome。
struct ShelfView: View {
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground().ignoresSafeArea()

                if capsules.isEmpty {
                    emptyState
                } else {
                    photoStack
                }
            }
            .navigationTitle("样片墙")
            .navigationDestination(for: UUID.self) { id in
                if let capsule = capsules.first(where: { $0.id == id }) {
                    CapsuleDetailView(capsule: capsule)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: VoxlueSpacing.lg) {
            // 大字 Crimson 斜体 display —— 给空状态一点旧派的留白与诗意。
            Text("voxlue")
                .font(VoxlueTypography.display)
                .foregroundStyle(VoxlueColor.darkroomGray)
            Text("样片墙还空着")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
            MarginNote("去首页冲一张声音。")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoStack: some View {
        // 用 List 而不是 ScrollView+LazyVStack —— XCUI 通过 cells 语义遍历样片墙，
        // 切到 LazyVStack 会让 cells.count 为 0，破坏既有 UI 测试契约。
        // List 套上 plain 样式 + 透明背景 + 隐藏分隔线 + 透明 row background，
        // 视觉等同于 PhotoCard 网格。
        List {
            ForEach(capsules) { capsule in
                NavigationLink(value: capsule.id) {
                    CapsuleRow(capsule: capsule)
                }
                // 不加 .plain 会在每张 PhotoCard 右侧露一道系统灰 disclosure chevron，
                // 与暗房纸感冲突。.plain 移除 chevron 与默认高亮，行仍可点。
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: VoxlueSpacing.sm,
                    leading: VoxlueSpacing.lg,
                    bottom: VoxlueSpacing.sm,
                    trailing: VoxlueSpacing.lg
                ))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    ShelfView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
