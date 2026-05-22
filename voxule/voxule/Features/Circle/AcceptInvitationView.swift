import SwiftUI
import VoxlueServices

/// 接受声音圈邀请的落地页 —— 由 DeepLinkRouter.acceptance 驱动。
struct AcceptInvitationView: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            switch router.acceptance {
            case .idle:
                Color.clear

            case .accepting:
                ProgressView()
                Text("正在把你请进这个声音圈…")
                    .font(.headline)

            case .accepted:
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("你已加入这个声音圈")
                    .font(.title3.weight(.semibold))
                Text("圈里的声音会慢慢同步到你这边。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("好的") { dismiss() }
                    .buttonStyle(.borderedProminent)

            case .failed(let reason):
                Image(systemName: "xmark.octagon")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                Text("没能加入")
                    .font(.title3.weight(.semibold))
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .presentationDetents([.medium])
    }
}

#Preview("接受中") {
    AcceptInvitationView()
        .environment(previewRouter(.accepting))
}

#Preview("已加入") {
    AcceptInvitationView()
        .environment(previewRouter(.accepted))
}

#Preview("失败") {
    AcceptInvitationView()
        .environment(previewRouter(.failed("这不是一个有效的声音圈邀请链接。")))
}

// 预览辅助：构造一个停在指定状态的 router。
@MainActor
private func previewRouter(_ state: DeepLinkRouter.AcceptanceState) -> DeepLinkRouter {
    let router = DeepLinkRouter(circleService: FakeCircleServicing())
    switch state {
    case .accepting:
        router.handleIncomingShare(url: URL(string: "https://www.icloud.com/share/preview")!)
    case .failed:
        router.handleIncomingShare(url: URL(string: "https://example.com/bad")!)
    default:
        break
    }
    return router
}
