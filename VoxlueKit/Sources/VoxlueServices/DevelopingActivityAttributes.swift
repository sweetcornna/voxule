// ActivityKit 仅在 iOS 等移动平台可用；macOS（swift test 宿主）无此 API。
// 整个文件用 #if os(iOS) 守卫 —— App 与 Widget Extension（均 iOS）共享这份契约。
#if os(iOS)
import Foundation
import ActivityKit

/// 「显影中」灵动岛 Live Activity 的数据契约。
/// App（起/结束 Activity）与 Widget Extension（渲染 UI）共享同一份定义。
public struct DevelopingActivityAttributes: ActivityAttributes {
    /// Live Activity 存续期间可变的动态状态。
    public struct ContentState: Codable, Hashable, Sendable {
        /// 显影进度 0...1，霜化动效用。
        public var developProgress: Double
        public init(developProgress: Double) {
            self.developProgress = developProgress
        }
    }

    /// 起 Activity 时定死的静态属性。
    public let capsuleID: UUID
    public let title: String

    public init(capsuleID: UUID, title: String) {
        self.capsuleID = capsuleID
        self.title = title
    }
}
#endif
