import SwiftUI
import VoxlueDesign
import VoxlueServices

/// HealthKit 授权与隐私说明界面。
/// 显式授权（架构文档 §10）：先讲清楚，再请求。
struct HealthAuthorizationView: View {
    /// 注入的 HealthKit wrapper —— 生产传真实现，预览传假实现。
    let health: any HealthProviding
    /// 授权完成回调。
    var onFinish: (Bool) -> Void = { _ in }

    @State private var requesting = false

    var body: some View {
        ZStack {
            VoxlueColor.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: VoxlueSpacing.xl) {
                    Text("让陪伴恰到好处")
                        .font(VoxlueTypography.heading)
                        .foregroundStyle(VoxlueColor.ink)

                    Text("voxlue 想读一点你的状态 —— 心情、心率与睡眠 —— 只为在一个合适的安静时刻，把你埋下的某段声音轻轻递到你面前。")
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.graphite)

                    PaperCard {
                        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
                            privacyRow(icon: "iphone",
                                       text: "原始数据全程留在你的设备上，永不上传。")
                            privacyRow(icon: "wand.and.sparkles",
                                       text: "上网的只是一份抽象摘要，无法回指到你的任何具体读数。")
                            privacyRow(icon: "hand.raised",
                                       text: "这是陪伴，不做任何健康判断。你随时可以在系统设置里收回授权。")
                        }
                    }

                    Button {
                        Task {
                            requesting = true
                            let granted = await health.requestAuthorization()
                            requesting = false
                            onFinish(granted)
                        }
                    } label: {
                        Text(requesting ? "请求中…" : "继续")
                            .font(VoxlueTypography.serifBody)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, VoxlueSpacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VoxlueColor.vermillion)
                    .disabled(requesting)

                    Button("以后再说") { onFinish(false) }
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.graphite)
                        .frame(maxWidth: .infinity)
                }
                .padding(VoxlueSpacing.lg)
            }
        }
        .navigationTitle("陪伴授权")
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: VoxlueSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(VoxlueColor.vermillion)
                .frame(width: 24)
            Text(text)
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.ink)
        }
    }
}

#Preview {
    NavigationStack {
        HealthAuthorizationView(health: FakeHealthProviding(snapshot: nil))
    }
}
