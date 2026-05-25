import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// voxlue 暗房调色板 —— 纸·墨·朱 八色。
///
/// 设计意图（架构文档 §1 / §9）：
/// - 「纸」三色：暖白胶片基底，从亮到暗。偏奶油、偏暖，不是冷蓝屏幕白。
/// - 「墨」四色：黑白胶片的灰阶层次，从安全灯下的近黑到暗房灰。
/// - 「朱」一色：唯一强调色，印泥 / 暗房安全灯的温度。克制使用。
///
/// 暗房模式（§9.3 / 2026-05-24 落地）：
/// - `paper / paperHighlight / paperShadow / ink / graphite / darkroomGray`
///   六只 token 公开为 colorScheme 自适应：light = 原暖白胶片基底，dark = 反相后的
///   负片黑底 + 暖白文字。这样所有「内容层永远是纸」的调用点（PaperCard、
///   `.background(VoxlueColor.paper)`、`.foregroundStyle(.ink)`）自动跟着 dark 翻面。
/// - `vermillion / negativeBlack` 不参与翻面 —— 朱红永远是朱红、PhotoCard 图像区
///   永远是负片黑底（这是暗房本体，不是主题色）。
/// - 永远的「亮底亮字」语境（NegativeCard 内文字、FilmPerforations、RecordView 整屏、
///   PhotoCard 内 waveform tint）用 `*Light` 固定变体，避免跟着 colorScheme 翻成黑底黑字。
public enum VoxlueColor {

    // MARK: 固定 light 原值 —— 旧八色 + 公开给「永远的亮底亮字」语境使用

    /// 纸基（固定 light）——「永远是暖白胶片基底」的语境，不跟随 colorScheme。
    /// 用于：NegativeCard 标题文字（永远在 negativeBlack 上）等。
    public static let paperLight = Color(hex: 0xF3ECDF)
    /// 纸面高光（固定 light）—— RecordView 计时器 / mic 图标、FilmPerforations
    /// 默认片孔色等永远盖在 negativeBlack 上的视觉元素用这个。
    public static let paperHighlightLight = Color(hex: 0xFBF6EC)
    /// 纸阴（固定 light）—— 罕用，留给未来需要永远暖灰的描边场景。
    public static let paperShadowLight = Color(hex: 0xDDD2BD)
    /// 墨（固定 light）—— 罕用。PaperGrain 的纸色噪点用；其他文字请用自适应 `ink`。
    public static let inkLight = Color(hex: 0x1F1B16)
    /// 石墨（固定 light）—— 罕用，留给完整对照。
    public static let graphiteLight = Color(hex: 0x5C554A)
    /// 暗房灰（固定 light）—— 用于 NegativeCard meta / 波形 idle tint 等永远在
    /// 暗底上的辅助色。跟随翻面会变得太暗、看不见。
    public static let darkroomGrayLight = Color(hex: 0x9A9183)

    // MARK: 固定 dark 原值 —— 自适应 token 在 dark 下的具体取值

    /// 纸基 dark 端 —— 与 negativeBlack 同值，暗房底片基的最深暖黑。
    static let paperDark = Color(hex: 0x14110D)
    /// 纸面高光 dark 端 —— 从负片黑微抬一档，胶片乳剂在安全灯下的颗粒亮度。
    static let paperHighlightDark = Color(hex: 0x1F1A14)
    /// 纸阴 dark 端 —— 卡边描边 / 头像底用的中暖灰。
    static let paperShadowDark = Color(hex: 0x2A2620)
    /// 墨 dark 端 —— 正文翻成暖白，与 paperLight 同值。
    static let inkDark = Color(hex: 0xF3ECDF)
    /// 石墨 dark 端 —— 次级文字提到 darkroomGrayLight 亮度仍可读。
    static let graphiteDark = Color(hex: 0xA8A092)
    /// 暗房灰 dark 端 —— 三级文字 / 占位，比 graphiteDark 暗一档。
    static let darkroomGrayDark = Color(hex: 0x7A7368)

    // MARK: 公开自适应 token —— 跟随 colorScheme 翻面

