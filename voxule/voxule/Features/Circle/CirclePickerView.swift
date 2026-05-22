import SwiftUI
import VoxlueData
import VoxlueServices

/// 装裱胶囊时选「埋给哪个声音圈」。
/// 计划 02 的装裱 UI 在 recipient == .circle 时嵌入本视图，
/// 把选中圈的 id 回写到正在装裱的 Capsule.circleID。
struct CirclePickerView: View {
    @Environment(ServiceContainer.self) private var services

    /// 当前选中的圈 id —— 与计划 02 装裱表单的 Capsule.circleID 双向绑定。
    @Binding var selectedCircleID: UUID?

    @State private var circles: [VoxlueData.Circle] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if isLoading {
                HStack { ProgressView(); Text("正在取声音圈…") }
            } else if circles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("你还没有声音圈。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("先建一个声音圈") { showCreateSheet = true }
                }
            } else {
                ForEach(circles) { circle in
                    Button {
                        selectedCircleID = circle.id
                    } label: {
                        HStack {
                            Text(circle.name.isEmpty ? "（未命名的圈）" : circle.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCircleID == circle.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCircleView(onCreated: { circle in
                selectedCircleID = circle.id
                Task { await reload() }
            })
        }
        .task { await reload() }
    }

    private func reload() async {
        isLoading = true
        circles = (try? await services.circleService.circles()) ?? []
        // 若当前选中的圈已不存在，清空选择。
        if let id = selectedCircleID, !circles.contains(where: { $0.id == id }) {
            selectedCircleID = nil
        }
        isLoading = false
    }
}

#Preview {
    @Previewable @State var selected: UUID?
    return Form {
        Section("埋给哪个圈") {
            CirclePickerView(selectedCircleID: $selected)
        }
    }
    .environment(ServiceContainer.preview())
}
