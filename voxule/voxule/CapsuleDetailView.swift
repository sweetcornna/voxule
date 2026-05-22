import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

/// 胶囊详情 + 回放。
struct CapsuleDetailView: View {
    let capsule: VoxlueData.Capsule

    @Environment(\.appEnvironment) private var env
    @Environment(\.modelContext) private var context

    @State private var loaded = false
    @State private var loadFailed = false

    private var player: any AudioPlaying { env.player }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                WaveformView(
                    samples: capsule.waveform.isEmpty
                        ? [Float](repeating: 0.1, count: 80)
                        : capsule.waveform,
                    progress: player.progress,
                    tint: .accentColor
                )
                .frame(height: 96)

                playbackControls

                metadata
            }
            .padding()
        }
        .navigationTitle(capsule.title.isEmpty ? "（无题）" : capsule.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: prepare)
        .onDisappear { player.pause() }
        .alert("没能放出这段声音", isPresented: $loadFailed) {
            Button("好") {}
        } message: {
            Text("音频读取失败。")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: lockIcon)
            Text(lockLabel)
            Text("·")
            Text(stateLabel)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var playbackControls: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { player.progress },
                    set: { player.seek(toProgress: $0) }
                ),
                in: 0...1
            )
            HStack {
                Text(progressTimeString)
                Spacer()
                Text(durationString)
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

            Button {
                togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .disabled(!loaded)
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let place = capsule.placeName {
                LabeledContent("录于", value: place)
            }
            if let note = capsule.note, !note.isEmpty {
                LabeledContent("批注", value: note)
            }
            LabeledContent("埋于", value: capsule.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .font(.callout)
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

    private var progressTimeString: String {
        timeString(player.progress * capsule.duration)
    }

    private var durationString: String { timeString(capsule.duration) }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var lockIcon: String {
        switch capsule.lock.kind {
        case .place: "mappin.and.ellipse"
        case .date: "calendar"
        case .mood: "heart"
        }
    }

    private var lockLabel: String {
        switch capsule.lock.kind {
        case .place: "地点锁"
        case .date: "时间锁"
        case .mood: "情绪锁"
        }
    }

    private var stateLabel: String {
        switch capsule.state {
        case .buried: "已埋下"
        case .developing: "显影中"
        case .developed: "等你听"
        case .opened: "已开启"
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
