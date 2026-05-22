// AVAudioSession 仅在 iOS 等移动平台可用；macOS（swift test 宿主）无此 API。
// 整个文件用 #if os(iOS) 守卫 —— 真实现只在 App（iOS）构建时编译。
#if os(iOS)
import Foundation
import AVFoundation

/// AVAudioSession 配置 wrapper。把会话类别切换集中在一处，便于排障。
enum AudioSession {

    /// 切到录音类别（允许录音 + 默认走扬声器）。
    static func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    /// 切到回放类别。
    static func activateForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    /// 释放会话，把音频焦点还给系统。
    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
#endif
