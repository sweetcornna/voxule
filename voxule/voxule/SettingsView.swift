import SwiftUI
import VoxlueDesign
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
                    settingsRow(icon: "wand.and.stars", text: "浮现频率")
                }
                NavigationLink {
                    HealthAuthorizationView(health: healthEnv.provider)
                } label: {
                    settingsRow(icon: "heart.text.square", text: "陪伴授权")
                }
            } header: {
                sectionHeader("陪伴")
            } footer: {
                Text("两项都是陪伴层面的设置 —— 与你的胶囊安全无关，随时可调。")
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.darkroomGray)
            }

            #if DEBUG
            Section {
                NavigationLink {
                    DevToolsView()
                } label: {
                    settingsRow(icon: "hammer", text: "Dev 工具")
                }
            } header: {
                sectionHeader("Dev")
            } footer: {
                Text("仅 DEBUG 构建可见 —— 种子数据、手动浮现、清空。Release 构建自动隐藏。")
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.darkroomGray)
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(VoxlueColor.paper.ignoresSafeArea())
        .navigationTitle("设置")
    }

    /// 行内 icon + 思源宋正文。设置子页统一形态。
    private func settingsRow(icon: String, text: String) -> some View {
        HStack(spacing: VoxlueSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(VoxlueColor.vermillion)
                .frame(width: 24)
            Text(text)
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.ink)
        }
    }

    /// 思源宋小标题 —— 关掉系统默认大写。
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(VoxlueTypography.caption)
            .foregroundStyle(VoxlueColor.graphite)
            .textCase(nil)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(HealthEnv(provider: FakeHealthProviding(snapshot: nil)))
}
