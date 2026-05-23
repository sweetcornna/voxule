#if DEBUG
import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

/// Dev 工具菜单 —— 仅 DEBUG 构建可见，挂在 `SettingsView` 底部。
/// 让前端不用录真音频、不用真后台 / 真账号，也能在样片墙 / 地图 / 我 / 浮现卡四处看到饱满内容。
struct DevToolsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppDependencies.self) private var dependencies

    @State private var lastAction: String?
    @State private var confirmingWipe = false

    var body: some View {
        Form {
            Section {
                Button {
                    DevSampleData.seedAll(into: context)
                    lastAction = "已种入 8 枚胶囊 + 2 个声音圈。"
                } label: {
                    Label("种入示例数据", systemImage: "leaf")
                }

                Button {
                    confirmingWipe = true
                } label: {
                    Label("清空所有胶囊与圈", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("种子数据")
            } footer: {
                Text("示例胶囊覆盖三种锁、四种状态、两种 recipient；音频留空，回放会显示「没能放出这段声音」属正常。")
            }

            Section {
                Button {
                    Task { await surfaceFirstBuried() }
                } label: {
                    Label("手动浮现一枚胶囊", systemImage: "wand.and.stars")
                }
            } header: {
                Text("触发引擎")
            } footer: {
                Text("挑第一枚 .buried 胶囊调用 TriggerEngine.surface()，跳过真 agent / 真后台。胶囊会进入 developing，下次深链进入即可看「浮现卡」。")
            }

            Section {
                Button {
                    CadenceSetting.current = .occasionally
                    lastAction = "cadence 已重置为「偶尔」。"
                } label: {
                    Label("重置 cadence 为「偶尔」", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("其他")
            }

            if let lastAction {
                Section {
                    Text(lastAction)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Dev 工具")
        .alert("清空全部胶囊与圈？", isPresented: $confirmingWipe) {
            Button("清空", role: .destructive) {
                DevSampleData.wipe(context: context)
                lastAction = "已清空全部胶囊与圈。"
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("仅清本设备本地库；CloudKit 已同步过的数据不在此影响。")
        }
    }

    /// 挑第一枚 .buried 胶囊调用 TriggerEngine.surface()。
    /// 失败（没胶囊）就提示。
    private func surfaceFirstBuried() async {
        let descriptor = FetchDescriptor<VoxlueData.Capsule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let capsules = (try? context.fetch(descriptor)) ?? []
        guard let target = capsules.first(where: { $0.state == .buried }) else {
            lastAction = "没找到可浮现的 .buried 胶囊，先「种入示例数据」。"
            return
        }
        await dependencies.engine.surface(capsuleID: target.id)
        // 同时填好路由 routedCapsuleID 让浮现卡直接弹出。
        dependencies.router.routedCapsuleID = target.id
        lastAction = "已浮现「\(target.title.isEmpty ? "（无题）" : target.title)」。"
    }
}
#endif
