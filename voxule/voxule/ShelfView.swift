import SwiftUI
import SwiftData
import VoxlueData

/// 样片墙 —— 全部胶囊按埋下时间倒序排开，是 App 的主页。
struct ShelfView: View {
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    @State private var isRecording = false

    var body: some View {
        NavigationStack {
            Group {
                if capsules.isEmpty {
                    ContentUnavailableView(
                        "样片墙还空着",
                        systemImage: "rectangle.stack",
                        description: Text("冲一张声音，埋下它。")
                    )
                } else {
                    List {
                        ForEach(capsules) { capsule in
                            NavigationLink(value: capsule.id) {
                                CapsuleRow(capsule: capsule)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("样片墙")
            .navigationDestination(for: UUID.self) { id in
                if let capsule = capsules.first(where: { $0.id == id }) {
                    CapsuleDetailView(capsule: capsule)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("冲一张", systemImage: "mic.circle.fill") {
                        isRecording = true
                    }
                }
            }
            .fullScreenCover(isPresented: $isRecording) {
                RecordView()
            }
        }
    }
}

#Preview {
    ShelfView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
