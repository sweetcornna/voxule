import Foundation
import Observation

/// 假播放器 —— 不解码音频，进度由 seek 直接驱动。供 #Preview 与 UI 测试用。
@MainActor
@Observable
public final class FakeAudioPlaying: AudioPlaying {
    public private(set) var isPlaying = false
    public private(set) var progress: Double = 0

    public init() {}

    public func load(_ data: Data) throws {
        progress = 0
        isPlaying = false
    }

    public func play() { isPlaying = true }

    public func pause() { isPlaying = false }

    public func seek(toProgress progress: Double) {
        self.progress = min(1, max(0, progress))
    }
}
