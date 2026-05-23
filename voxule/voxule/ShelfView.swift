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

        // @Query 已按 createdAt desc 排好；这里只需顺扫一遍，
        // 在 bucket 变化的边界标 firstInBucket = true。
        var rows: [ShelfRow] = []
        rows.reserveCapacity(capsules.count)
        var previousBucket: Bucket?
        for capsule in capsules {
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
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// 区段引线 —— 朱红短画 + 石墨小字，像档案柜抽屉上贴的标签。
    /// 与 MarginNote 同款引线，但不用手写体 —— 这里是分隔，不是批注。
    /// 没有 .listRowInsets / .listRowBackground：这里不是独立 List row，
    /// 而是被嵌进该段首行 NavigationLink 内容顶部的一个 HStack。
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
        .padding(.top, VoxlueSpacing.sm)
        .padding(.bottom, VoxlueSpacing.xs)
    }
}

#Preview {
    ShelfView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