    /// 纸基 · 主背景。light = 米白偏暖的相纸色，dark = 负片黑底。
    /// PaperBackground 与 `.background(VoxlueColor.paper)` 自动跟随翻面。
    public static let paper = Color.voxlueAdaptive(light: paperLight, dark: paperDark)
    /// 纸面高光 · 卡片受光面 / 留白。light = 最亮的暖白，dark = 微抬一档的暖深黑。
    /// PaperCard / PhotoCard 片基条 / Capsule 高亮背景跟随翻面。
    public static let paperHighlight = Color.voxlueAdaptive(light: paperHighlightLight, dark: paperHighlightDark)
    /// 纸阴 · 纸卡压低区 / 分隔 / 描边。light = 带灰的暖米色，dark = 中暖灰。
    public static let paperShadow = Color.voxlueAdaptive(light: paperShadowLight, dark: paperShadowDark)
    /// 墨 · 正文与标题主色。light = 暖调近黑，dark = 暖白（与 paperLight 同）。
    public static let ink = Color.voxlueAdaptive(light: inkLight, dark: inkDark)
    /// 石墨 · 次级文字 / 图标。light = 暖中灰，dark = 提亮的暖中灰。
    public static let graphite = Color.voxlueAdaptive(light: graphiteLight, dark: graphiteDark)
    /// 暗房灰 · 三级文字 / 占位。light = 浅暖灰，dark = 暗一档的暖灰。
    public static let darkroomGray = Color.voxlueAdaptive(light: darkroomGrayLight, dark: darkroomGrayDark)

    // MARK: 永远不变的两色

    /// 负片黑 · 负片卡 / 暗房模式深底 / PhotoCard 图像区 / RecordView 整屏。
    /// 这是暗房本体而不是主题色 —— 任何 colorScheme 下都是最深的暖黑。
    public static let negativeBlack = Color(hex: 0x14110D)

    /// 朱红 · 印章 / 手写批注 / 关键强调。任何 colorScheme 下都是暖橘红。
    public static let vermillion = Color(hex: 0xC4452D)

    // MARK: catalog / 单测用

    /// 八色调色板（固定 light 端 + 朱红 + 负片黑），翻面对照「light 栏」与单测计数用。
    /// 顺序与 `paletteNames` 一致。整屏跟随翻面用 `adaptivePalette`、dark 端定值用 `darkPalette`。
    public static let palette: [Color] = [
        paperLight, paperHighlightLight, paperShadowLight,
        inkLight, graphiteLight, darkroomGrayLight, negativeBlack,
        vermillion,
    ]

    /// 自适应版八色 —— 前六只跟随 colorScheme 翻面、朱红 / 负片黑不变。
    /// catalog 顶部「八色铺面」用这套，保证打开 catalog 时上下两段视觉一致：
    /// 系统切到 dark，顶部 swatch 也跟着翻面，不会与下方「暗房模式 · 翻面对照」自相矛盾。
    public static let adaptivePalette: [Color] = [
        paper, paperHighlight, paperShadow,
        ink, graphite, darkroomGray, negativeBlack,
        vermillion,
    ]

    /// 暗房模式调色板（六只自适应 token 的 dark 端 + 朱红 + 负片黑），catalog 对照「dark 栏」用。
    /// 顺序与 `palette` 一一对应，便于左右铺成「翻面前 / 翻面后」两栏。
    public static let darkPalette: [Color] = [
        paperDark, paperHighlightDark, paperShadowDark,
        inkDark, graphiteDark, darkroomGrayDark, negativeBlack,
        vermillion,
    ]

    /// 每色的中文名，catalog 标注用，与 palette 顺序一致。
    public static let paletteNames: [String] = [
        "纸基", "纸面高光", "纸阴",
        "墨", "石墨", "暗房灰", "负片黑",
        "朱红",
    ]
}

// MARK: - 自适应 Color 工厂

public extension Color {
    /// 构造一只 colorScheme 自适应 Color：light 模式取 `light`，dark 模式取 `dark`。
    /// iOS 走 UIColor dynamic provider，SwiftUI 会在视图渲染的 trait collection 里
    /// 解析；macOS 测试环境直接落到 `light`，因为 VoxlueDesign 运行端仅 iOS。
    static func voxlueAdaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return light
        #endif
    }
}
