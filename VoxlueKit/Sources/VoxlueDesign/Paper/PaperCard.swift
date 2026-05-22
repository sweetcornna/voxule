import SwiftUI

/// 纸卡 —— 暗房纸感容器基元。
/// 内容层永远是纸：暖白底、暖色阴影、克制圆角。绝不用玻璃。
public struct PaperCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(VoxlueSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                    .fill(VoxlueColor.paperHighlight)
            )
            .overlay(
                // 一道极淡的纸阴描边，强化「纸切边」。
                RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                    .strokeBorder(VoxlueColor.paperShadow, lineWidth: 0.75)
            )
            .voxlueShadow(.paper)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        PaperCard {
            VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                Text("一张待显影的纸卡")
                    .font(VoxlueTypography.serifTitle)
                    .foregroundStyle(VoxlueColor.ink)
                Text("内容层永远是纸 —— 暖白底、暖色阴影。")
                    .font(VoxlueTypography.serifBody)
                    .foregroundStyle(VoxlueColor.graphite)
            }
        }
        .padding(VoxlueSpacing.xl)
    }
}
