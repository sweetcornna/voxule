// AudioEngine 真实现依赖 AVAudioSession（iOS 专有），整个文件用 #if os(iOS) 守卫。
// macOS（swift test 宿主）不编译它 —— 自动化测试只覆盖 Fake* 与纯函数。
#if os(iOS)
import Foundation
import AVFoundation
import Observation

/// 录音 / 播放 / 声纹采样的真实现，基于 AVFoundation。
/// 触麦克风，不进自动化测试 —— UI 测试与预览用 `FakeAudioRecording` / `FakeAudioPlaying`。
@MainActor
@Observable
public final class AudioEngine: NSObject, AudioRecording, AudioPlaying {

    // MARK: 录音状态
    public private(set) var isRecording = false
    public private(set) var elapsed: TimeInterval = 0

    // MARK: 回放状态
    public private(set) var isPlaying = false
    public private(set) var progress: Double = 0

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordURL: URL?
    private var levelTimer: Timer?
    private var progressTimer: Timer?
    /// 录音过程中周期采集的峰值电平（线性 0...1），停录时下采样为声纹。
    private var levelSamples: [Float] = []

    public override init() { super.init() }

    // MARK: - AudioRecording

    public func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func start() throws {
        try AudioSession.activateForRecording()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()

        self.recorder = recorder
        self.recordURL = url
        self.levelSamples = []
        self.elapsed = 0
        self.isRecording = true

        // 每 0.05s 采一次峰值电平，并刷新计时。
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleLevel() }
        }
        self.levelTimer = timer
    }

    private func sampleLevel() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime
        // averagePower 单位 dB（-160...0），转线性 0...1。
        let db = recorder.averagePower(forChannel: 0)
        let linear = db < -60 ? 0 : powf(10, db / 20)
        levelSamples.append(linear)
    }

    public func stop() async throws -> RecordingResult {
        levelTimer?.invalidate()
        levelTimer = nil
        guard let recorder, let url = recordURL else {
            throw AudioEngineError.notRecording
        }
        let duration = recorder.currentTime
        recorder.stop()
        isRecording = false
        AudioSession.deactivate()

        let data = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        self.recorder = nil
        self.recordURL = nil

        let waveform = Waveform.downsample(levelSamples, buckets: 80)
        elapsed = 0
        return RecordingResult(audioData: data, duration: duration, waveform: waveform)
    }

    public func cancel() {
        levelTimer?.invalidate()
        levelTimer = nil
        recorder?.stop()
        if let url = recordURL { try? FileManager.default.removeItem(at: url) }
        recorder = nil
        recordURL = nil
        levelSamples = []
        isRecording = false
        elapsed = 0
        AudioSession.deactivate()
    }

    // MARK: - AudioPlaying

    public func load(_ data: Data) throws {
        try AudioSession.activateForPlayback()
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        progress = 0
        isPlaying = false
    }

    public func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshProgress() }
        }
        progressTimer = timer
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        progressTimer?.invalidate()
        progressTimer = nil
    }

    public func seek(toProgress progress: Double) {
        guard let player else { return }
        let clamped = min(1, max(0, progress))
        player.currentTime = player.duration * clamped
        self.progress = clamped
    }

    private func refreshProgress() {
        guard let player, player.duration > 0 else { return }
        progress = min(1, player.currentTime / player.duration)
    }
}

extension AudioEngine: AVAudioPlayerDelegate {
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1
            self.progressTimer?.invalidate()
            self.progressTimer = nil
        }
    }
}

/// AudioEngine 错误。
public enum AudioEngineError: Error, Sendable {
    case notRecording
}
#endif
