// VoxlueDesign —— voxlue 设计系统层。
// P3 · Photographic Plate（暗房 / 黑白胶片美学）。
// 立意：纸的温度，不是屏幕的反光。
//
// 四块（架构文档 §9）：
//   1. 设计 tokens —— 纸·墨·朱 八色、字阶、圆角、暖色阴影。
//   2. 暗房纸感控件 —— 相片 / 负片 / 朱章 / 批注 / 纸卡。
//   3. 液态玻璃导航层 —— iOS 26 原生 glassEffect，暖色 tint。
//   4. 显影动效 —— 「霜化开」招牌转场。
//
// 方案 B：玻璃只在 chrome，纸只在 content。
public enum VoxlueDesign {
    /// 设计系统版本号，便于 catalog 标注。
    public static let version = "1.0"
}
