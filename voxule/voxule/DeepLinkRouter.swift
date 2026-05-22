import SwiftUI
import VoxlueServices

/// 壳层深链路由 —— 处理进站的 CKShare 声音圈邀请。
/// 接受动作转交 `CircleServicing`；本类只管「接住事件 → 调服务 → 暴露结果给 UI」。
/// （`voxlue://capsule/` 胶囊深链由计划 03 的 `CapsuleRouter` 处理，与此互不相干。）
@MainActor
@Observable
final class DeepLinkRouter {

    /// 一次共享接受的结果，驱动落地页。
    enum AcceptanceState: Equatable {
        case idle
        case accepting
        case accepted
        case failed(String)
    }

    private(set) var acceptance: AcceptanceState = .idle

    private let circleService: any CircleServicing

    init(circleService: any CircleServicing) {
        self.circleService = circleService
    }

    /// 收到一个进站的 CKShare 链接 —— 接受它。
    func handleIncomingShare(url: URL) {
        acceptance = .accepting
        Task {
            do {
                try await circleService.acceptShare(from: url)
                acceptance = .accepted
            } catch CircleServiceError.invalidInvitationURL {
                acceptance = .failed("这不是一个有效的声音圈邀请链接。")
            } catch CircleServiceError.cloudKitUnavailable {
                acceptance = .failed("iCloud 暂时连不上，没能加入圈。")
            } catch {
                acceptance = .failed("加入失败：\(error.localizedDescription)")
            }
        }
    }

    /// 落地页关闭后复位。
    func reset() {
        acceptance = .idle
    }
}
