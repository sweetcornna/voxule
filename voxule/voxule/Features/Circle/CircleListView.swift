import SwiftUI
import VoxlueData
import VoxlueDesign
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
            ZStack {
                PaperBackground().ignoresSafeArea()

                Group {
                    if isLoading {
                        loadingState
                    } else if let loadError {
                        errorState(loadError)
                    } else if circles.isEmpty {
                        emptyState
                    } else {
                        circlesList
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
                            .foregroundStyle(VoxlueColor.ink)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(VoxlueColor.vermillion)
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

    private var loadingState: some View {
        VStack(spacing: VoxlueSpacing.md) {
            ProgressView()
                .tint(VoxlueColor.vermillion)
            Text("正在取声音圈…")
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: VoxlueSpacing.md) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 44))
                .foregroundStyle(VoxlueColor.darkroomGray)
            Text("声音圈没取到")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
            Text(message)
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        // 不再复用样片墙的 Crimson display "voxlue" hero —— Crimson 给唯一显著时刻；
        // 这里走 SF symbol + 思源宋 + Caveat 描述，与样片墙保持对话感的差异。
        VStack(spacing: VoxlueSpacing.lg) {
            Image(systemName: "person.2.wave.2")
                .font(.system(size: 44))
                .foregroundStyle(VoxlueColor.darkroomGray)
            Text("还没有声音圈")
                .font(VoxlueTypography.heading)
                .foregroundStyle(VoxlueColor.ink)
            MarginNote("圈起来，几个人就够。")
            Button("建一个声音圈") { showCreateSheet = true }
                .font(VoxlueTypography.serifBody)
                .buttonStyle(.borderedProminent)
                .tint(VoxlueColor.vermillion)
                .padding(.top, VoxlueSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 圈列表 —— List 套 PaperCard 风格的 row。
    private var circlesList: some View {
        List(circles) { circle in
            NavigationLink(value: circle.id) {
                CircleRow(circle: circle)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: VoxlueSpacing.sm,
                leading: VoxlueSpacing.lg,
                bottom: VoxlueSpacing.sm,
                trailing: VoxlueSpacing.lg
            ))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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

/// 列表里的一行圈 —— 纸卡风。
private struct CircleRow: View {
    let circle: VoxlueData.Circle

    private var memberCount: Int { circle.members?.count ?? 0 }

    var body: some View {
        PaperCard {
            HStack {
                VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
                    Text(circle.name.isEmpty ? "（未命名的圈）" : circle.name)
                        .font(VoxlueTypography.serifTitle)
                        .foregroundStyle(VoxlueColor.ink)
                    Text("\(memberCount) 位成员")
                        .font(VoxlueTypography.meta)
                        .foregroundStyle(VoxlueColor.graphite)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VoxlueColor.darkroomGray)
            }
        }
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
