import SwiftUI
import UIKit
import VoxlueDesign

/// 邀请已显影 —— 把 CKShare 链接交付给用户的暗房页面。
///
/// 流程：CircleDetailView 通过 `.sheet(item:)` 弹出本视图；用户读到链接、点
/// 「分享给朋友」后再叠一层系统 share sheet（iMessage / 复制 / AirDrop…），
/// 保持「先在纸上把章盖好，再递出去」的节奏，避免直接把冷冰冰的 UIKit
/// 弹窗糊到用户脸上。
struct ShareInvitationSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingSystemShare = false

    var body: some View {
        ZStack {
            // 纸基底 —— 与其他 sheet（AcceptInvitationView 等）共用语言。
            PaperBackground().ignoresSafeArea()

            VStack(spacing: VoxlueSpacing.xl) {
                // 朱章入场：链接已生成 = 显影完成。
                SealStamp(.developed)

                VStack(spacing: VoxlueSpacing.sm) {
                    Text("邀请链接已显影")
                        .font(VoxlueTypography.heading)
                        .foregroundStyle(VoxlueColor.ink)

                    Text("把这条链接交给想拉进圈里的人；对方点开即可加入。")
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.graphite)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VoxlueSpacing.md)
                }

                // URL 显示框 —— Space Mono 打字机字体 + 纸面凹槽，呼应「冲洗台」。
                urlPlate

                // 朱红 CTA —— 一次只引导一条路径：去系统 share sheet。
                Button {
                    isPresentingSystemShare = true
                } label: {
                    Label("分享给朋友", systemImage: "square.and.arrow.up")
                        .font(VoxlueTypography.serifBody)
                        .padding(.horizontal, VoxlueSpacing.md)
                        .padding(.vertical, VoxlueSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(VoxlueColor.vermillion)

                // 次级动作：留在原页（让用户能从容地复制链接再做别的）。
                Button("先不分享") { dismiss() }
                    .font(VoxlueTypography.caption)
                    .foregroundStyle(VoxlueColor.graphite)
                    .buttonStyle(.plain)
            }
            .padding(VoxlueSpacing.xl)
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $isPresentingSystemShare) {
            SystemShareSheet(url: url)
                .ignoresSafeArea()
        }
    }

    /// 链接显示槽 —— Space Mono + 浅墨描边，模拟暗房冲洗时的玻璃片。
    private var urlPlate: some View {
        Text(url.absoluteString)
            .font(VoxlueTypography.meta)
            .foregroundStyle(VoxlueColor.ink)
            .lineLimit(2)
            .truncationMode(.middle)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, VoxlueSpacing.md)
            .padding(.vertical, VoxlueSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                    .fill(VoxlueColor.paper.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                    .stroke(VoxlueColor.graphite.opacity(0.35), lineWidth: 0.75)
            )
    }
}

/// 把一个 CKShare 邀请链接交给系统 share sheet（iMessage / 复制 / AirDrop…）。
///
/// 之前是顶层视图；现在退到内层，只负责 UIKit 桥接。
private struct SystemShareSheet: UIViewControllerRepresentable {
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
