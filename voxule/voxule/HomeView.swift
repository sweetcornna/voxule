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
    /// 当日 prompt 偏移 —— 用户在 prompt 上点一下就 +1，循环取下一句。
    /// 只活在当前 session 里，杀进程或跨日都重置回 0，让按日轮换的默认体验保持稳定。
    @State private var promptOffset = 0

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
    /// 叠加 `promptOffset` 让用户点 prompt 时能在当前 session 里换下一句，
    /// 杀进程或跨日重置回当日固定那句。
    private var todaysPrompt: String {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1 + promptOffset) % Self.prompts.count
        return Self.prompts[index]
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

                        // 点一下 prompt 就轮到下一句 —— promptOffset += 1，
                        // contentTransition(.numericText()) 让换字像翻页器一样平滑，
                        // 既不打扰录音主流程，也给「不想要这句」的用户一个出口。
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                promptOffset += 1
                            }
                        } label: {
                            Text(todaysPrompt)
                                .font(VoxlueTypography.caption)
                                .foregroundStyle(VoxlueColor.graphite)
                                .multilineTextAlignment(.center)
                                .contentTransition(.numericText())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("今日提示")
                        .accessibilityHint("点一下换一句")
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
            // 玻璃形状与最终 clipShape 必须对齐：传 Circle()，让 specular 高光沿圆走，
            // 避免默认 rect(22) 玻璃被 clipShape 切成一圈亮鳞（dark 下尤其刺眼）。
            .voxlueGlass(tint: GlassTint.vermillionWash, interactive: true, in: Circle())
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
            .overlay(alignment: .bottom) {
                // 长按 affordance 的额外提示 —— mic 下方一颗朱红小 capsule，
                // 告诉用户「现在松手就会开始录」，把 0.4s 的悬停时间从「没反馈」变成「在等你」。
                // 跟着 isPressing 走，外层 .animation(...) 自动 fade in/out，不打断录音主流程。
                if isPressing {
                    Text("松手开始录音")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.vermillion)
                        .padding(.horizontal, VoxlueSpacing.md)
                        .padding(.vertical, VoxlueSpacing.xs)
                        .background(VoxlueColor.paperHighlight, in: Capsule())
                        .voxlueShadow(.paper)
                        .offset(y: 30)
                        .transition(.opacity)
                }
            }
            .contentShape(Circle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("冲一张")
            .accessibilityHint("点按或长按开始冲洗")
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                // tap 也给一记 light haptic —— 不给的话用户短按会觉得「按了没反应」，
                // 长按反而有 medium 反馈，体验割裂。light 比 medium 弱一档，正好区分两种意图。
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isRecording = true
            }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 24) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                isPressing = false
                isRecording = true
            } onPressingChanged: { pressing in
                // 手指刚贴上 mic 就来一记 selection 脉冲 —— 比 impact 更轻、更「电子」，
                // 给用户「我感知到你了」的物理回授，不会跟后面 0.4s 的 medium 撞车。
                if pressing {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
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
