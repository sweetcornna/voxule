import SwiftUI
import BackgroundTasks

/// 情绪胶囊浮现频率（架构文档 §6）。用户可调，「关」则 agent 不再主动浮现。
enum CadenceSetting: String, CaseIterable, Identifiable {
    case gentle = "gentle"              // 轻轻地
    case occasionally = "occasionally"  // 偶尔
    case off = "off"                    // 关

    var id: String { rawValue }

    /// 显示名 —— 陪伴语气。
    var label: String {
        switch self {
        case .gentle: "轻轻地"
        case .occasionally: "偶尔"
        case .off: "关"
        }
    }

    /// 一句说明。
    var caption: String {
        switch self {
        case .gentle: "更常浮现，像偶尔路过的旧友"
        case .occasionally: "久一点才浮现一次"
        case .off: "不再主动浮现；你随时能在 App 里手动打开"
        }
    }

    /// 后台唤醒的最短间隔（秒）。
    var interval: TimeInterval {
        switch self {
        case .gentle: 60 * 60 * 24           // 约一天
        case .occasionally: 60 * 60 * 24 * 4 // 约四天
        case .off: .infinity
        }
    }

    private static let storageKey = "voxlue.cadence"

    /// 当前设置 —— 持久化在 UserDefaults，后台排程与设置界面共用。
    static var current: CadenceSetting {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey)
            return raw.flatMap(CadenceSetting.init(rawValue:)) ?? .occasionally
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}

/// cadence 设置界面。
struct CadenceSettingsView: View {
    @State private var selection = CadenceSetting.current

    var body: some View {
        Form {
            Section {
                ForEach(CadenceSetting.allCases) { cadence in
                    Button {
                        selection = cadence
                        CadenceSetting.current = cadence
                        // 改频率即刻生效：「关」取消待发唤醒，否则按新间隔重排。
                        if cadence == .off {
                            BGTaskScheduler.shared.cancel(
                                taskRequestWithIdentifier: voxuleApp.surfacingTaskID)
                        } else {
                            Task { await voxuleApp.scheduleNextSurfacing() }
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cadence.label)
                                    .foregroundStyle(.primary)
                                Text(cadence.caption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if cadence == selection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("浮现频率")
            } footer: {
                Text("情绪胶囊由陪伴 agent 在安静时刻为你浮现。这是陪伴，不是提醒事项 —— 你随时可以调慢，或关掉。")
            }
        }
        .navigationTitle("浮现")
    }
}

#Preview {
    NavigationStack { CadenceSettingsView() }
}
