import SwiftUI

/// voxlue 暗房调色板 —— 纸·墨·朱 八色。
///
/// 设计意图（架构文档 §1 / §9）：
/// - 「纸」三色：暖白胶片基底，从亮到暗。偏奶油、偏暖，不是冷蓝屏幕白。
/// - 「墨」四色：黑白胶片的灰阶层次，从安全灯下的近黑到暗房灰。
/// - 「朱」一色：唯一强调色，印泥 / 暗房安全灯的温度。克制使用。
public enum VoxlueColor {

    // MARK: 纸 —— 暖白纸基（内容层底色）

    /// 纸基 · 主背景。米白偏暖的相纸色。
    public static let paper = Color(hex: 0xF3ECDF)
    /// 纸面高光 · 卡片受光面 / 留白。最亮的暖白。
    public static let paperHighlight = Color(hex: 0xFBF6EC)
    /// 纸阴 · 纸卡压低区 / 分隔。带灰的暖米色。
    public static let paperShadow = Color(hex: 0xDDD2BD)

    // MARK: 墨 —— 黑白胶片灰阶（文字 / 线条）

    /// 墨 · 正文与标题主色。暖调近黑，不是纯黑。
    public static let ink = Color(hex: 0x1F1B16)
    /// 石墨 · 次级文字 / 图标。暖中灰。
    public static let graphite = Color(hex: 0x5C554A)
    /// 暗房灰 · 三级文字 / 占位。浅暖灰。
    public static let darkroomGray = Color(hex: 0x9A9183)
    /// 负片黑 · 负片卡 / 暗房模式深底。最深的暖黑。
    public static let negativeBlack = Color(hex: 0x14110D)

    // MARK: 朱 —— 唯一强调色

    /// 朱红 · 印章 / 手写批注 / 关键强调。暖橘红。
    public static let vermillion = Color(hex: 0xC4452D)

    /// 全部八色，供 catalog 遍历与单测计数。
    public static let palette: [Color] = [
        paper, paperHighlight, paperShadow,
        ink, graphite, darkroomGray, negativeBlack,
        vermillion,
    ]

    /// 每色的中文名，catalog 标注用，与 palette 顺序一致。
    public static let paletteNames: [String] = [
        "纸基", "纸面高光", "纸阴",
        "墨", "石墨", "暗房灰", "负片黑",
        "朱红",
    ]
}
