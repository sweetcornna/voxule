import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign

/// 样片墙 —— 全部胶囊按埋下时间倒序排开，存储与浏览中心。
/// 录音入口已搬到首页（HomeView）巨型 mic 键，这里不再放浮动入口，避免重复 chrome。
/// 第五轮：墙面按时间分段 —— 本周 / 上个月 / 更早，像档案箱的隔板。
struct ShelfView: View {
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    /// SwiftData 上下文 —— contextMenu 的"划掉"走 context.delete + save。
    /// 这里不引 CapsuleStore，避免给样片墙再背一份依赖；
    /// 行级删除是纯本地操作，直接走 modelContext 已够。
    @Environment(\.modelContext) private var context

    /// 搜索词 —— 空串等价于不过滤，保留与 @Query 完全相同的渲染序，
    /// 保证 UI 测试 testRecordBuryPlayMainLoop 在默认空查询下不动行为契约。
    @State private var query = ""

    /// 二次确认的目标胶囊 —— 非 nil 即弹 alert，alert 关闭时复位为 nil。
    /// 用 Capsule? 而不是 Bool + 旁置 selected：
    /// .alert(_:isPresented:presenting:) 需要个非空值给 actions/message 闭包，
    /// 拿它当 identity 一并解决"弹谁"的歧义。
    @State private var confirmingDelete: VoxlueData.Capsule?

    /// 时间分段 —— 顺序即渲染顺序，新鲜的在上。
    private enum Bucket: CaseIterable {
        case thisWeek   // 0–7 天
        case lastMonth  // 8–30 天
        case earlier    // 30+ 天

