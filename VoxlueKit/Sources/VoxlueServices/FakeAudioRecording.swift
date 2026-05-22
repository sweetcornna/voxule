import Foundation
import Observation

/// 假录音器 —— 不碰麦克风，返回固定 8 秒假波形。供 #Preview 与 UI 测试用。
@MainActor
@Observable
public final class FakeAudioRecording: AudioRecording {
    public private(set) var isRecording = false
    public private(set) var elapsed: TimeInterval = 0

    /// 固定假波形：80 个采样点的平滑正弦包络，归一化 0...1。
    public static let fakeWaveform: [Float] = (0..<80).map { i in
        let phase = Double(i) / 80.0 * .pi * 3
        return Float((sin(phase) * 0.5 + 0.5) * (0.4 + 0.6 * Double(i) / 80.0))
    }

    public init() {}

    public func requestPermission() async -> Bool { true }

    public func start() throws {
        isRecording = true
        elapsed = 0
    }

    public func stop() async throws -> RecordingResult {
        isRecording = false
        elapsed = 0
        return RecordingResult(
            audioData: Data("fake-audio".utf8),
            duration: 8,
            waveform: Self.fakeWaveform
        )
    }

    public func cancel() {
        isRecording = false
        elapsed = 0
    }
}
