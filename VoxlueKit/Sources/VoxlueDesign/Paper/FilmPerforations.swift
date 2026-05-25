import SwiftUI

/// 胶片孔洞 —— 影像区上下两排片孔，让 PhotoCard / NegativeCard 是「胶片」而不是「卡片」。
/// 圆角小方孔，等距排列，纸色填充贴出片基。
public struct FilmPerforations: View {

    /// 排在影像哪一边：顶 / 底。两边都要的话叠两遍。
    public enum Edge: Sendable {
        case top, bottom
    }

    // MARK: 公开尺寸 token —— 让外部组件（朱章 / 标题）能算让出多少空间。

    /// 单个片孔的高度。
    public static let rowHeight: CGFloat = 5
    /// 片孔距影像区上/下边缘的内边距。
    public static let edgeInset: CGFloat = 6
    /// 朱章 / 文字等内容应让出的最小顶 / 底距，避开片孔区。
    public static let safeContentInset: CGFloat = rowHeight + edgeInset + 4

    private let edge: Edge
    /// 颜色：默认 paperHighlightLight 贴亮底 —— 片孔永远在 PhotoCard 的负片黑图像区
    /// 之上，不跟随 colorScheme 翻面（否则 dark 下会被 elevated dark 吃掉）。
    /// 反相态调用方传 darkroomGrayLight。
    private let holeColor: Color

    public init(edge: Edge, holeColor: Color = VoxlueColor.paperHighlightLight) {
        self.edge = edge
        self.holeColor = holeColor
    }

    public var body: some View {
        GeometryReader { proxy in
            let count = max(6, Int(proxy.size.width / 18))
            let spacing = proxy.size.width / CGFloat(count)
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { _ in
                    Spacer()
                        .frame(width: spacing)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .fill(holeColor)
                                .frame(width: spacing * 0.55, height: Self.rowHeight)
                        )
                }
            }
            .frame(height: Self.rowHeight)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: edge == .top ? .top : .bottom
            )
            .padding(.top, edge == .top ? Self.edgeInset : 0)
            .padding(.bottom, edge == .bottom ? Self.edgeInset : 0)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        VStack(spacing: VoxlueSpacing.xl) {
            // 亮底：纸色片孔。
            Rectangle()
                .fill(VoxlueColor.negativeBlack)
                .frame(height: 150)
                .overlay(FilmPerforations(edge: .top))
                .overlay(FilmPerforations(edge: .bottom))
                .clipShape(RoundedRectangle(cornerRadius: VoxlueRadius.photo, style: .continuous))
        }
        .padding(VoxlueSpacing.xl)
    }
}
