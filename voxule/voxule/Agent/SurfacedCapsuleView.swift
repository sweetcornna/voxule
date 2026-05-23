import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 浮现卡 —— 一枚被陪伴 agent 浮现的情绪胶囊。
/// 由灵动岛/通知点开进入；agent 闭环在前端的落点。
/// 整页用纸基底，中央一张 PaperCard 放正题与朱红「听听看」CTA；显影中带霜化开入场。
struct SurfacedCapsuleView: View {
    /// 被浮现胶囊的 id（agent 决定，经深链传入）。
    let capsuleID: UUID

    @Environment(\.appEnvironment) private var env
    @Environment(\.modelContext) private var context
    @Query private var capsules: [VoxlueData.Capsule]
    @State private var playFailed = false
    @State private var developed = false

    private var player: any AudioPlaying { env.player }

    init(capsuleID: UUID) {
        self.capsuleID = capsuleID
        _capsules = Query(filter: #Predicate { $0.id == capsuleID })
    }

    private var capsule: VoxlueData.Capsule? { capsules.first }

    var body: some View {
        ZStack {
            VoxlueColor.paper.ignoresSafeArea().paperGrain()

            if let capsule {
                VStack(spacing: VoxlueSpacing.xl) {
                    Spacer()

                    Text("一段你埋下的声音，浮上来了")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.graphite)
                        .tracking(1)

                    PaperCard {
                        VStack(spacing: VoxlueSpacing.md) {
                            Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                                .font(VoxlueTypography.heading)
                                .foregroundStyle(VoxlueColor.ink)
                                .multilineTextAlignment(.center)

                            if let place = capsule.placeName {
                                Label(place, systemImage: "mappin.and.ellipse")
                                    .font(VoxlueTypography.meta)
                                    .foregroundStyle(VoxlueColor.graphite)
                            }

                            Button {
                                listen(to: capsule)
                            } label: {
                                Label("听听看", systemImage: "play.circle.fill")
                                    .font(VoxlueTypography.serifBody)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, VoxlueSpacing.sm)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(VoxlueColor.vermillion)
                            .controlSize(.large)
                            .padding(.top, VoxlueSpacing.xs)
                        }
                    }
                    .frostReveal(developed: developed)
                    .overlay(alignment: .topTrailing) {
                        // Caveat 手写边注：像冲洗师在样片角落落了一句。
                        MarginNote("今天，它想被你听到。")
                            .offset(x: 16, y: -8)
                            .rotationEffect(.degrees(2))
                    }

                    Text("不急。它会一直在这里，等你想听的时候。")
                        .font(VoxlueTypography.caption)
                        .foregroundStyle(VoxlueColor.darkroomGray)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, VoxlueSpacing.xl)
            } else {
                ContentUnavailableView("这枚胶囊不在了", systemImage: "questionmark.circle")
            }
        }
        .onAppear {
            // 入场霜化开：FrostReveal 内部自带 `.animation(_:value:)`，外层不要再 withAnimation
            // 包，否则两条动画路径会互相覆盖。同步 onAppear 改 @State 可能与首帧 commit 合并，
            // 导致直接落在 developed=true 状态、动画被吞 —— DispatchQueue.main.async 把翻转推迟
            // 到下一拍，让第一帧渲染霜化态。
            DispatchQueue.main.async { developed = true }
        }
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
