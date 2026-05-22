import Foundation

/// VoxlueDesign 随包打包的字体文件清单。
/// 每一项对应 Sources/VoxlueDesign/Fonts/Resources 下的一个文件。
///
/// 四套开源字体（OFL 许可）均取自 Google Fonts。Crimson Pro / Caveat /
/// Noto Serif SC 上游是可变字体，已用 fontTools 实例化为静态字重；Noto Serif SC
/// 另做子集化（保留 ASCII + 常用汉字 + 标点）以控制体积。六个文件统一为 .ttf。
public enum VoxlueFontFile: String, CaseIterable, Sendable {
    case crimsonProRegular = "CrimsonPro-Regular"
    case crimsonProItalic  = "CrimsonPro-Italic"
    case notoSerifSCRegular  = "NotoSerifSC-Regular"
    case notoSerifSCSemiBold = "NotoSerifSC-SemiBold"
    case spaceMonoRegular = "SpaceMono-Regular"
    case caveatRegular    = "Caveat-Regular"

    /// 文件扩展名。六个文件统一为 TrueType（.ttf）。
    public var fileExtension: String { "ttf" }

    /// 该字体文件在 resource bundle 内的 URL；找不到返回 nil。
    public var url: URL? {
        Bundle.module.url(
            forResource: rawValue,
            withExtension: fileExtension,
            subdirectory: "Resources"
        )
    }
}
