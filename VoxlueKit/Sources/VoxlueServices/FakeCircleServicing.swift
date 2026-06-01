import Foundation
import VoxlueData

/// `CircleServicing` 的假实现 —— 全内存，不接 CloudKit。
/// 供前端 UI、`#Preview` 与单元测试注入；不需要 iCloud 账号。
@MainActor
public final class FakeCircleServicing: CircleServicing {

    /// 已存在的圈（自建 + 受邀加入）。
    private var storedCircles: [Circle]
    /// circle.id → 已生成的邀请 URL，保证同圈邀请稳定。
    private var invitationURLs: [UUID: URL] = [:]

    /// - Parameter circles: 预置圈，便于预览展示非空列表。
    public init(circles: [Circle] = []) {
        self.storedCircles = circles
    }

    public func createCircle(name: String) async throws -> Circle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CircleServiceError.emptyCircleName }
        let circle = Circle(name: trimmed, ownerID: "fake-owner")
        circle.members = [
            CircleMember(name: "我", userRecordID: "fake-owner", role: .owner)
        ]
        storedCircles.append(circle)
        return circle
    }

    public func makeInvitation(for circle: Circle) async throws -> ShareInvitation {
        if let existing = invitationURLs[circle.id] {
            return ShareInvitation(url: existing)
        }
        let url = URL(string: "https://www.icloud.com/share/fake-\(circle.id.uuidString)")!
        invitationURLs[circle.id] = url
        return ShareInvitation(url: url)
    }

    public func acceptShare(from url: URL) async throws {
        guard FakeCircleServicing.looksLikeShareURL(url) else {
            throw CircleServiceError.invalidInvitationURL
        }
        let joined = Circle(name: "（受邀加入的圈）", ownerID: "someone-else")
        joined.members = [
            CircleMember(name: "我", userRecordID: "fake-owner", role: .member)
        ]
        storedCircles.append(joined)
    }

    public func circles() async throws -> [Circle] {
        storedCircles
    }

    /// 一个 URL 是否长得像 CKShare 邀请链接。真实 CKShare 链接形如
    /// `https://www.icloud.com/share/<token>`。纯函数，`nonisolated` 便于各处调用。
    ///
    /// 安全（D24）：host 必须**精确**是 icloud.com 或其子域，且 scheme 为 https。
    /// 旧实现用 `host.contains("icloud.com")` 子串匹配，`icloud.com.attacker.net`
    /// 之类的钓鱼域名可绕过，诱使 App 向攻击者 URL 发起 CloudKit shareMetadata 查询。
    nonisolated public static func looksLikeShareURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host()?.lowercased() else { return false }
        let isICloudHost = host == "icloud.com" || host.hasSuffix(".icloud.com")
        guard isICloudHost else { return false }
        return url.path().contains("/share/")
    }
}
