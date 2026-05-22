import SwiftUI
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("让陪伴恰到好处")
                    .font(.title2.weight(.semibold))

                Text("voxlue 想读一点你的状态 —— 心情、心率与睡眠 —— 只为在一个合适的安静时刻，把你埋下的某段声音轻轻递到你面前。")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    privacyRow(icon: "iphone",
                               text: "原始数据全程留在你的设备上，永不上传。")
                    privacyRow(icon: "wand.and.sparkles",
                               text: "上网的只是一份抽象摘要，无法回指到你的任何具体读数。")
                    privacyRow(icon: "hand.raised",
                               text: "这是陪伴，不做任何健康判断。你随时可以在系统设置里收回授权。")
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task {
                        requesting = true
                        let granted = await health.requestAuthorization()
                        requesting = false
                        onFinish(granted)
                    }
                } label: {
                    Text(requesting ? "请求中…" : "继续")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(requesting)

                Button("以后再说") { onFinish(false) }
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("陪伴授权")
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(.callout)
        }
    }
}

#Preview {
    NavigationStack {
        HealthAuthorizationView(health: FakeHealthProviding(snapshot: nil))
    }
}
