import SwiftUI

/// 胶片孔洞 —— 影像区上下两排片孔，让 PhotoCard / NegativeCard 是「胶片」而不是「卡片」。
/// 圆角小方孔，等距排列，纸色填充贴出片基。
public struct FilmPerforations: View {

    /// 排在影像哪一边：顶 / 底。两边都要的话叠两遍。
    public enum Edge: Sendable {
        case top, bottom
    }

    private let edge: Edge
    /// 颜色：默认 paperHighlight 贴亮底，给到 darkroomGray 也能盖在反相黑底上。
    private let holeColor: Color

    public init(edge: Edge, holeColor: Color = VoxlueColor.paperHighlight) {
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
                                .frame(width: spacing * 0.55, height: 5)
                        )
                }
            }
            .frame(height: 5)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: edge == .top ? .top : .bottom
            )
            .padding(.top, edge == .top ? 6 : 0)
            .padding(.bottom, edge == .bottom ? 6 : 0)
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
