import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

/// 浮现卡 —— 一枚被陪伴 agent 浮现的情绪胶囊。
/// 由灵动岛/通知点开进入；agent 闭环在前端的落点。
struct SurfacedCapsuleView: View {
    /// 被浮现胶囊的 id（agent 决定，经深链传入）。
    let capsuleID: UUID

    @Environment(\.appEnvironment) private var env
    @Environment(\.modelContext) private var context
    @Query private var capsules: [VoxlueData.Capsule]
    @State private var playFailed = false

    private var player: any AudioPlaying { env.player }

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
                    listen(to: capsule)
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
        .onDisappear { onLeave() }
        .alert("没能放出这段声音", isPresented: $playFailed) {
            Button("好") {}
        } message: {
            Text("音频读取失败。")
        }
    }

    /// 「听听看」—— 直接起回放。状态保持 .developing，待用户离开本卡再翻为 .opened，
    /// 避免回放刚开始就被 CapsuleDetailView 切换接管、把音频中断。
    private func listen(to capsule: VoxlueData.Capsule) {
        guard let data = capsule.audioData else {
            playFailed = true
            return
        }
        do {
            try player.load(data)
            player.play()
        } catch {
            playFailed = true
        }
    }

    /// 离开浮现卡：停回放并把胶囊翻到 .opened（仅当仍是 .developing），
    /// 以便下次进入时走常规详情。
    private func onLeave() {
        player.pause()
        if let capsule, capsule.state == .developing {
            try? CapsuleStore(context: context).updateState(capsule, to: .opened)
        }
    }
}

#Preview {
    let container = try! VoxlueModelContainer.make(inMemory: true)
    let capsule = VoxlueData.Capsule(title: "外婆喊吃饭", lock: .mood(notBefore: nil))
    container.mainContext.insert(capsule)
    return SurfacedCapsuleView(capsuleID: capsule.id)
        .modelContainer(container)
}
