import SwiftUI
import VoxlueServices

/// 「我」标签下的设置入口 —— 把陪伴 agent 的两个开关聚到一处：
/// 浮现频率（cadence）与陪伴授权（HealthKit）。
struct SettingsView: View {
    @Environment(HealthEnv.self) private var healthEnv

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    CadenceSettingsView()
                } label: {
                    Label("浮现频率", systemImage: "wand.and.stars")
                }
                NavigationLink {
                    HealthAuthorizationView(health: healthEnv.provider)
                } label: {
                    Label("陪伴授权", systemImage: "heart.text.square")
                }
            } header: {
                Text("陪伴")
            } footer: {
                Text("两项都是陪伴层面的设置 —— 与你的胶囊安全无关，随时可调。")
            }

            #if DEBUG
            Section {
                NavigationLink {
                    DevToolsView()
                } label: {
                    Label("Dev 工具", systemImage: "hammer")
                }
            } header: {
                Text("Dev")
            } footer: {
                Text("仅 DEBUG 构建可见 —— 种子数据、手动浮现、清空。Release 构建自动隐藏。")
            }
            #endif
        }
        .navigationTitle("设置")
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(HealthEnv(provider: FakeHealthProviding(snapshot: nil)))
}
