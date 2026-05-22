import SwiftUI
import SwiftData

/// App 根骨架 —— 三标签：样片墙 / 地图 / 我。
/// 地图与我在本计划仅占位，分别由计划 03、05 充实。
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("样片墙", systemImage: "rectangle.stack") {
                ShelfView()
            }
            Tab("地图", systemImage: "map") {
                NavigationStack { CapsuleMapView() }
            }
            Tab("我", systemImage: "person.crop.circle") {
                PlaceholderTab(title: "我", note: "声音圈与设置 —— 计划 05 充实。")
            }
        }
    }
}

/// 标签占位页。
private struct PlaceholderTab: View {
    let title: String
    let note: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hourglass", description: Text(note))
                .navigationTitle(title)
        }
    }
}

#Preview {
    RootTabView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
