import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign

/// 样片墙 —— 全部胶囊按埋下时间倒序排开，是 App 的主页。
/// 改成纸基底 + PhotoCard 网格 + 玻璃浮动「冲一张」入口。
struct ShelfView: View {
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    @State private var isRecording = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VoxlueColor.paper.ignoresSafeArea()

                Group {
                    if capsules.isEmpty {
                        emptyState
                    } else {
                        photoStack
                    }
                }

                // 玻璃浮动主按钮 —— 「冲一张」录音入口，悬浮在样片墙右下。
                GlassFloatingButton(systemImage: "mic.fill") {
                    isRecording = true
                }
                .padding(.trailing, VoxlueSpacing.lg)
                .padding(.bottom, VoxlueSpacing.lg)
                .accessibilityLabel("冲一张")
            }
            .navigationTitle("样片墙")
            .navigationDestination(for: UUID.self) { id in
                if let capsule = capsules.first(where: { $0.id == id }) {
                    CapsuleDetailView(capsule: capsule)
                }
            }
            .fullScreenCover(isPresented: $isRecording) {
                RecordView()
            }
        }
    }

    private var emptyState: some View {
        // 必须撑满父 ZStack 才不会被 .bottomTrailing 对齐拽到角落里去。
        VStack(spacing: VoxlueSpacing.md) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 44))
                .foregroundStyle(VoxlueColor.darkroomGray)
            Text("样片墙还空着")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
            Text("冲一张声音，埋下它。")
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.graphite)
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
        .contentMargins(.bottom, VoxlueSpacing.xxl + 60, for: .scrollContent)
    }
}

#Preview {
    ShelfView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
