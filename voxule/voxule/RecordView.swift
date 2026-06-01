import SwiftUI
import SwiftData
import VoxlueDesign
import VoxlueServices

/// 录音视图 —— 点按开始/停止录音，实时声纹与计时。
/// 停录后把 RecordingResult 交给装裱视图。
struct RecordView: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var permissionDenied = false
    @State private var recordingFailed = false
    @State private var liveSamples: [Float] = []
    @State private var result: RecordingResult?
    @State private var sampleTimer: Timer?
    @State private var isVisible = false
    @State private var confirmingCancel = false

    private var recorder: any AudioRecording { env.recorder }

    /// 录音情绪 —— 闲置 / 录音中 / 录到 30s 之后 / 录到 60s 之后。
    /// long / longer 都只是软提示，录音不会自动停。
    private enum RecordingMood {
        case idle
        case recording
        case long      // ≥30s
        case longer    // ≥60s
    }

    private var recordingMood: RecordingMood {
        guard recorder.isRecording else { return .idle }
        if recorder.elapsed >= 60 { return .longer }
        if recorder.elapsed >= 30 { return .long }
        return .recording
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VoxlueColor.negativeBlack.ignoresSafeArea()

                VStack(spacing: VoxlueSpacing.xl) {
                    Spacer()

                    Text(timeString(recorder.elapsed))
                        .font(VoxlueTypography.clock)
                        .foregroundStyle(VoxlueColor.paperHighlightLight)
                        .contentTransition(.numericText())

                    // 闲时：TimelineView 推呼吸波，darkroomGray；
                    // 录音：liveSamples + vermillion，节奏与电平绑定。
                    // 12fps（0.08s）够呼吸视觉，不浪费 CPU；视图不可见时停掉。
                    Group {
                        if isVisible {
                            TimelineView(.animation(minimumInterval: 0.08)) { context in
                                WaveformView(
                                    samples: recorder.isRecording
                                        ? (liveSamples.isEmpty ? breathingSamples(at: context.date) : liveSamples)
                                        : breathingSamples(at: context.date),
                                    tint: recorder.isRecording
                                        ? VoxlueColor.vermillion
                                        : VoxlueColor.darkroomGrayLight
                                )
                            }
                        } else {
                            // 不可见时返回静态占位，省 TimelineView 的 12fps 推送。
                            // 整屏永远是 negativeBlack 暗房底，波形 tint 用固定 light。
                            WaveformView(
                                samples: [Float](repeating: 0.07, count: 80),
                                tint: VoxlueColor.darkroomGrayLight
                            )
                        }
                    }
                    .frame(height: 80)
                    .padding(.horizontal, VoxlueSpacing.xl)
                    .onAppear { isVisible = true }
                    .onDisappear { isVisible = false }

                    Spacer()

                    Button {
                        recorder.isRecording ? stop() : start()
                    } label: {
                        // 110×110 朱红径向渐变球 —— 暗房整屏黑底里唯一的色温热点。
                        // 录音时中心放 38×38 paperLight 方块（停止信号），闲时放 mic glyph。
                        // 不用 .system stop.circle.fill / mic.circle.fill —— 系统 icon 的
                        // 描边与圆点比例与设计稿的「实心朱红球 + 留白方块」对不上。
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            VoxlueColor.vermillion,
                                            VoxlueColor.vermillion.opacity(0.82)
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 55
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .voxlueShadow(.paper)

                            if recorder.isRecording {
                                // 38×38 paperLight 方块 —— 停止信号。
                                // 锐角 2px 圆角保留一丝纸感，不彻底机械化。
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(VoxlueColor.paperHighlightLight)
                                    .frame(width: 38, height: 38)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 44, weight: .semibold))
                                    .foregroundStyle(VoxlueColor.paperHighlightLight)
                            }
                        }
                    }
                    .accessibilityLabel(recorder.isRecording ? "停止" : "开始冲洗")

                    // 30s / 60s 都是软提示，不是硬上限 —— 越过门槛就把灰小字换成朱红手写批注，
                    // 像冲洗师在样片边角随手记一句「差不多了」。录音继续，不打断。
                    Group {
                        switch recordingMood {
                        case .idle:
                            Text("点按，冲一张声音")
                                .font(VoxlueTypography.caption)
                                .foregroundStyle(VoxlueColor.darkroomGrayLight)
                        case .recording:
                            Text("正在冲洗这一张……")
                                .font(VoxlueTypography.caption)
                                .foregroundStyle(VoxlueColor.darkroomGrayLight)
                        case .long:
                            MarginNote("30 秒，差不多了。")
                        case .longer:
                            MarginNote("再多就讲不完了。")
                        }
                    }
                    .animation(.easeInOut(duration: 0.6), value: recordingMood)

                    Spacer()
                }
            }
            .navigationTitle("冲洗台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VoxlueColor.negativeBlack, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if recorder.elapsed > 5 {
                            confirmingCancel = true
                        } else {
                            discard()
                            dismiss()
                        }
                    }
                    // 与录音按钮同朱红 —— 让取消/录音两键在暗房里彼此呼应。
                    .foregroundStyle(VoxlueColor.vermillion)
                }
            }
            .confirmationDialog("丢掉这段录音？", isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("丢掉", role: .destructive) {
                    discard()
                    dismiss()
                }
                Button("继续录", role: .cancel) {}
            } message: {
                Text("已经录了 \(Int(recorder.elapsed)) 秒，丢了就没了。")
            }
            .alert("没有麦克风权限", isPresented: $permissionDenied) {
                Button("好") {}
            } message: {
                Text("请到「设置」里允许 voxlue 使用麦克风。")
            }
            .alert("没能开始冲洗", isPresented: $recordingFailed) {
                Button("好") {}
            } message: {
                Text("音频会话启动失败，请稍后再试。")
            }
            .navigationDestination(item: $result) { recording in
                FramingView(recording: recording) { dismiss() }
            }
        }
        // 兜底：无论经哪条路径离开冲洗台（取消 / 丢掉 / 关闭），都拆掉实时采样计时器。
        // 旧版仅 stop() 拆，两条取消路径会把 10Hz 计时器永久留在 runloop 上空转（D19）。
        .onDisappear {
            sampleTimer?.invalidate()
            sampleTimer = nil
        }
    }

    /// 闲时呼吸声纹 —— 一道极慢的正弦驻波，给暗房一点「在等你」的呼吸感。
    /// 用 TimelineView 驱动；phase 按时间线性走，sin 把它拍成 0~0.18 之间的低幅波。
    private func breathingSamples(at date: Date) -> [Float] {
        let t = date.timeIntervalSinceReferenceDate
        return (0..<80).map { i in
            let phase = Double(i) * 0.22 - t * 0.8
            return Float(0.07 + sin(phase) * 0.05 + sin(phase * 0.5) * 0.04)
        }
    }

    private func start() {
        Task {
            guard await recorder.requestPermission() else {
                permissionDenied = true
                return
            }
            do {
                try recorder.start()
                startLiveSampling()
            } catch {
                recordingFailed = true
            }
        }
    }

    /// 录音时每 0.1s 推一个随机抖动采样，仅作实时声纹动效占位 ——
    /// 真实声纹在 stop() 返回的 RecordingResult.waveform 里，由引擎按真实电平算出。
    private func startLiveSampling() {
        liveSamples = []
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard recorder.isRecording else { return }
                let value = Float.random(in: 0.2...1.0)
                liveSamples.append(value)
                if liveSamples.count > 80 { liveSamples.removeFirst() }
            }
        }
    }

    /// 丢弃当前录音：先拆实时采样计时器，再取消录音。两条取消路径共用，避免计时器空转（D19）。
    private func discard() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        recorder.cancel()
    }

    private func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        Task {
            do {
                result = try await recorder.stop()
            } catch {
                recorder.cancel()
                dismiss()
            }
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    RecordView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
