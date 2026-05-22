import SwiftUI

/// 间距 token —— 4pt 网格。
public enum VoxlueSpacing {
    /// 4 —— 紧贴元素间。
    public static let xs: CGFloat = 4
    /// 8 —— 行内间距。
    public static let sm: CGFloat = 8
    /// 12 —— 卡内分组间。
    public static let md: CGFloat = 12
    /// 16 —— 卡片内边距。
    public static let lg: CGFloat = 16
    /// 24 —— 区块间。
    public static let xl: CGFloat = 24
    /// 32 —— 大留白。
    public static let xxl: CGFloat = 32

    /// 全部间距，由小到大。
    public static let allSteps: [CGFloat] = [xs, sm, md, lg, xl, xxl]
}

/// 圆角 token —— 暗房纸感，克制，偏方。
public enum VoxlueRadius {
    /// 2 —— 朱章 / 小标签的微圆角。
    public static let stamp: CGFloat = 2
    /// 6 —— 相片 / 负片卡。相纸切边的硬朗感。
    public static let photo: CGFloat = 6
    /// 10 —— 纸卡通用容器。
    public static let card: CGFloat = 10
    /// 22 —— 液态玻璃 chrome（玻璃层才用大圆角）。
    public static let glass: CGFloat = 22
}

/// 暖色阴影 token。
/// 阴影朝墨色偏暖，不用系统默认冷黑 —— 纸落在纸上的影子是暖的。
public struct VoxlueShadow: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    /// 纸卡阴影 —— 轻、暖、贴近。
    public static let paper = VoxlueShadow(
        color: Color(hex: 0x1F1B16).opacity(0.12),
        radius: 8, x: 0, y: 4
    )

    /// 相片阴影 —— 略抬起，相片浮在纸面上。
    public static let photo = VoxlueShadow(
        color: Color(hex: 0x1F1B16).opacity(0.18),
        radius: 14, x: 0, y: 8
    )

    /// 朱章阴影 —— 极轻，盖章压痕感。
    public static let stamp = VoxlueShadow(
        color: Color(hex: 0xC4452D).opacity(0.20),
        radius: 3, x: 0, y: 1
    )
}

public extension View {
    /// 套一个 voxlue 暖色阴影 token。
    func voxlueShadow(_ shadow: VoxlueShadow) -> some View {
        self.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x, y: shadow.y
        )
    }
}