        var label: String {
            switch self {
            case .thisWeek:  "本周"
            case .lastMonth: "上个月"
            case .earlier:   "更早"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground().ignoresSafeArea()

                if capsules.isEmpty {
                    // 数据库本身为空 —— 首次到访，引去首页冲一张。
                    emptyState
                } else if filteredCapsules.isEmpty && !query.isEmpty {
                    // 数据库有片，但搜不到 —— 区别于空数据库的诗意空状态，
                    // 用一行 MarginNote 提示，避免覆盖整个区域的大字 display。
                    noMatchState
                } else {
                    photoStack
                }
            }
            .navigationTitle("样片墙")
            .searchable(text: $query, prompt: Text("找一段声音"))
            .navigationDestination(for: UUID.self) { id in
                if let capsule = capsules.first(where: { $0.id == id }) {
                    CapsuleDetailView(capsule: capsule)
                }
            }
            // 行级 contextMenu 的二次确认 —— 用 presenting: 把目标胶囊带进闭包。
            // isPresented 的 Binding 用 confirmingDelete != nil 推导：
            // alert 系统在 dismiss 时会回写 false，借此把 state 复位为 nil。
            .alert(
                "划掉这枚胶囊？",
                isPresented: Binding(
                    get: { confirmingDelete != nil },
                    set: { if !$0 { confirmingDelete = nil } }
                ),
                presenting: confirmingDelete
            ) { capsule in
                Button("划掉", role: .destructive) {
                    context.delete(capsule)
                    try? context.save()
                }
                Button("不了", role: .cancel) {}
            } message: { _ in
                Text("声音会从样片墙、地图和声音圈里消失。")
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
            // 居中 VStack 里不用 MarginNote 的左侧朱红短画 —— 会把视觉重心拽偏。
            Text("去首页冲一张声音。")
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 搜不到匹配 —— 小份量提示，留给搜索栏继续输入的余地。
    /// 不复用 emptyState 的大字 display，那是给"墙真的空"的场合的。
    private var noMatchState: some View {
        VStack(spacing: VoxlueSpacing.sm) {
            Text("找不到匹配的声音")
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.ink)
            Text("换个词试试。")
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 应用搜索词过滤 —— 空串直通，匹配 title 或 placeName（若存在）。
    /// 在 shelfRows 之前过滤，bucket 划分才会跟着结果一起收敛。
    private var filteredCapsules: [VoxlueData.Capsule] {
        guard !query.isEmpty else { return capsules }
        return capsules.filter { capsule in
            if capsule.title.localizedCaseInsensitiveContains(query) {
                return true
            }
            if let place = capsule.placeName,
               place.localizedCaseInsensitiveContains(query) {
                return true
            }
            return false
        }
    }

    /// 把每个 capsule 标上所属 bucket，并打 firstInBucket 旗标。
    /// 摊平成一维数组 —— 这样 List 里只有一个 ForEach，cells.count == capsules.count，
    /// 不破 UI 测试契约。bucket header 直接挂在每段第一行的内容顶部，看上去仍是分段。
    private struct ShelfRow: Identifiable {
        let capsule: VoxlueData.Capsule
        let bucket: Bucket
        let firstInBucket: Bool
        var id: UUID { capsule.id }
    }

    private var shelfRows: [ShelfRow] {
        let now = Date()
        let calendar = Calendar.current

        func bucket(for date: Date) -> Bucket {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days <= 7  { return .thisWeek }
            if days <= 30 { return .lastMonth }
            return .earlier
        }

        // @Query 已按 createdAt desc 排好；filter 保留顺序，
        // 这里只需顺扫一遍，在 bucket 变化的边界标 firstInBucket = true。
        let source = filteredCapsules
        var rows: [ShelfRow] = []
        rows.reserveCapacity(source.count)
        var previousBucket: Bucket?
        for capsule in source {
            let b = bucket(for: capsule.createdAt)
            rows.append(ShelfRow(
                capsule: capsule,
                bucket: b,
                firstInBucket: b != previousBucket
            ))
            previousBucket = b
        }
        return rows
    }

    private var photoStack: some View {
        // 用 List 而不是 ScrollView+LazyVStack —— XCUI 通过 cells 语义遍历样片墙，
        // 切到 LazyVStack 会让 cells.count 为 0，破坏既有 UI 测试契约。
        // List 套上 plain 样式 + 透明背景 + 隐藏分隔线 + 透明 row background，
        // 视觉等同于 PhotoCard 网格。
        //
        // 为什么不用 Section / header：plain List 的 section header 会在 XCUITest 里
        // 算作一个独立 cell，破坏 cells.count == capsules.count 契约。
        // 折中方案：把 bucket 标签挂在该段第一行的内容顶部，行还是一行，cell 还是一个。
        List {
            ForEach(shelfRows) { row in
                NavigationLink(value: row.capsule.id) {
                    VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                        if row.firstInBucket {
                            sectionHeader(row.bucket.label)
                        }
                        CapsuleRow(capsule: row.capsule)
                    }
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
                // 长按行 —— 不进详情就能分享 / 划掉。
                // 分享只在确有音频数据时露出，避免给 buried/空音频行甩个空按钮；
                // 划掉走 confirmingDelete = capsule，弹层在 NavigationStack 层级统一处理。
                .contextMenu {
                    if let data = row.capsule.audioData, !data.isEmpty {
                        ShareLink(
                            item: data,
                            preview: SharePreview(
                                row.capsule.title.isEmpty ? "（无题）" : row.capsule.title
                            )
                        )
                    }
                    Button(role: .destructive) {
                        confirmingDelete = row.capsule
                    } label: {
                        Label("划掉", systemImage: "trash")
                    }
                }
                // 右滑快捷入口 —— 长按只是发现路径之一，多数 iOS 用户先试右滑。
                // 与 contextMenu 并存：两条路通向同一组动作，谁先发现都行。
                // allowsFullSwipe: false —— 划掉是破坏性操作，不让一滑到底无确认就走。
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        confirmingDelete = row.capsule
                    } label: {
                        Label("划掉", systemImage: "trash")
                    }
                    .tint(VoxlueColor.vermillion)

                    if let data = row.capsule.audioData, !data.isEmpty {
                        ShareLink(
                            item: data,
                            preview: SharePreview(
                                row.capsule.title.isEmpty ? "（无题）" : row.capsule.title
                            )
                        ) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        .tint(VoxlueColor.graphite)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// 区段引线 —— 朱红短画 + 石墨小字，像档案柜抽屉上贴的标签。
    /// 与 MarginNote 同款引线，但不用手写体 —— 这里是分隔，不是批注。
    /// 没有 .listRowInsets / .listRowBackground：这里不是独立 List row，
    /// 而是被嵌进该段首行 NavigationLink 内容顶部的一个 HStack。
    /// 左 padding 与 PhotoCard / NegativeCard 内部标题对齐（外 lg + 卡内 lg = 2lg），
    /// 否则短画悬在卡片标题左侧 12pt 空中，视觉上歪一寸。
    private func sectionHeader(_ label: String) -> some View {
        HStack(spacing: VoxlueSpacing.sm) {
            Rectangle()
                .fill(VoxlueColor.vermillion)
                .frame(width: 14, height: 1.5)
            Text(label)
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        }
        .textCase(nil)
        .padding(.leading, VoxlueSpacing.lg)
        .padding(.top, VoxlueSpacing.sm)
        .padding(.bottom, VoxlueSpacing.xs)
    }
}

#Preview {
    ShelfView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
