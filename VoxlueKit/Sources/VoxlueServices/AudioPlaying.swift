import Foundation

/// 播放器。
/// 契约定义见路线图 §3.1 —— 签名冻结，不得改动。
@MainActor public protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    var progress: Double { get }                 // 0...1
    func load(_ data: Data) throws
    func play()
    func pause()
    func seek(toProgress progress: Double)
}
