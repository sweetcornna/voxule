import SwiftUI
import SwiftData
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

    private var recorder: any AudioRecording { env.recorder }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(timeString(recorder.elapsed))
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .contentTransition(.numericText())

                WaveformView(samples: liveSamples.isEmpty ? idleSamples : liveSamples,
                             tint: recorder.isRecording ? .red : .secondary)
                    .frame(height: 80)
                    .padding(.horizontal)

                Spacer()

                Button {
                    recorder.isRecording ? stop() : start()
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                }
                .accessibilityLabel(recorder.isRecording ? "停止" : "开始冲洗")

                Text(recorder.isRecording ? "正在冲洗这一张……" : "点按，冲一张声音")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationTitle("冲洗台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        recorder.cancel()
                        dismiss()
                    }
                }
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
    }

    /// 未录音时显示的静默声纹占位。
    private var idleSamples: [Float] { [Float](repeating: 0.06, count: 80) }

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
