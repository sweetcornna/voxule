import SwiftUI
import VoxlueData
import VoxlueServices

/// 声音圈列表 —— 自建的与受邀加入的圈都在这里。
struct CircleListView: View {
    @Environment(ServiceContainer.self) private var services

    @State private var circles: [VoxlueData.Circle] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("正在取声音圈…")
                } else if let loadError {
                    ContentUnavailableView(
                        "声音圈没取到",
                        systemImage: "exclamationmark.icloud",
                        description: Text(loadError)
                    )
                } else if circles.isEmpty {
                    ContentUnavailableView {
                        Label("还没有声音圈", systemImage: "person.2.wave.2")
                    } description: {
                        Text("建一个圈，把家人或挚友请进来。")
                    } actions: {
                        Button("建一个声音圈") { showCreateSheet = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(circles) { circle in
                        NavigationLink(value: circle.id) {
                            CircleRow(circle: circle)
                        }
                    }
                }
            }
            .navigationTitle("声音圈")
            .navigationDestination(for: UUID.self) { circleID in
                if let circle = circles.first(where: { $0.id == circleID }) {
                    CircleDetailView(circle: circle)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateCircleView(onCreated: { _ in Task { await reload() } })
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        loadError = nil
        do {
            circles = try await services.circleService.circles()
        } catch {
            loadError = "iCloud 暂时连不上。"
        }
        isLoading = false
    }
}

/// 列表里的一行圈。
private struct CircleRow: View {
    let circle: VoxlueData.Circle

    private var memberCount: Int { circle.members?.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(circle.name.isEmpty ? "（未命名的圈）" : circle.name)
                .font(.headline)
            Text("\(memberCount) 位成员")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview("有圈") {
    CircleListView()
        .environment(ServiceContainer.preview())
        .environment(HealthEnv(provider: FakeHealthProviding(snapshot: nil)))
}

#Preview("空") {
    CircleListView()
        .environment(ServiceContainer.previewEmpty())
        .environment(HealthEnv(provider: FakeHealthProviding(snapshot: nil)))
}
