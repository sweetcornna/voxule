import SwiftUI
import UIKit

/// 把一个 CKShare 邀请链接交给系统 share sheet（iMessage / 复制 / AirDrop…）。
struct ShareInvitationSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [InvitationActivityItem(url: url)],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 给 share sheet 一段友好的随附文案（发 iMessage 时的引导语）。
private final class InvitationActivityItem: NSObject, UIActivityItemSource {
    let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "请你加入我的声音圈"
    }
}

#Preview {
    ShareInvitationSheet(url: URL(string: "https://www.icloud.com/share/fake-preview")!)
}
