import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

/// App 壳层依赖容器。集中持有领域服务，经环境注入功能视图。
/// MV 模式：服务即真相源，无 ViewModel。
@MainActor
@Observable
final class AppEnvironment {
    /// 录音器。生产用 AudioEngine 真实现；预览/测试注入 Fake。
    let recorder: any AudioRecording
    /// 播放器。
    let player: any AudioPlaying

    init(recorder: any AudioRecording, player: any AudioPlaying) {
        self.recorder = recorder
        self.player = player
    }

    /// 生产装配：真实 AudioEngine。录音与回放共用同一个 AudioEngine 实例。
    static func live() -> AppEnvironment {
        let engine = AudioEngine()
        return AppEnvironment(recorder: engine, player: engine)
    }

    /// 预览/测试装配：假实现，不碰麦克风。
    static func preview() -> AppEnvironment {
        AppEnvironment(recorder: FakeAudioRecording(), player: FakeAudioPlaying())
    }
}

extension EnvironmentValues {
    /// 经环境传递的 App 依赖容器。
    @Entry var appEnvironment: AppEnvironment = .preview()
}

/// 预览专用：所有 SwiftData 模型清单。供各视图 #Preview 建内存容器。
enum VoxlueDataModelsPreview {
    static let all: [any PersistentModel.Type] = [
        VoxlueData.Capsule.self,
        VoxlueData.Circle.self,
        VoxlueData.CircleMember.self,
    ]
}
