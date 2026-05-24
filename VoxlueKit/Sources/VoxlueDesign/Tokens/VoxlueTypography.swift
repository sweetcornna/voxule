import SwiftUI

/// voxlue 字阶与字体助手。
///
/// 字体栈（架构文档 §9）：
/// - Crimson Pro（斜体）—— display 标题，旧派书卷气。
/// - Noto Serif SC 思源宋 —— 中文正文。
/// - Space Mono —— 元数据（时间、坐标、时长），打字机式冷静。
/// - Caveat —— 朱红手写批注。
public enum VoxlueTypography {

    /// 六级字阶。size 单位 pt。
    public enum Step: CaseIterable, Sendable {
        case meta        // 元数据：坐标、时长、天气
        case caption     // 图注、次级说明
        case body        // 正文
        case title       // 卡片标题
        case heading     // 区段标题
        case display     // 大标题 / 启动词

        public var size: CGFloat {
            switch self {
            case .meta:    12
            case .caption: 14
            case .body:    17
            case .title:   20
            case .heading: 26
            case .display: 34
            }
        }

        public var lineSpacing: CGFloat {
            switch self {
            case .meta, .caption: 2
            case .body:           6
            case .title, .heading: 4
            case .display:        2
            }
        }
    }

    /// 全部字阶，由小到大。catalog 与单测用。
    public static let scale: [Step] = Step.allCases.sorted { $0.size < $1.size }

    // MARK: PostScript 字体名常量

    private enum PSName {
        static let crimsonRegular = "CrimsonPro-Regular"
        static let crimsonItalic  = "CrimsonPro-Italic"
        static let notoRegular    = "NotoSerifSC-Regular"
        static let notoSemiBold   = "NotoSerifSC-SemiBold"
        static let spaceMono      = "SpaceMono-Regular"
        static let caveat         = "Caveat-Regular"
    }

    /// 取自定义字体前确保已注册。
    private static func custom(_ name: String, size: CGFloat) -> Font {
        VoxlueFontRegistrar.registerAll()
        return Font.custom(name, size: size)
    }

    // MARK: Font 助手 —— 直接用在 .font(...)

    /// display 大标题：Crimson Pro 斜体，34pt。
    public static var display: Font {
        custom(PSName.crimsonItalic, size: Step.display.size)
    }

    /// 入场 hero 大字：Crimson Pro 斜体，56pt。仅给 Onboarding 第一屏的
    /// 「voxlue」与同等量级的 hero 标题用 —— 比 display 多一档诗意留白。
    public static var displayHero: Font {
        custom(PSName.crimsonItalic, size: 56)
    }

    /// 暗房时钟：Crimson Pro 斜体，72pt。只给 Record 冲洗台计时器用 ——
    /// 整屏负片黑底里需要这一档「老式秒表」字号才压得住，display 的 34pt
    /// 太收敛，会被 80pt 波形线挤走视觉焦点。
    public static var clock: Font {
        custom(PSName.crimsonItalic, size: 72)
    }

    /// 区段标题：思源宋 SemiBold，26pt。
    public static var heading: Font {
        custom(PSName.notoSemiBold, size: Step.heading.size)
    }

    /// 卡片标题：思源宋 SemiBold，20pt。
    public static var serifTitle: Font {
        custom(PSName.notoSemiBold, size: Step.title.size)
    }

    /// 中文正文：思源宋 Regular，17pt。
    public static var serifBody: Font {
        custom(PSName.notoRegular, size: Step.body.size)
    }

    /// 图注：思源宋 Regular，14pt。
    public static var caption: Font {
        custom(PSName.notoRegular, size: Step.caption.size)
    }

    /// 元数据：Space Mono，12pt。
    public static var meta: Font {
        custom(PSName.spaceMono, size: Step.meta.size)
    }

    /// 手写批注：Caveat，20pt（手写体视觉偏小，用 title 级补偿）。
    public static var annotation: Font {
        custom(PSName.caveat, size: Step.title.size)
    }

    /// 英文衬线（西文标题等）：Crimson Pro Regular，按指定字阶。
    public static func serifLatin(_ step: Step) -> Font {
        custom(PSName.crimsonRegular, size: step.size)
    }
}
