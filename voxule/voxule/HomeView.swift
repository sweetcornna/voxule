import SwiftUI
import VoxlueDesign

/// 首页 —— App 唯一主页面，居中一颗巨大的玻璃 mic 录音键，
/// 让「冲一张声音」是用户随手能触发的第一动作。
/// 视觉与冲洗台暗房风格呼应，但保留纸基底（玻璃在 chrome，纸在 content）。
struct HomeView: View {
    @State private var isRecording = false

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

                    // 巨大玻璃 mic —— 屏幕中心唯一焦点。
                    Button {
                        isRecording = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 72, weight: .semibold))
                            .foregroundStyle(VoxlueColor.vermillion)
                            .frame(width: 200, height: 200)
                    }
                    .voxlueGlass(tint: GlassTint.vermillionWash, interactive: true)
                    .clipShape(Circle())
                    .accessibilityLabel("冲一张")

                    Spacer().frame(height: VoxlueSpacing.sm)

                    // Caveat 手写引导 —— 像冲洗师在工作台留了一句。
                    MarginNote("点我，把这段声音冲下来。")

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
}

#Preview {
    HomeView()
        .environment(\.appEnvironment, .preview())
}
