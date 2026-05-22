import SwiftUI

/// 液态玻璃 tint —— 偏纸奶油色，不用冷蓝科技玻璃（架构文档 §9）。
public enum GlassTint {
    /// 中性玻璃 tint —— 纸奶油色，半透。标签栏 / sheet 用。
    public static let cream = VoxlueColor.paperHighlight.opacity(0.55)

    /// 强调玻璃 tint —— 极淡朱红，显影相关 chrome（灵动岛、浮动「冲一张」键）用。
    public static let vermillionWash = VoxlueColor.vermillion.opacity(0.22)
}

public extension View {
    /// 套一层暖色 iOS 26 液态玻璃。方案 B：只用在 chrome，绝不用在内容纸卡上。
    /// - Parameter tint: 玻璃染色，默认纸奶油色。
    func voxlueGlass(tint: Color = GlassTint.cream, interactive: Bool = false) -> some View {
        self.glassEffect(
            .regular.tint(tint).interactive(interactive),
            in: .rect(cornerRadius: VoxlueRadius.glass)
        )
    }
}
