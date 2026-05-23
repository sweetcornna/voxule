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

    private static var recentDescriptor: FetchDescriptor<VoxlueData.Capsule> {
        var descriptor = FetchDescriptor<VoxlueData.Capsule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground().ignoresSafeArea()

                VStack(spacing: VoxlueSpacing.lg) {
                    Spacer()

                    // 思源宋 heading —— 一句把用户拽进来的诱导语。
                    Text("今天，冲一张")
                        .font(VoxlueTypography.heading)
                        .foregroundStyle(VoxlueColor.ink)

                    Spacer().frame(height: VoxlueSpacing.lg)

                    micButton

                    Spacer().frame(height: VoxlueSpacing.sm)

                    // Caveat 手写引导 —— 像冲洗师在工作台留了一句。
                    MarginNote("点我，把这段声音冲下来。")

                    if let capsule = latestCapsule {
                        recentPreview(for: capsule)
                            .padding(.top, VoxlueSpacing.lg)
                    }

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

    /// 最近一枚胶囊的小预览 —— 缩小 75% 的 CapsuleRow，
    /// 按状态自动走 PhotoCard / NegativeCard，点击进 CapsuleDetailView。
    @ViewBuilder
    private func recentPreview(for capsule: VoxlueData.Capsule) -> some View {
        VStack(spacing: VoxlueSpacing.sm) {
            // 显示的可能是 .buried / .developing / .developed / .opened 任一状态，
            // 不一定刚埋下，所以不说「埋下的」。
            MarginNote("最近的一段")

            NavigationLink {
                CapsuleDetailView(capsule: capsule)
            } label: {
                CapsuleRow(capsule: capsule)
                    .scaleEffect(0.75, anchor: .top)
                    .frame(maxWidth: 280)
                    // scaleEffect 不真正缩布局尺寸，要手动收缩容器高度。
                    // 卡片原高 ≈ 216（image 150 + 标题 ~22 + 间距 + meta ~16 + 内 padding ~24 + 阴影），
                    // × 0.75 ≈ 162，给一点呼吸到 168。
                    .frame(height: 168, alignment: .top)
                    .clipped()
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("最近一枚：\(capsule.title.isEmpty ? "（无题）" : capsule.title)")
        }
    }
}

#Preview {
    HomeView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
