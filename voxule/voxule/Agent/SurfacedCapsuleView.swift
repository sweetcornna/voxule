import SwiftUI
import SwiftData
import VoxlueData

/// 浮现卡 —— 一枚被陪伴 agent 浮现的情绪胶囊。
/// 由灵动岛/通知点开进入；agent 闭环在前端的落点。
struct SurfacedCapsuleView: View {
    /// 被浮现胶囊的 id（agent 决定，经深链传入）。
    let capsuleID: UUID

    @Environment(\.modelContext) private var context
    @Query private var capsules: [VoxlueData.Capsule]

    init(capsuleID: UUID) {
        self.capsuleID = capsuleID
        _capsules = Query(filter: #Predicate { $0.id == capsuleID })
    }

    private var capsule: VoxlueData.Capsule? { capsules.first }

    var body: some View {
        VStack(spacing: 24) {
            if let capsule {
                Spacer()
                Text("一段你埋下的声音，浮上来了")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let place = capsule.placeName {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    let store = CapsuleStore(context: context)
                    try? store.updateState(capsule, to: .opened)
                } label: {
                    Label("听听看", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("不急。它会一直在这里，等你想听的时候。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                ContentUnavailableView("这枚胶囊不在了", systemImage: "questionmark.circle")
            }
        }
        .padding(32)
    }
}

#Preview {
    let container = try! VoxlueModelContainer.make(inMemory: true)
    let capsule = VoxlueData.Capsule(title: "外婆喊吃饭", lock: .mood(notBefore: nil))
    container.mainContext.insert(capsule)
    return SurfacedCapsuleView(capsuleID: capsule.id)
        .modelContainer(container)
}
