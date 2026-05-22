import Foundation

/// 一次录音的产物。
/// 契约定义见路线图 §3.1 —— 签名冻结，不得改动。
public struct RecordingResult: Sendable, Equatable, Hashable {
    public let audioData: Data
    public let duration: TimeInterval
    public let waveform: [Float]   // 归一化 0...1，60–120 个采样点

    public init(audioData: Data, duration: TimeInterval, waveform: [Float]) {
        self.audioData = audioData
        self.duration = duration
        self.waveform = waveform
    }
}
