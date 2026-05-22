import Foundation
import SwiftUI

/// 深链 / 通知路由 —— 把外部入口（通知点击、Live Activity 点击、URL Scheme）
/// 统一解析成「要打开哪枚胶囊」，驱动导航。
/// 通知点击经 `NotificationDelegate` 落到这里；URL/灵动岛经 `handle(url:)`。
@MainActor
@Observable
final class CapsuleRouter {
    /// 当前要展示详情的胶囊 —— 根视图据它弹出详情。
    var routedCapsuleID: UUID?

    /// 解析一条深链 URL，形如 `voxlue://capsule/<uuid>`。
    func handle(url: URL) {
        guard url.scheme == "voxlue", url.host == "capsule" else { return }
        let idString = url.lastPathComponent
        guard let id = UUID(uuidString: idString) else { return }
        routedCapsuleID = id
    }
}
