import SwiftUI

/// 液态玻璃 tint —— 偏纸奶油色，不用冷蓝科技玻璃（架构文档 §9）。
public enum GlassTint {
    /// 中性玻璃 tint —— 标签栏 / sheet / chrome 用。
    ///
    /// light：纸奶油色半透，盖在暖白基底上读起来像「上釉的纸」。
    /// dark：若直接跟 `paperHighlight` 翻面 → tint 变 0x1F1A14@55%，与 negativeBlack 背板
    /// 几乎同色，玻璃失去视觉重量。改成「永远的暖白」低不透明度，在暗底上保持
    /// 一道暖色薄釉、不抢内容也不消失。
    public static let cream = Color.voxlueAdaptive(
        light: VoxlueColor.paperHighlightLight.opacity(0.55),
        dark: VoxlueColor.paperHighlightLight.opacity(0.18)
    )

    /// 强调玻璃 tint —— 极淡朱红，显影相关 chrome（灵动岛、浮动「冲一张」键）用。
    /// 朱红不参与翻面，本身就是「永远是朱红」语义；不透明度也无需随 scheme 变。
    public static let vermillionWash = VoxlueColor.vermillion.opacity(0.22)
}

public extension View {
    /// 套一层暖色 iOS 26 液态玻璃 —— 默认 22pt 圆角矩形。
    /// 方案 B：只用在 chrome，绝不用在内容纸卡上。
    ///
    /// 圆形 mic、胶囊状浮按等场景必须把 `in:` 传成与最终 clipShape 一致的几何，
    /// 否则矩形玻璃的高光会沿矩形 4 条边走，被外层 clipShape(Circle()) 切成
    /// 一道弧形亮鳞（dark 下尤其刺眼）。
    /// - Parameter tint: 玻璃染色，默认纸奶油色。
    /// - Parameter shape: 玻璃形态，默认 22pt 圆角矩形。
    @ViewBuilder
    func voxlueGlass<S: Shape>(
        tint: Color = GlassTint.cream,
        interactive: Bool = false,
        in shape: S
    ) -> some View {
        self.glassEffect(
            .regular.tint(tint).interactive(interactive),
            in: shape
        )
    }

    /// 默认 22pt 圆角矩形的便捷重载 —— 内部转发给泛型 overload，单一实现源。
    /// Swift 不允许默认参数 + 泛型同时写默认 `RoundedRectangle(cornerRadius:)`
    /// （类型不可推），因此分两条入口；行为完全等价。
    func voxlueGlass(tint: Color = GlassTint.cream, interactive: Bool = false) -> some View {
        voxlueGlass(
            tint: tint,
            interactive: interactive,
            in: RoundedRectangle(cornerRadius: VoxlueRadius.glass, style: .continuous)
        )
    }
}
