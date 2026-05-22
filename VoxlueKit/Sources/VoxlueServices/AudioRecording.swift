import Foundation

/// 录音器。
/// 契约定义见路线图 §3.1 —— 签名冻结，不得改动。
@MainActor public protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    var elapsed: TimeInterval { get }            // 录制中实时秒数，驱动 UI
    func requestPermission() async -> Bool
    func start() throws
    func stop() async throws -> RecordingResult
    func cancel()
}
