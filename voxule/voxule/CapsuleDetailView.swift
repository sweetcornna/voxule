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
    @Environment(\.dismiss) private var dismiss

    @State private var loaded = false
    @State private var loadFailed = false
    @State private var confirmingDelete = false

    private var player: any AudioPlaying { env.player }

    var body: some View {
        ZStack {
            PaperBackground().ignoresSafeArea()

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
        .toolbar { toolbarContent }
        .onAppear(perform: prepare)
        .onDisappear { player.pause() }
        .alert("没能放出这段声音", isPresented: $loadFailed) {
            Button("好") {}
        } message: {
            Text("音频读取失败。")
        }
        .alert("划掉这枚胶囊？", isPresented: $confirmingDelete) {
            Button("划掉", role: .destructive) { performDelete() }
            Button("不了", role: .cancel) {}
        } message: {
            Text("声音会从样片墙、地图和声音圈里消失。")
        }
    }

    /// 顶栏右上：分享 + 划掉。分享只在确有音频时露出。
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let audioData = capsule.audioData, !audioData.isEmpty {
                ShareLink(
                    item: audioData,
                    preview: SharePreview(displayTitle)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(VoxlueColor.ink)
                }
                .accessibilityLabel("分享")
            }

            Menu {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("划掉", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(VoxlueColor.ink)
            }
            .accessibilityLabel("更多")
        }
    }

    /// 划掉：先停播放器（不然 AVAudioPlayer 还在抓 data）→ store.delete → dismiss。
    private func performDelete() {
        player.pause()
        do {
            try CapsuleStore(context: context).delete(capsule)
        } catch {
            // 兜底：store 失败就直接走 context，免得卡死返回不了。
            context.delete(capsule)
            try? context.save()
        }
        dismiss()
    }

    /// 顶部相片 —— 按状态分流：
    /// .buried 显未显影的 NegativeCard 反相；其余走 PhotoCard 已显影。
    @ViewBuilder
    private var photoHero: some View {
        if capsule.state == .buried {
            NegativeCard(title: displayTitle, meta: headerMeta, seal: sealKind) {
                WaveformView(
                    samples: capsule.waveform.isEmpty
                        ? [Float](repeating: 0.1, count: 80)
                        : capsule.waveform,
                    progress: player.progress,
                    tint: VoxlueColor.darkroomGray
                )
                .padding(.horizontal, VoxlueSpacing.lg)
            }
        } else {
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
    }

    private var playbackControls: some View {
        PaperCard {
            VStack(spacing: VoxlueSpacing.lg) {
                // 滑杆区 —— 进度 + 双字体时间码 + 上下文批注。
                VStack(spacing: VoxlueSpacing.sm) {
                    Slider(
                        value: Binding(
                            get: { player.progress },
                            set: { player.seek(toProgress: $0) }
                        ),
                        in: 0...1
                    )
                    .tint(VoxlueColor.vermillion)

                    HStack(spacing: VoxlueSpacing.sm) {
                        // 左：Crimson Pro 计数器 —— 像胶片片头的西文计时。
                        Text(progressTimeString)
                            .font(VoxlueTypography.serifLatin(.body))
                            .foregroundStyle(VoxlueColor.ink)
                        // 播放时朱红圆点呼吸 —— 中段分隔。
                        // phaseAnimator 自动在 phases 间无限循环；不需要外面手动反复
                        // toggle @State 才能 repeatForever 生效（这是原写法的 bug）。
                        if player.isPlaying {
                            Circle()
                                .fill(VoxlueColor.vermillion)
                                .frame(width: 5, height: 5)
                                .phaseAnimator([false, true]) { content, phase in
                                    content.opacity(phase ? 1.0 : 0.3)
                                } animation: { _ in
                                    .easeInOut(duration: 0.8)
                                }
                        }
                        Spacer()
                        // 右：Space Mono 时长 —— 元数据冷调。
                        Text(durationString)
                            .font(VoxlueTypography.meta)
                            .foregroundStyle(VoxlueColor.graphite)
                    }

                    if let note = playbackMarginNote {
                        MarginNote(note)
                            .padding(.top, VoxlueSpacing.xs)
                    }
                }

                // 按钮区 —— 朱红脉冲环包裹的播放/暂停。
                // 用 phaseAnimator 在 [false, true] 间循环，scale 在 1.0 ↔ 1.12 之间呼吸；
                // 仅在 isPlaying 时让 scale 落到 phase 上，否则强制回 1.0。
                ZStack {
                    Circle()
                        .stroke(
                            VoxlueColor.vermillion.opacity(player.isPlaying ? 0.35 : 0.18),
                            lineWidth: 2
                        )
                        .frame(width: 64, height: 64)
                        .phaseAnimator([false, true]) { content, phase in
                            content.scaleEffect(player.isPlaying && phase ? 1.12 : 1.0)
                        } animation: { _ in
                            .easeInOut(duration: 0.9)
                        }

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
    }

    /// 滑杆下的上下文批注：播放中 / 听到一半 / 否则隐藏。
    private var playbackMarginNote: String? {
        if player.isPlaying {
            return "正在听 →"
        } else if loaded && player.progress > 0 {
            return "听到一半，可以接着"
        } else {
            return nil
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
