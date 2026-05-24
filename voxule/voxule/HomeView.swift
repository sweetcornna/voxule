import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign

/// 首页 —— App 唯一主页面，居中一颗巨大的玻璃 mic 录音键，
/// 让「冲一张声音」是用户随手能触发的第一动作。
/// 视觉与冲洗台暗房风格呼应，但保留纸基底（玻璃在 chrome，纸在 content）。
struct HomeView: View {
    @State private var isRecording = false
    /// 长按视觉反馈 —— 按住 mic 时整颗按钮放大并外圈泛朱红，
    /// 给用户「我已经按住了」的物理回授，0.4s 后才真正触发录音。
    @State private var isPressing = false

    /// 取最近一枚胶囊 —— FetchDescriptor 显式设 fetchLimit=1，
    /// 避免预览渲染时把整张 Capsule 表 materialize 进内存。
    @Query(Self.recentDescriptor)
    private var recentCapsules: [VoxlueData.Capsule]

    private var latestCapsule: VoxlueData.Capsule? { recentCapsules.first }

    /// 全量胶囊 —— 内存里过滤出 .developing 的那批。
    /// 没用 `#Predicate { $0.state == .developing }` 是因为 SwiftData 对枚举字段的
    /// predicate 在 iOS 26 仍偶现编译期奇怪报错；这里数据量本就不大，内存 filter 更稳。
    /// 按 createdAt 倒序排好，pill 点进去的「第一段」就是最新一段在显影的。
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var allCapsules: [VoxlueData.Capsule]

    private var developingCapsules: [VoxlueData.Capsule] {
        allCapsules.filter { $0.state == .developing }
    }

    // 顶部统计 —— 三个数字像档案盒的封签条，给用户一个「我攒了多少」的归档感。
    // 「待听」把 .developing 和 .developed 合并：用户感知里都是「等我」的同一档。
    private var buriedCount: Int { allCapsules.filter { $0.state == .buried }.count }
    private var developingOrDevelopedCount: Int {
        allCapsules.filter { $0.state == .developing || $0.state == .developed }.count
    }
    private var openedCount: Int { allCapsules.filter { $0.state == .opened }.count }
    private var hasAnyCapsule: Bool { !allCapsules.isEmpty }

