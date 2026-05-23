import VoxlueData

extension CapsuleState {
    /// 前端显示用 —— 与 SealStamp 的章面文字对齐，避免多个视图各写一套漂移。
    /// 仅在 app 壳层加扩展，不动 VoxlueData 包，规避跨轨接口变更。
    var displayLabel: String {
        switch self {
        case .buried: "已埋下"
        case .developing: "显影中"
        case .developed: "待你听"
        case .opened: "已开启"
        }
    }
}
