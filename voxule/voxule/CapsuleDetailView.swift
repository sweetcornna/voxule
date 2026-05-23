import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign
import VoxlueServices

/// 胶囊详情 + 回放。改用相片卡 + 纸基容器：顶部 PhotoCard 露图像，
/// 下面纸卡放回放控件与元数据。
struct CapsuleDetailView: View {
    let capsule: VoxlueData.Capsule

    @Environment(\.appEnvironment) private var env
    @Environment(\.modelContext) private var context

    @State private var loaded = false
    @State private var loadFailed = false

    private var player: any AudioPlaying { env.player }

    var body: some View {
        ZStack {
            VoxlueColor.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: VoxlueSpacing.xl) {
                    photoHero
                    playbackControls
                    metadata
                }
                .padding(VoxlueSpacing.lg)
            }
        }
        .navigationTitle(capsule.title.isEmpty ? "（无题）" : capsule.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: prepare)
        .onDisappear { player.pause() }
        .alert("没能放出这段声音", isPresented: $loadFailed) {
            Button("好") {}
        } message: {
            Text("音频读取失败。")
        }
    }

    /// 顶部相片 —— 用 PhotoCard 包声纹波形，朱章盖在右上（PhotoCard 内部对齐）。
    private var photoHero: some View {
        PhotoCard(title: displayTitle, meta: headerMeta, seal: sealKind) {
            WaveformView(
                samples: capsule.waveform.isEmpty
                    ? [Float](repeating: 0.1, count: 80)
                    : capsule.waveform,
                progress: player.progress,
                tint: VoxlueColor.paperHighlight
            )
            .padding(.horizontal, VoxlueSpacing.lg)
        }
    }

    private var playbackControls: some View {
        PaperCard {
            VStack(spacing: VoxlueSpacing.md) {
                Slider(
                    value: Binding(
                        get: { player.progress },
                        set: { player.seek(toProgress: $0) }
                    ),
                    in: 0...1
                )
                .tint(VoxlueColor.vermillion)
                HStack {
                    Text(progressTimeString)
                    Spacer()
                    Text(durationString)
                }
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.graphite)

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(VoxlueColor.vermillion)
                }
                .disabled(!loaded)
                .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
            }
        }
    }

    private var metadata: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                if let place = capsule.placeName {
                    metadataRow(label: "录于", value: place)
                }
                if let note = capsule.note, !note.isEmpty {
                    metadataRow(label: "批注", value: note)
                }
                metadataRow(
                    label: "埋于",
                    value: capsule.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(VoxlueTypography.caption)
                .foregroundStyle(VoxlueColor.graphite)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(VoxlueTypography.serifBody)
                .foregroundStyle(VoxlueColor.ink)
            Spacer()
        }
    }

    private func prepare() {
        guard !loaded else { return }
        guard let data = capsule.audioData, !data.isEmpty else {
            loadFailed = true
            return
        }
        do {
            try player.load(data)
            loaded = true
        } catch {
            loadFailed = true
        }
    }

    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
            markOpenedIfNeeded()
        }
    }

    /// 首次播放把胶囊状态推进到 opened。
    private func markOpenedIfNeeded() {
        guard capsule.state != .opened else { return }
        try? CapsuleStore(context: context).updateState(capsule, to: .opened)
    }

    private var displayTitle: String {
        capsule.title.isEmpty ? "（无题）" : capsule.title
    }

    /// 片基小字 —— 锁 · 时长 · 状态。
    private var headerMeta: String {
        var parts: [String] = [lockLabel]
        if capsule.duration > 0 {
            parts.append(durationString)
        }
        parts.append(capsule.state.displayLabel)
        return parts.joined(separator: " · ")
    }

    private var progressTimeString: String {
        timeString(player.progress * capsule.duration)
    }

    private var durationString: String { timeString(capsule.duration) }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var lockLabel: String {
        switch capsule.lock.kind {
        case .place: "地点锁"
        case .date: "时间锁"
        case .mood: "情绪锁"
        }
    }

    private var sealKind: SealStamp.Kind {
        switch capsule.state {
        case .buried: .buried
        case .developing: .developing
        case .developed: .developed
        case .opened: .opened
        }
    }
}

#Preview {
    NavigationStack {
        CapsuleDetailView(
            capsule: VoxlueData.Capsule(
                title: "咖啡馆的雨",
                audioData: Data("preview".utf8),
                duration: 8,
                waveform: FakeAudioRecording.fakeWaveform,
                state: .developed,
                lock: .date(.now)
            )
        )
    }
    .environment(\.appEnvironment, .preview())
    .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
