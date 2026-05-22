import Foundation
import VoxlueData

/// 一份声音圈共享邀请。`url` 是 CKShare 链接，用于 iMessage / 系统分享。
public struct ShareInvitation: Sendable, Identifiable {
    public let url: URL          // CKShare 链接，用于 iMessage/分享
    /// URL 唯一，可直接作 SwiftUI `.sheet(item:)` 的标识。
    public var id: URL { url }

    public init(url: URL) {
        self.url = url
    }
}

/// 声音圈服务 —— 建圈、CKShare 邀请、共享同步。
///
/// 这是架构文档 §8 / §13 钉死的**隔离层**：v1 真实现走 SwiftData 原生共享，
/// 若原生共享某个边角不稳，可整体退回手写 `CKShare` 而不改本协议、不波及调用方。
/// 调用方（前端 UI、App 壳层）只认本协议。
@MainActor public protocol CircleServicing: AnyObject {
    /// 圈主建一个新声音圈。
    func createCircle(name: String) async throws -> Circle
    /// 为圈生成共享邀请（CKShare 链接）。
    func makeInvitation(for circle: Circle) async throws -> ShareInvitation
    /// 接受他人共享链接 —— 把圈与圈内胶囊落进自己的共享库。
    func acceptShare(from url: URL) async throws
    /// 当前用户可见的全部声音圈（自建的 + 已加入的）。
    func circles() async throws -> [Circle]
}

/// 声音圈服务可能抛出的错误。
public enum CircleServiceError: Error, Sendable, Equatable {
    /// 圈名为空或仅空白。
    case emptyCircleName
    /// 传入的链接不是有效的 CKShare 邀请链接。
    case invalidInvitationURL
    /// CloudKit 不可用（未登录 iCloud、无网络、缺账号等）。
    case cloudKitUnavailable
}