    private static var recentDescriptor: FetchDescriptor<VoxlueData.Capsule> {
        var descriptor = FetchDescriptor<VoxlueData.Capsule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// 每日 prompt 池 —— 顺着 voxlue 暗房气质写：第二人称、感官、轻、不下命令。
    /// 故意全是「问句 / 邀请 / 留白」，避免 CTA 式的「立刻录！」。
    /// 顺序无所谓，只要保持稳定（同一索引同一句话），按日轮换就行。
    private static let prompts: [String] = [
        "今天有什么声音想留下？",
        "外婆的口头禅，录一句？",
        "雨打窗户的声音，存一段。",
        "厨房里有人在做饭吗？",
        "今天的笑声，值得留下来。",
        "想了又想没说出口的那句话。",
        "陌生地方的环境声。",
        "回家路上听到的歌。",
        "枕边人均匀的呼吸。",
        "窗外那只总在叫的鸟。",
        "一句给十年后自己的话。",
        "此刻屋里最安静的声音。"
    ]

    /// 今日 prompt —— 用 day-of-year 取模，让同一天反复打开 app 看到的话不变；
    /// 跨日 0 点自动换一句。`ordinality(of:.day, in:.year)` 在闰年里走到 366，
    /// 模运算照常工作，不需要特判。
    /// nil 兜底是日历返回失败时的极端情况（理论上不会发生在 Gregorian + .current），
    /// 保底用第 0 句而不是 crash。
    private static var todaysPrompt: String {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return prompts[(dayOfYear - 1) % prompts.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground().ignoresSafeArea()

                VStack(spacing: VoxlueSpacing.lg) {
                    Spacer()

                    // 浮现待听 pill —— 有显影中胶囊就把它顶到 heading 上方，
                    // 点一下进最新一段的 CapsuleDetailView（state == .developing
                    // 时 detail 会自动落到 SurfacedCapsuleView 那张「等你听」的牌）。
                    if !developingCapsules.isEmpty {
                        surfacingPill
                    }

                    // 思源宋 heading + 每日 prompt —— heading 拽用户进来，prompt 给一个
                    // 具体的「今天可以录什么」的轻提示。两行用 xs 间距黏成一组，外层 VStack
                    // 的 lg 间距继续把这一组与下面的 mic 拉开。
                    VStack(spacing: VoxlueSpacing.xs) {
                        Text("今天，冲一张")
                            .font(VoxlueTypography.heading)
                            .foregroundStyle(VoxlueColor.ink)

                        Text(Self.todaysPrompt)
                            .font(VoxlueTypography.caption)
                            .foregroundStyle(VoxlueColor.graphite)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("今天的提示：\(Self.todaysPrompt)")
                    }

                    Spacer().frame(height: VoxlueSpacing.lg)

                    micButton

                    Spacer().frame(height: VoxlueSpacing.sm)

                    // Caveat 手写引导 —— mic 下方的独立指示语，不需要 MarginNote 的朱红
                    // 引线（引线是「批注某物」的语义）。这里只是一句话，居中纯文字更和谐。
                    Text("点我，把这段声音冲下来。")
                        .font(VoxlueTypography.annotation)
                        .foregroundStyle(VoxlueColor.vermillion)
                        .multilineTextAlignment(.center)

                    if let capsule = latestCapsule {
                        recentPreview(for: capsule)
                            .padding(.top, VoxlueSpacing.lg)
                    }

                    statsLine
                        .padding(.top, VoxlueSpacing.md)

                    Spacer()
                    // 有最近一枚预览时少压一个 Spacer，让 mic 仍居中视觉而不被压扁。
                    if latestCapsule == nil {
                        Spacer()
                    }
                }
            }
            // .navigationBarHidden 已弃用，且会沿着 NavigationStack 把 push 出去的子视图的
            // 导航条也藏了 —— back 按钮就跟着不见。换成 .toolbar(.hidden:for:) 作用域里只
            // 收 HomeView 自己这层。
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $isRecording) {
                RecordView()
            }
        }
    }

    /// 巨型玻璃 mic —— 屏幕中心唯一焦点。
    /// 短按：弹 RecordView 走「点按开始冲洗」流程。
    /// 长按 0.4s：触发 medium haptic 后同样弹 RecordView，按住期间按钮放大 + 朱红光圈反馈。
    ///
    /// 不用 Button —— Button + onLongPressGesture 在 SwiftUI 里不互斥：长按结束松手时
    /// Button 的 tap 也会触发，等于「长按 + tap」双路径都 set isRecording。
    /// 用 ZStack + 单独 onTapGesture + onLongPressGesture，SwiftUI 的 gesture 系统
    /// 会自动按持续时长择一触发。
    private var micButton: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 72, weight: .semibold))
            .foregroundStyle(VoxlueColor.vermillion)
            .frame(width: 200, height: 200)
            .voxlueGlass(tint: GlassTint.vermillionWash, interactive: true)
            .clipShape(Circle())
            .overlay(
                // 朱红光圈 —— 按住时从 mic 边缘往外推一圈淡朱，松手即收。
                Circle()
                    .stroke(VoxlueColor.vermillion.opacity(isPressing ? 0.45 : 0), lineWidth: 6)
                    .scaleEffect(isPressing ? 1.18 : 1.0)
                    .blur(radius: 1)
                    .allowsHitTesting(false)
            )
            .scaleEffect(isPressing ? 1.06 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isPressing)
            .contentShape(Circle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("冲一张")
            .accessibilityHint("点按或长按开始冲洗")
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                isRecording = true
            }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 24) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                isPressing = false
                isRecording = true
            } onPressingChanged: { pressing in
                isPressing = pressing
            }
    }

    /// 浮现待听 pill —— 顶在 heading 上方的一小颗 chrome。
    /// 朱红呼吸点 + 「有 N 段等你听 →」，点击 push 进最新一段 developing 胶囊的
    /// CapsuleDetailView。SurfacedCapsuleView 会接管渲染（state == .developing）。
    /// 没有 developing 胶囊时，外部 `if` 直接不渲染 —— 默认布局完全不变。
    @ViewBuilder
    private var surfacingPill: some View {
        // 兜底空数组保护：外部 if 已确保非空，这里取 first! 也是安全的，
        // 但用 if let 让 SwiftUI diff 时类型一致、preview 也更稳。
        if let first = developingCapsules.first {
            NavigationLink {
                CapsuleDetailView(capsule: first)
            } label: {
                HStack(spacing: VoxlueSpacing.sm) {
                    Circle()
                        .fill(VoxlueColor.vermillion)
                        .frame(width: 6, height: 6)
                        // 朱红点呼吸 —— 0.4 ↔ 1.0 让 pill 在视觉里活着，
                        // 又不至于像 badge 那样咣咣闪。
                        .phaseAnimator([false, true]) { content, phase in
                            content.opacity(phase ? 1.0 : 0.4)
                        } animation: { _ in
                            .easeInOut(duration: 0.9)
                        }

                    Text("有 \(developingCapsules.count) 段等你听 →")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.vermillion)
                }
                .padding(.horizontal, VoxlueSpacing.md)
                .padding(.vertical, VoxlueSpacing.sm)
                .background(VoxlueColor.paperHighlight, in: Capsule())
                .voxlueShadow(.paper)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("有 \(developingCapsules.count) 段在显影，等你听")
            .accessibilityHint("点开听最新一段")
            .accessibilityAddTraits(.isButton)
        }
    }

    /// 最近一枚胶囊的小预览 —— 缩小 75% 的 CapsuleRow，
    /// 按状态自动走 PhotoCard / NegativeCard，点击进 CapsuleDetailView。
    @ViewBuilder
    private func recentPreview(for capsule: VoxlueData.Capsule) -> some View {
        // 「最近的一段」与缩放后的 NegativeCard 共享同一左边轴：
        // CapsuleRow scaleEffect(0.75) 后内 padding 从 16 缩到 12pt，
        // 标签左 padding 也设 12pt，标签字体起点与卡片标题起点垂直对齐。
        // 不再用 MarginNote —— 左侧朱红短画与下方卡片的左缘形成双线，反而扰乱。
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            // 显示的可能是 .buried / .developing / .developed / .opened 任一状态，
            // 不一定刚埋下，所以不说「埋下的」。
            Text("最近的一段")
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
                .padding(.leading, 12)

            NavigationLink {
                CapsuleDetailView(capsule: capsule)
            } label: {
                CapsuleRow(capsule: capsule)
                    .scaleEffect(0.75, anchor: .topLeading)
                    // scaleEffect 不真正缩布局尺寸，要手动收缩容器高度。
                    // 卡片原高 ≈ 216 × 0.75 ≈ 162，给一点呼吸到 168。
                    .frame(height: 168, alignment: .top)
                    .clipped()
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("最近一枚：\(capsule.title.isEmpty ? "（无题）" : capsule.title)")
        }
        // 整个 VStack 限到 280pt 再居中放进父 VStack —— 标签 + 卡片同一左轴。
        .frame(maxWidth: 280)
    }

    /// 档案统计条 —— Space Mono 跑出像胶卷边沿打孔的标签感，
    /// 数字之间用「·」当分隔点；全空（hasAnyCapsule == false）就整条不出，
    /// 避免新用户看见 0 · 0 · 0 的尴尬冷场。
    @ViewBuilder
    private var statsLine: some View {
        if hasAnyCapsule {
            HStack(spacing: VoxlueSpacing.sm) {
                statChip(label: "埋下", count: buriedCount)
                dot
                statChip(label: "待听", count: developingOrDevelopedCount)
                dot
                statChip(label: "已听", count: openedCount)
            }
            .font(VoxlueTypography.meta)
            .foregroundStyle(VoxlueColor.graphite)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("埋下 \(buriedCount)，待听 \(developingOrDevelopedCount)，已听 \(openedCount)")
        }
    }

    private func statChip(label: String, count: Int) -> some View {
        Text("\(label) \(count)")
    }

    private var dot: some View {
        Text("·")
            .font(VoxlueTypography.meta)
            .foregroundStyle(VoxlueColor.darkroomGray)
    }
}

#Preview {
    HomeView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
