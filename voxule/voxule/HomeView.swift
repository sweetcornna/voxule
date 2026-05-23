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

    /// 取最近埋下的一枚胶囊 —— SwiftData fetchLimit 在 iOS 17+ 可用，
    /// 这里只要 limit=1 让 MarginNote 下方挂一张小预览，不污染样片墙。
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var recentCapsules: [VoxlueData.Capsule]

    private var latestCapsule: VoxlueData.Capsule? { recentCapsules.first }

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
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $isRecording) {
                RecordView()
            }
        }
    }

    /// 巨型玻璃 mic —— 屏幕中心唯一焦点。
    /// 短按：弹 RecordView 走「点按开始冲洗」流程。
    /// 长按 0.4s：触发 medium haptic 后同样弹 RecordView，按住期间按钮放大 + 朱红光圈作视觉反馈。
    private var micButton: some View {
        Button {
            // 短按入口 —— 沿用原 tap 行为。
            isRecording = true
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(VoxlueColor.vermillion)
                .frame(width: 200, height: 200)
        }
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
        .accessibilityLabel("冲一张")
        .accessibilityHint("点按或长按开始冲洗")
        .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 24) {
            // 达到 0.4s —— 触觉反馈一下，再走录音流程。
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
            MarginNote("最近埋下的一段")

            NavigationLink {
                CapsuleDetailView(capsule: capsule)
            } label: {
                CapsuleRow(capsule: capsule)
                    .scaleEffect(0.75, anchor: .top)
                    .frame(maxWidth: 280)
                    // scaleEffect 不会真正缩布局尺寸，缩完底部会留一大块空白；
                    // 给容器一个合理高度让排版重新呼吸，288 ≈ 卡片原高 0.75。
                    .frame(height: 220, alignment: .top)
                    .clipped()
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    HomeView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
