# voxlue 计划 04 · 设计系统与液态玻璃（VoxlueDesign）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `VoxlueKit` 里新建 `VoxlueDesign` 库目标，落地 voxlue 暗房美学的全套设计系统 —— 纸·墨·朱八色 tokens、四套字体栈、暗房纸感控件（相片/负片/朱章/批注/纸卡）、iOS 26 原生液态玻璃导航层、「霜化开」显影动效，并附一个可视化图鉴 catalog 视图。可测的部分（颜色 hex、字阶值、圆角、字体注册）写 Swift Testing 单测；纯视觉控件以「构建通过 + catalog 预览渲染 + 模拟器截图」验证。

**Architecture:** `VoxlueDesign` 是 `VoxlueKit` 包内第三个 library 目标（与 `VoxlueData`、待建的 `VoxlueServices` 并列，见路线图 §3.0）。它**不依赖** `VoxlueData` / `VoxlueServices` —— 纯 SwiftUI + CoreText，可独立编译、独立测试、独立预览。设计系统层对应架构文档 §4 的「设计系统层」与 §9 的四块内容。方案 B 原则贯穿全程：**液态玻璃只在 chrome（导航层），纸感只在 content（内容层）**。字体以 SPM `resources:` 打包，首次使用时用 `CTFontManagerRegisterFontsForURL` 注册。

**Tech Stack:** Swift 6.2 · SwiftUI · CoreText（字体注册）· iOS 26 Liquid Glass（`glassEffect` / `GlassEffectContainer`）· Swift Testing · Xcode 26.5

**前置条件:** 已完成计划 01（`VoxlueKit` 包与 `VoxlueData` 已合入 `main`）；已安装 Xcode 26.5；有 iPhone 17 模拟器；能访问 Google Fonts 下载四套开源字体。本计划**无后端依赖**，是前端轨第一件开工的事。

**对应设计文档:** `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md` 的 §1（P3 Photographic Plate 暗房美学）、§9（前端/液态玻璃层）；路线图 §1、§3.0、§6。

---

## 文件结构

```
/Users/cornna/project/voxule/
├── VoxlueKit/
│   ├── Package.swift                              ← 改：新增 VoxlueDesign 目标 + resources
│   ├── Sources/VoxlueDesign/
│   │   ├── Tokens/
│   │   │   ├── VoxlueColor.swift                  纸·墨·朱 八色调色板
│   │   │   ├── VoxlueColor+Hex.swift              Color(hex:) 工具
│   │   │   ├── VoxlueSpacing.swift                间距 / 圆角 / 暖色阴影
│   │   │   └── VoxlueTypography.swift             字阶 + Font 助手
│   │   ├── Fonts/
│   │   │   ├── VoxlueFontRegistrar.swift          CTFontManager 注册逻辑
│   │   │   └── Resources/                         ← 工程师手动放 6 个字体文件
│   │   │       ├── CrimsonPro-Italic.ttf
│   │   │       ├── CrimsonPro-Regular.ttf
│   │   │       ├── NotoSerifSC-Regular.otf
│   │   │       ├── NotoSerifSC-SemiBold.otf
│   │   │       ├── SpaceMono-Regular.ttf
│   │   │       └── Caveat-Regular.ttf
│   │   ├── Paper/
│   │   │   ├── PaperCard.swift                    纸卡（纸感容器基元）
│   │   │   ├── PhotoCard.swift                    相片
│   │   │   ├── NegativeCard.swift                 负片
│   │   │   ├── SealStamp.swift                    朱章
│   │   │   └── MarginNote.swift                   批注
│   │   ├── Glass/
│   │   │   ├── GlassTint.swift                    暖色玻璃 tint 常量
│   │   │   ├── GlassChrome.swift                  标签栏 / sheet / 浮动控制 wrapper
│   │   │   └── DevelopingIslandLabel.swift        灵动岛玻璃标签
│   │   ├── Motion/
│   │   │   └── DevelopTransition.swift            「霜化开」显影转场
│   │   └── Catalog/
│   │       └── DesignCatalogView.swift            预览图鉴
│   └── Tests/VoxlueDesignTests/
│       ├── ColorTests.swift
│       ├── HexTests.swift
│       ├── SpacingTests.swift
│       ├── TypographyTests.swift
│       └── FontRegistrarTests.swift
└── voxule/voxule/voxule/
    └── DebugRootView.swift                        ← 改：临时挂 DesignCatalogView 入口
```

---

## Task 1: 在 VoxlueKit 新增 VoxlueDesign 目标 【前端】

**Files:**
- Modify: `VoxlueKit/Package.swift`
- Create: `VoxlueKit/Sources/VoxlueDesign/VoxlueDesign.swift`
- Create: `VoxlueKit/Tests/VoxlueDesignTests/SmokeTests.swift`

- [ ] **Step 1: 改 Package.swift 新增目标**

把 `VoxlueKit/Package.swift` 全文替换为（新增 `VoxlueDesign` product + target + testTarget；字体资源声明留到 Task 3 字体文件就位后再加，先保证目标可编译）：

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VoxlueKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "VoxlueData", targets: ["VoxlueData"]),
        .library(name: "VoxlueDesign", targets: ["VoxlueDesign"]),
    ],
    targets: [
        .target(name: "VoxlueData"),
        .testTarget(name: "VoxlueDataTests", dependencies: ["VoxlueData"]),
        // VoxlueDesign 独立、不依赖 VoxlueData/VoxlueServices（路线图 §3.0）。
        .target(name: "VoxlueDesign"),
        .testTarget(name: "VoxlueDesignTests", dependencies: ["VoxlueDesign"]),
    ]
)
```

- [ ] **Step 2: 创建模块根文件**

创建 `VoxlueKit/Sources/VoxlueDesign/VoxlueDesign.swift`：

```swift
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
```

- [ ] **Step 3: 写冒烟测试**

创建 `VoxlueKit/Tests/VoxlueDesignTests/SmokeTests.swift`：

```swift
import Testing
@testable import VoxlueDesign

@Test func moduleLoads() {
    #expect(VoxlueDesign.version == "1.0")
}
```

- [ ] **Step 4: 验证包可测试**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter VoxlueDesignTests`
Expected: 输出包含 `Test run with 1 test passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Package.swift VoxlueKit/Sources/VoxlueDesign VoxlueKit/Tests/VoxlueDesignTests
git commit -m "feat(design): 新增 VoxlueDesign 库目标"
```

---

## Task 2: 设计 tokens —— 纸·墨·朱 八色调色板 【前端】

八色暗房调色板。暖白纸基（非冷蓝），墨黑墨灰构成黑白胶片层次，一抹朱红做唯一强调色（印泥 / 暗房安全灯的温度）。先做 `Color(hex:)` 工具，再做调色板。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueColor+Hex.swift`
- Create: `VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueColor.swift`
- Test: `VoxlueKit/Tests/VoxlueDesignTests/HexTests.swift`
- Test: `VoxlueKit/Tests/VoxlueDesignTests/ColorTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDesignTests/HexTests.swift`：

```swift
import Testing
import SwiftUI
@testable import VoxlueDesign

@MainActor
@Test func hexParsesPureWhite() {
    let c = Color(hex: 0xFFFFFF)
    let res = c.resolve(in: .init())
    #expect(abs(res.red - 1) < 0.01)
    #expect(abs(res.green - 1) < 0.01)
    #expect(abs(res.blue - 1) < 0.01)
}

@MainActor
@Test func hexParsesPureBlack() {
    let c = Color(hex: 0x000000)
    let res = c.resolve(in: .init())
    #expect(abs(res.red) < 0.01)
    #expect(abs(res.green) < 0.01)
    #expect(abs(res.blue) < 0.01)
}

@MainActor
@Test func hexParsesVermillionChannels() {
    // 朱红 0xC4452D → R 196 / G 69 / B 45。
    let res = Color(hex: 0xC4452D).resolve(in: .init())
    #expect(abs(res.red - 196.0 / 255.0) < 0.01)
    #expect(abs(res.green - 69.0 / 255.0) < 0.01)
    #expect(abs(res.blue - 45.0 / 255.0) < 0.01)
}
```

创建 `VoxlueKit/Tests/VoxlueDesignTests/ColorTests.swift`：

```swift
import Testing
import SwiftUI
@testable import VoxlueDesign

@Test func paletteHasEightColors() {
    #expect(VoxlueColor.palette.count == 8)
}

@MainActor
@Test func paperBaseIsWarmCream() {
    // 纸基必须偏暖：红通道 > 蓝通道（不是冷蓝屏幕白）。
    let res = VoxlueColor.paper.resolve(in: .init())
    #expect(res.red > res.blue)
}

@MainActor
@Test func vermillionIsWarmAccent() {
    // 朱红必须偏暖：红通道明显高于蓝通道。
    let res = VoxlueColor.vermillion.resolve(in: .init())
    #expect(res.red - res.blue > 0.4)
}

@MainActor
@Test func inkIsDarkerThanGraphite() {
    let ink = VoxlueColor.ink.resolve(in: .init())
    let graphite = VoxlueColor.graphite.resolve(in: .init())
    #expect(ink.red < graphite.red)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter VoxlueDesignTests`
Expected: 编译失败，提示找不到 `Color(hex:)` / `VoxlueColor`

- [ ] **Step 3: 实现 Color(hex:) 工具**

创建 `VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueColor+Hex.swift`：

```swift
import SwiftUI

public extension Color {
    /// 用 0xRRGGBB 整数字面量构造颜色（sRGB）。
    /// 例：`Color(hex: 0xC4452D)`。
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
```

- [ ] **Step 4: 实现纸·墨·朱 八色调色板**

创建 `VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueColor.swift`：

```swift
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
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter VoxlueDesignTests`
Expected: `Test run with 8 tests passed`（1 冒烟 + 3 hex + 4 色）

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueColor.swift \
        VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueColor+Hex.swift \
        VoxlueKit/Tests/VoxlueDesignTests/HexTests.swift \
        VoxlueKit/Tests/VoxlueDesignTests/ColorTests.swift
git commit -m "feat(design): 新增纸·墨·朱 八色调色板与 Color(hex:) 工具"
```

---

## Task 3: 字体栈接入 —— 下载字体文件并声明为 SPM 资源 【前端】

四套开源字体（全在 Google Fonts，OFL 许可，可随 App 分发）。本步骤把字体文件放进包、声明为 `resources`，并写一个能定位资源 URL 的助手。字体注册逻辑在 Task 4。

> **重要：字体文件无法由本计划生成 —— 必须由工程师手动下载放置。** 步骤里给出确切下载来源与落地路径。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Fonts/Resources/`（6 个 `.ttf`/`.otf`，手动放置）
- Modify: `VoxlueKit/Package.swift`
- Create: `VoxlueKit/Sources/VoxlueDesign/Fonts/VoxlueFontFile.swift`

- [ ] **Step 1: 下载四套开源字体**

打开浏览器，从 Google Fonts 下载并解压，取出以下 6 个字重文件：

| 字体 | 用途 | Google Fonts 页 | 取出的文件 |
|---|---|---|---|
| Crimson Pro | display 标题（含斜体） | fonts.google.com/specimen/Crimson+Pro | `CrimsonPro-Regular.ttf`、`CrimsonPro-Italic.ttf` |
| Noto Serif SC | 中文思源宋 | fonts.google.com/noto/specimen/Noto+Serif+SC | `NotoSerifSC-Regular.otf`、`NotoSerifSC-SemiBold.otf` |
| Space Mono | 元数据等宽 | fonts.google.com/specimen/Space+Mono | `SpaceMono-Regular.ttf` |
| Caveat | 朱红手写批注 | fonts.google.com/specimen/Caveat | `Caveat-Regular.ttf` |

> Noto Serif SC 在 Google Fonts 下载包内字重文件名形如 `NotoSerifSC-Regular.otf`；若下载到的是可变字体（`NotoSerifSC[wght].otf`）或静态包文件名不同，**重命名**为上表第四列的精确名字。Crimson Pro 同理（可变字体须用 static 子目录里的静态字重，或重命名为 `CrimsonPro-Regular.ttf` / `CrimsonPro-Italic.ttf`）。

- [ ] **Step 2: 把字体文件放进包资源目录**

创建目录并把 6 个文件按精确文件名放入：

```bash
mkdir -p /Users/cornna/project/voxule/VoxlueKit/Sources/VoxlueDesign/Fonts/Resources
# 把下载好的 6 个字体文件复制进上面这个目录，文件名必须与 Step 1 表格第四列完全一致。
ls /Users/cornna/project/voxule/VoxlueKit/Sources/VoxlueDesign/Fonts/Resources
```

Expected: `ls` 列出恰好 6 个文件：`CrimsonPro-Italic.ttf`、`CrimsonPro-Regular.ttf`、`Caveat-Regular.ttf`、`NotoSerifSC-Regular.otf`、`NotoSerifSC-SemiBold.otf`、`SpaceMono-Regular.ttf`。

- [ ] **Step 3: 在 Package.swift 声明字体为 resources**

把 `VoxlueKit/Package.swift` 里 `VoxlueDesign` 目标一行替换为带 `resources` 的写法（用 `.copy` 把整个 `Fonts/Resources` 目录原样打进 resource bundle）：

```swift
        // VoxlueDesign 独立、不依赖 VoxlueData/VoxlueServices（路线图 §3.0）。
        .target(
            name: "VoxlueDesign",
            resources: [
                // 字体文件随包打成 resource bundle，首次使用时经 CoreText 注册。
                .copy("Fonts/Resources"),
            ]
        ),
```

- [ ] **Step 4: 写资源定位助手**

创建 `VoxlueKit/Sources/VoxlueDesign/Fonts/VoxlueFontFile.swift`：

```swift
import Foundation

/// VoxlueDesign 随包打包的字体文件清单。
/// 每一项对应 Sources/VoxlueDesign/Fonts/Resources 下的一个文件。
public enum VoxlueFontFile: String, CaseIterable, Sendable {
    case crimsonProRegular = "CrimsonPro-Regular"
    case crimsonProItalic  = "CrimsonPro-Italic"
    case notoSerifSCRegular  = "NotoSerifSC-Regular"
    case notoSerifSCSemiBold = "NotoSerifSC-SemiBold"
    case spaceMonoRegular = "SpaceMono-Regular"
    case caveatRegular    = "Caveat-Regular"

    /// 文件扩展名：思源宋是 OpenType（.otf），其余 TrueType（.ttf）。
    public var fileExtension: String {
        switch self {
        case .notoSerifSCRegular, .notoSerifSCSemiBold: "otf"
        default: "ttf"
        }
    }

    /// 该字体文件在 resource bundle 内的 URL；找不到返回 nil。
    public var url: URL? {
        Bundle.module.url(
            forResource: rawValue,
            withExtension: fileExtension,
            subdirectory: "Resources"
        )
    }
}
```

- [ ] **Step 5: 验证包仍可编译（资源已识别）**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift build --target VoxlueDesign`
Expected: 编译成功，无 `unhandled files` 警告（若有 `unhandled files` 警告说明 `.copy` 路径写错）。

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Package.swift VoxlueKit/Sources/VoxlueDesign/Fonts
git commit -m "feat(design): 引入四套开源字体并声明为 SPM 资源"
```

---

## Task 4: 字体注册 —— CTFontManager 首次使用注册 【前端】

包资源里的字体不会被系统自动加载，须在运行时用 `CTFontManagerRegisterFontsForURL` 注册。本步骤做注册器（幂等、只跑一次），并写测试验证注册成功后能拿到对应的 `PostScript` 字体名。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Fonts/VoxlueFontRegistrar.swift`
- Test: `VoxlueKit/Tests/VoxlueDesignTests/FontRegistrarTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDesignTests/FontRegistrarTests.swift`：

```swift
import Testing
import CoreText
@testable import VoxlueDesign

@Test func everyBundledFontFileResolvesToAURL() {
    for file in VoxlueFontFile.allCases {
        #expect(file.url != nil, "字体资源缺失：\(file.rawValue)")
    }
}

@Test func registerAllSucceeds() {
    // 注册不抛错、可重复调用（幂等）。
    VoxlueFontRegistrar.registerAll()
    VoxlueFontRegistrar.registerAll()
    #expect(VoxlueFontRegistrar.isRegistered)
}

@Test func registeredPostScriptNamesAreAvailable() {
    VoxlueFontRegistrar.registerAll()
    // 注册后，系统应能按 PostScript 名找到字体。
    let names = ["CrimsonPro-Regular", "NotoSerifSC-Regular", "SpaceMono-Regular", "Caveat-Regular"]
    for name in names {
        let descriptor = CTFontDescriptorCreateWithNameAndSize(name as CFString, 12)
        let resolved = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String
        #expect(resolved == name, "未注册成功：\(name)")
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter FontRegistrarTests`
Expected: 编译失败，提示找不到 `VoxlueFontRegistrar`

- [ ] **Step 3: 实现字体注册器**

创建 `VoxlueKit/Sources/VoxlueDesign/Fonts/VoxlueFontRegistrar.swift`：

```swift
import CoreText
import Foundation
import os

/// VoxlueDesign 字体注册器。
/// 包资源里的字体须在运行时经 CoreText 注册系统才认。
/// `registerAll()` 幂等 —— 多次调用只真正注册一次。
public enum VoxlueFontRegistrar {

    private static let lock = OSAllocatedUnfairLock(initialState: false)
    private static let log = Logger(subsystem: "VoxlueDesign", category: "fonts")

    /// 字体是否已注册。
    public static var isRegistered: Bool {
        lock.withLock { $0 }
    }

    /// 注册全部随包字体。幂等：重复调用安全、不重复注册。
    public static func registerAll() {
        lock.withLock { done in
            guard !done else { return }
            for file in VoxlueFontFile.allCases {
                register(file)
            }
            done = true
        }
    }

    private static func register(_ file: VoxlueFontFile) {
        guard let url = file.url else {
            log.error("字体资源缺失：\(file.rawValue, privacy: .public)")
            return
        }
        var errorRef: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef)
        if !ok {
            // 「已注册过」不算失败 —— 测试环境会重复加载进程。
            let code = (errorRef?.takeUnretainedValue() as Error?).map {
                ($0 as NSError).code
            }
            if code == CTFontManagerError.alreadyRegistered.rawValue {
                log.debug("字体已注册：\(file.rawValue, privacy: .public)")
            } else {
                log.error("字体注册失败：\(file.rawValue, privacy: .public)")
            }
        }
        errorRef?.release()
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter VoxlueDesignTests`
Expected: `Test run with 11 tests passed`（累计 8 + 3 字体注册）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Fonts/VoxlueFontRegistrar.swift \
        VoxlueKit/Tests/VoxlueDesignTests/FontRegistrarTests.swift
git commit -m "feat(design): 新增 CTFontManager 字体注册器"
```

---

## Task 5: 设计 tokens —— 字阶与 Font 助手 【前端】

字阶建在已注册的字体上。display 用 Crimson Pro 斜体，中文用思源宋，元数据用 Space Mono，批注用 Caveat。每个 `Font` 助手在被取用前确保字体已注册。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueTypography.swift`
- Test: `VoxlueKit/Tests/VoxlueDesignTests/TypographyTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDesignTests/TypographyTests.swift`：

```swift
import Testing
@testable import VoxlueDesign

@Test func typeScaleHasSixSteps() {
    #expect(VoxlueTypography.scale.count == 6)
}

@Test func typeScaleSizesAscend() {
    let sizes = VoxlueTypography.scale.map(\.size)
    #expect(sizes == sizes.sorted())
}

@Test func displaySizeIsThirtyFour() {
    #expect(VoxlueTypography.Step.display.size == 34)
}

@Test func metaSizeIsTwelve() {
    #expect(VoxlueTypography.Step.meta.size == 12)
}

@Test func touchingFontHelpersRegistersFonts() {
    // 取任意 Font 助手都应先确保字体注册完成。
    _ = VoxlueTypography.display
    _ = VoxlueTypography.serifBody
    _ = VoxlueTypography.meta
    _ = VoxlueTypography.annotation
    #expect(VoxlueFontRegistrar.isRegistered)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter TypographyTests`
Expected: 编译失败，提示找不到 `VoxlueTypography`

- [ ] **Step 3: 实现字阶与 Font 助手**

创建 `VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueTypography.swift`：

```swift
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
    public enum Step: CaseIterable {
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
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter VoxlueDesignTests`
Expected: `Test run with 16 tests passed`（累计 11 + 5 字阶）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueTypography.swift \
        VoxlueKit/Tests/VoxlueDesignTests/TypographyTests.swift
git commit -m "feat(design): 新增六级字阶与字体助手"
```

---

## Task 6: 设计 tokens —— 间距、圆角、暖色阴影 【前端】

间距走 4pt 基数；圆角小（暗房纸感不要圆润气泡感）；阴影是**暖色**（朝墨色偏，不用系统冷黑阴影），呼应「纸的温度」。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueSpacing.swift`
- Test: `VoxlueKit/Tests/VoxlueDesignTests/SpacingTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDesignTests/SpacingTests.swift`：

```swift
import Testing
import SwiftUI
@testable import VoxlueDesign

@Test func spacingFollowsFourPointGrid() {
    for value in VoxlueSpacing.allSteps {
        #expect(value.truncatingRemainder(dividingBy: 4) == 0, "\(value) 不在 4pt 网格")
    }
}

@Test func spacingStepsAscend() {
    let steps = VoxlueSpacing.allSteps
    #expect(steps == steps.sorted())
}

@Test func cornerRadiiAreSmall() {
    // 暗房纸感：圆角克制，不超过 16。
    #expect(VoxlueRadius.card <= 16)
    #expect(VoxlueRadius.photo <= 16)
}

@MainActor
@Test func paperShadowIsWarm() {
    // 暖色阴影：阴影色偏暖（红 > 蓝）。
    let res = VoxlueShadow.paper.color.resolve(in: .init())
    #expect(res.red >= res.blue)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter SpacingTests`
Expected: 编译失败，提示找不到 `VoxlueSpacing` / `VoxlueRadius` / `VoxlueShadow`

- [ ] **Step 3: 实现间距 / 圆角 / 阴影 token**

创建 `VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueSpacing.swift`：

```swift
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
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter VoxlueDesignTests`
Expected: `Test run with 20 tests passed`（累计 16 + 4 间距）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Tokens/VoxlueSpacing.swift \
        VoxlueKit/Tests/VoxlueDesignTests/SpacingTests.swift
git commit -m "feat(design): 新增间距、圆角与暖色阴影 token"
```

---

## Task 7: 暗房纸感控件 —— PaperCard 与 PhotoCard 【前端】

纸感控件第一组。`PaperCard` 是纸感容器基元（暖白底 + 暖阴影 + 小圆角），其余纸感控件都建在它上面。`PhotoCard` 是「相片」—— 一段声音被装裱后的样子，相纸边白 + 片基小字。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Paper/PaperCard.swift`
- Create: `VoxlueKit/Sources/VoxlueDesign/Paper/PhotoCard.swift`

- [ ] **Step 1: 实现 PaperCard**

创建 `VoxlueKit/Sources/VoxlueDesign/Paper/PaperCard.swift`：

```swift
import SwiftUI

/// 纸卡 —— 暗房纸感容器基元。
/// 内容层永远是纸：暖白底、暖色阴影、克制圆角。绝不用玻璃。
public struct PaperCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(VoxlueSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                    .fill(VoxlueColor.paperHighlight)
            )
            .overlay(
                // 一道极淡的纸阴描边，强化「纸切边」。
                RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                    .strokeBorder(VoxlueColor.paperShadow, lineWidth: 0.75)
            )
            .voxlueShadow(.paper)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        PaperCard {
            VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                Text("一张待显影的纸卡")
                    .font(VoxlueTypography.serifTitle)
                    .foregroundStyle(VoxlueColor.ink)
                Text("内容层永远是纸 —— 暖白底、暖色阴影。")
                    .font(VoxlueTypography.serifBody)
                    .foregroundStyle(VoxlueColor.graphite)
            }
        }
        .padding(VoxlueSpacing.xl)
    }
}
```

- [ ] **Step 2: 实现 PhotoCard**

创建 `VoxlueKit/Sources/VoxlueDesign/Paper/PhotoCard.swift`：

```swift
import SwiftUI

/// 相片 —— 一段声音被装裱后的样子。
/// 相纸边白（顶部图像区 + 底部片基白条），片基上印标题与元数据小字。
public struct PhotoCard<Image: View>: View {
    private let title: String
    private let meta: String
    private let image: Image

    /// - Parameters:
    ///   - title: 相片标题（思源宋）。
    ///   - meta: 片基小字 —— 坐标 / 时长 / 天气（Space Mono）。
    ///   - image: 图像区内容，通常是声纹波形视图。
    public init(
        title: String,
        meta: String,
        @ViewBuilder image: () -> Image
    ) {
        self.title = title
        self.meta = meta
        self.image = image()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 图像区 —— 深底，相纸里被显影的那块。
            image
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(VoxlueColor.negativeBlack)

            // 片基白条 —— 印标题与元数据。
            VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
                Text(title)
                    .font(VoxlueTypography.serifTitle)
                    .foregroundStyle(VoxlueColor.ink)
                    .lineLimit(1)
                Text(meta)
                    .font(VoxlueTypography.meta)
                    .foregroundStyle(VoxlueColor.darkroomGray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(VoxlueSpacing.md)
            .background(VoxlueColor.paperHighlight)
        }
        .clipShape(RoundedRectangle(cornerRadius: VoxlueRadius.photo, style: .continuous))
        .voxlueShadow(.photo)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        PhotoCard(
            title: "咖啡馆的雨",
            meta: "31.21, 121.43 · 0:48 · 阴"
        ) {
            // 占位声纹：等宽竖条。
            HStack(spacing: 3) {
                ForEach(0..<28, id: \.self) { i in
                    Capsule()
                        .fill(VoxlueColor.paper.opacity(0.85))
                        .frame(width: 3, height: CGFloat(12 + (i * 7) % 70))
                }
            }
        }
        .padding(VoxlueSpacing.xl)
    }
}
```

- [ ] **Step 3: 验证包可编译**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift build --target VoxlueDesign`
Expected: 编译成功。

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Paper/PaperCard.swift \
        VoxlueKit/Sources/VoxlueDesign/Paper/PhotoCard.swift
git commit -m "feat(design): 新增 PaperCard 与 PhotoCard 纸感控件"
```

---

## Task 8: 暗房纸感控件 —— NegativeCard、SealStamp、MarginNote 【前端】

纸感控件第二组：负片（埋下后、未显影的胶囊的样子，反相）、朱章（盖在相片上的状态印 —— buried/developed）、批注（朱红手写小字）。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Paper/NegativeCard.swift`
- Create: `VoxlueKit/Sources/VoxlueDesign/Paper/SealStamp.swift`
- Create: `VoxlueKit/Sources/VoxlueDesign/Paper/MarginNote.swift`

- [ ] **Step 1: 实现 NegativeCard**

创建 `VoxlueKit/Sources/VoxlueDesign/Paper/NegativeCard.swift`：

```swift
import SwiftUI

/// 负片 —— 一枚埋下后、尚未显影的胶囊的样子。
/// 反相：深底亮字，标题被「冲淡」。胶囊显影后会换成 PhotoCard。
public struct NegativeCard<Image: View>: View {
    private let title: String
    private let meta: String
    private let image: Image

    public init(
        title: String,
        meta: String,
        @ViewBuilder image: () -> Image
    ) {
        self.title = title
        self.meta = meta
        self.image = image()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            image
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .opacity(0.55)               // 未显影 —— 影像偏淡。

            Text(title)
                .font(VoxlueTypography.serifTitle)
                .foregroundStyle(VoxlueColor.paper)
                .lineLimit(1)
            Text(meta)
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.darkroomGray)
                .lineLimit(1)
        }
        .padding(VoxlueSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VoxlueRadius.photo, style: .continuous)
                .fill(VoxlueColor.negativeBlack)
        )
        .voxlueShadow(.photo)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        NegativeCard(title: "潜伏中的一段声", meta: "已埋下 · 等一个地点") {
            Rectangle().fill(VoxlueColor.graphite)
        }
        .padding(VoxlueSpacing.xl)
    }
}
```

- [ ] **Step 2: 实现 SealStamp**

创建 `VoxlueKit/Sources/VoxlueDesign/Paper/SealStamp.swift`：

```swift
import SwiftUI

/// 朱章 —— 盖在相片上的状态印。朱红、方、带一点旋转，像真盖上去的。
public struct SealStamp: View {

    /// 章的语义。
    public enum Kind: Sendable {
        case buried       // 已埋下
        case developing   // 显影中
        case developed    // 已显影
        case opened       // 已开启

        var text: String {
            switch self {
            case .buried:     "已埋下"
            case .developing: "显影中"
            case .developed:  "待你听"
            case .opened:     "已开启"
            }
        }
    }

    private let kind: Kind

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public var body: some View {
        Text(kind.text)
            .font(VoxlueTypography.meta)
            .tracking(2)
            .foregroundStyle(VoxlueColor.vermillion)
            .padding(.horizontal, VoxlueSpacing.sm)
            .padding(.vertical, VoxlueSpacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: VoxlueRadius.stamp, style: .continuous)
                    .strokeBorder(VoxlueColor.vermillion, lineWidth: 1.5)
            )
            .rotationEffect(.degrees(-8))     // 手盖的章不会正。
            .opacity(0.88)                    // 印泥透出底纹。
            .voxlueShadow(.stamp)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        HStack(spacing: VoxlueSpacing.lg) {
            SealStamp(.buried)
            SealStamp(.developing)
            SealStamp(.developed)
            SealStamp(.opened)
        }
    }
}
```

- [ ] **Step 3: 实现 MarginNote**

创建 `VoxlueKit/Sources/VoxlueDesign/Paper/MarginNote.swift`：

```swift
import SwiftUI

/// 批注 —— 写在相片边上的朱红手写小字。
/// 用 Caveat 手写体，朱红色，像冲洗师在样片边角随手记的一句。
public struct MarginNote: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .top, spacing: VoxlueSpacing.xs) {
            // 一道朱红短画，像批注的引出线。
            Rectangle()
                .fill(VoxlueColor.vermillion)
                .frame(width: 14, height: 1.5)
                .padding(.top, 12)
            Text(text)
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
        }
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        MarginNote("这一段，是奶奶哼的调子")
            .padding(VoxlueSpacing.xl)
    }
}
```

- [ ] **Step 4: 验证包可编译**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift build --target VoxlueDesign`
Expected: 编译成功。

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Paper/NegativeCard.swift \
        VoxlueKit/Sources/VoxlueDesign/Paper/SealStamp.swift \
        VoxlueKit/Sources/VoxlueDesign/Paper/MarginNote.swift
git commit -m "feat(design): 新增 NegativeCard、SealStamp、MarginNote 纸感控件"
```

---

## Task 9: 液态玻璃导航层 —— 暖色 tint 与 chrome wrapper 【前端】

iOS 26 原生 Liquid Glass。方案 B：玻璃只在 chrome。tint 偏纸奶油色（不用冷蓝科技玻璃）。本步骤做暖色 tint 常量、`GlassEffectContainer` 包装的标签栏 / sheet / 浮动控制 wrapper。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Glass/GlassTint.swift`
- Create: `VoxlueKit/Sources/VoxlueDesign/Glass/GlassChrome.swift`

- [ ] **Step 1: 实现暖色玻璃 tint**

创建 `VoxlueKit/Sources/VoxlueDesign/Glass/GlassTint.swift`：

```swift
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
```

- [ ] **Step 2: 实现 chrome wrapper**

创建 `VoxlueKit/Sources/VoxlueDesign/Glass/GlassChrome.swift`：

```swift
import SwiftUI

/// 浮动玻璃控制条 —— 漂在样片墙 / 地图之上的操作 chrome。
/// 例：浮动「冲一张」录音键、地图上的图层切换。
public struct GlassControlBar<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        // GlassEffectContainer 让同容器内多片玻璃融合、流动。
        GlassEffectContainer(spacing: VoxlueSpacing.md) {
            HStack(spacing: VoxlueSpacing.md) {
                content
            }
            .padding(.horizontal, VoxlueSpacing.lg)
            .padding(.vertical, VoxlueSpacing.md)
        }
        .voxlueGlass(tint: GlassTint.cream)
    }
}

/// 玻璃浮动主按钮 —— 「冲一张」录音入口。暖朱玻璃、可交互。
public struct GlassFloatingButton: View {
    private let systemImage: String
    private let action: () -> Void

    public init(systemImage: String = "mic.fill", action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(VoxlueColor.vermillion)
                .frame(width: 60, height: 60)
        }
        .voxlueGlass(tint: GlassTint.vermillionWash, interactive: true)
        .clipShape(Circle())
    }
}

/// sheet 的玻璃顶把手区。把 sheet 内容包成「玻璃 chrome + 纸内容」。
public struct GlassSheetChrome<Content: View>: View {
    private let title: String
    private let content: Content

    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 玻璃标题条 —— chrome。
            Text(title)
                .font(VoxlueTypography.serifTitle)
                .foregroundStyle(VoxlueColor.ink)
                .frame(maxWidth: .infinity)
                .padding(VoxlueSpacing.lg)
                .voxlueGlass(tint: GlassTint.cream)
            // 纸内容区 —— content。
            content
                .frame(maxWidth: .infinity)
                .background(VoxlueColor.paper)
        }
    }
}

#Preview("浮动玻璃") {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        VStack(spacing: VoxlueSpacing.xl) {
            GlassControlBar {
                Image(systemName: "square.grid.2x2").foregroundStyle(VoxlueColor.ink)
                Image(systemName: "map").foregroundStyle(VoxlueColor.ink)
                Image(systemName: "person.2").foregroundStyle(VoxlueColor.ink)
            }
            GlassFloatingButton {}
        }
    }
}
```

- [ ] **Step 3: 验证包可编译（含 iOS 26 玻璃 API）**

`glassEffect` / `GlassEffectContainer` 是 iOS 平台 API，`swift build` 默认编 macOS 可能不识别。用 App 工程的模拟器构建验证（见 Task 12 会做全量验证；此处先单独确认本目标在 iOS SDK 下可编）：

Run: `cd /Users/cornna/project/voxule && xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`（注：Task 12 才把 VoxlueDesign 链入 App；若此处 App 尚未链入该包，命令仍应成功，只是不覆盖玻璃文件 —— 玻璃文件的真正验证在 Task 12。可先跳过本步骤的链接验证，仅确认现有 App 不被破坏。）

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Glass/GlassTint.swift \
        VoxlueKit/Sources/VoxlueDesign/Glass/GlassChrome.swift
git commit -m "feat(design): 新增液态玻璃导航层（暖色 tint 与 chrome wrapper）"
```

---

## Task 10: 液态玻璃 —— 灵动岛显影标签 【前端】

灵动岛上的「显影中」玻璃标签 —— 胶囊 buried→developing 时灵动岛轻轻提醒「这里有一张你洗过一次的相」。这是玻璃 chrome 与显影状态的触点。本步骤做可复用的标签视图（ActivityKit Live Activity 的实际接线在计划 03）。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Glass/DevelopingIslandLabel.swift`

- [ ] **Step 1: 实现灵动岛显影标签**

创建 `VoxlueKit/Sources/VoxlueDesign/Glass/DevelopingIslandLabel.swift`：

```swift
import SwiftUI

/// 灵动岛 / 通知里的「显影中」玻璃标签。
/// 一枚胶囊进入 developing 时显示，呼应「这里有一张你洗过一次的相」。
/// 实际 Live Activity 接线在计划 03；此处只产出可复用的视觉。
public struct DevelopingIslandLabel: View {

    /// 紧凑（灵动岛 compact）或展开（expanded / 通知）两种形态。
    public enum Layout: Sendable { case compact, expanded }

    private let capsuleTitle: String
    private let layout: Layout

    public init(capsuleTitle: String, layout: Layout = .compact) {
        self.capsuleTitle = capsuleTitle
        self.layout = layout
    }

    public var body: some View {
        HStack(spacing: VoxlueSpacing.sm) {
            // 朱红显影点 —— 安全灯。
            Circle()
                .fill(VoxlueColor.vermillion)
                .frame(width: 8, height: 8)

            if layout == .expanded {
                VStack(alignment: .leading, spacing: 1) {
                    Text("显影中")
                        .font(VoxlueTypography.meta)
                        .foregroundStyle(VoxlueColor.darkroomGray)
                    Text(capsuleTitle)
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.paper)
                        .lineLimit(1)
                }
            } else {
                Text("显影中")
                    .font(VoxlueTypography.meta)
                    .foregroundStyle(VoxlueColor.paper)
            }
        }
        .padding(.horizontal, VoxlueSpacing.md)
        .padding(.vertical, VoxlueSpacing.sm)
        .voxlueGlass(tint: GlassTint.vermillionWash)
    }
}

#Preview {
    ZStack {
        VoxlueColor.negativeBlack.ignoresSafeArea()
        VStack(spacing: VoxlueSpacing.xl) {
            DevelopingIslandLabel(capsuleTitle: "咖啡馆的雨", layout: .compact)
            DevelopingIslandLabel(capsuleTitle: "咖啡馆的雨", layout: .expanded)
        }
    }
}
```

- [ ] **Step 2: 验证包可编译**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift build --target VoxlueDesign 2>&1 | tail -3`
Expected: 编译成功（玻璃 API 在 macOS SDK 下若报错，以 Task 12 的 iOS 模拟器构建为准）。

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Glass/DevelopingIslandLabel.swift
git commit -m "feat(design): 新增灵动岛显影玻璃标签"
```

---

## Task 11: 显影动效 —— 「霜化开」转场 【前端】

招牌动效。胶囊 buried→developing 时播放：负片从一层「霜」里慢慢化开、显出影像 —— 像相纸在显影液里浮现。这是 UI 与领域状态机的接缝，做成可复用的 SwiftUI `Transition` + 修饰器。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Motion/DevelopTransition.swift`

- [ ] **Step 1: 实现「霜化开」转场**

创建 `VoxlueKit/Sources/VoxlueDesign/Motion/DevelopTransition.swift`：

```swift
import SwiftUI

/// 「霜化开」显影转场 —— voxlue 的招牌动效。
/// 胶囊 buried → developing 时播放：影像从一层「霜」里慢慢化开。
/// 实现：模糊 + 去饱和 + 微缩放，三者随显影同步退去。
public struct DevelopTransition: Transition {

    public init() {}

    public func body(content: Content, phase: TransitionPhase) -> some View {
        let developing = phase.isIdentity   // 完成态 = 已显影。
        return content
            .blur(radius: developing ? 0 : 18)                 // 霜 —— 模糊散去。
            .saturation(developing ? 1 : 0)                     // 黑白 → 显出影调。
            .scaleEffect(developing ? 1 : 1.04)                 // 极轻的「浮现」缩放。
            .opacity(developing ? 1 : 0)
    }
}

public extension Transition where Self == DevelopTransition {
    /// `.transition(.develop)` —— 霜化开显影转场。
    static var develop: DevelopTransition { DevelopTransition() }
}

/// 显影动画的标准时长与曲线 —— 全 App 统一用这一条，保证「显影」节奏一致。
public enum DevelopAnimation {
    /// 显影主动画：缓入缓出，1.1 秒 —— 慢得能被「看见在变」。
    public static let curve: Animation = .easeInOut(duration: 1.1)
}

/// 把一个布尔「是否已显影」绑到霜化开转场上的便捷修饰器。
public struct FrostReveal: ViewModifier {
    private let developed: Bool

    public init(developed: Bool) {
        self.developed = developed
    }

    public func body(content: Content) -> some View {
        content
            .blur(radius: developed ? 0 : 18)
            .saturation(developed ? 1 : 0)
            .scaleEffect(developed ? 1 : 1.04)
            .animation(DevelopAnimation.curve, value: developed)
    }
}

public extension View {
    /// 把视图随 `developed` 翻转播放「霜化开」 —— 用于原地显影（非插入/移除）。
    func frostReveal(developed: Bool) -> some View {
        modifier(FrostReveal(developed: developed))
    }
}

#Preview("霜化开") {
    struct Demo: View {
        @State private var developed = false
        var body: some View {
            ZStack {
                VoxlueColor.negativeBlack.ignoresSafeArea()
                VStack(spacing: VoxlueSpacing.xl) {
                    PhotoCard(title: "咖啡馆的雨", meta: "0:48 · 阴") {
                        Rectangle().fill(VoxlueColor.graphite)
                    }
                    .frostReveal(developed: developed)
                    .frame(width: 260)

                    Button("显影") {
                        withAnimation(DevelopAnimation.curve) { developed.toggle() }
                    }
                    .font(VoxlueTypography.meta)
                    .foregroundStyle(VoxlueColor.paper)
                }
            }
        }
    }
    return Demo()
}
```

- [ ] **Step 2: 验证包可编译**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift build --target VoxlueDesign 2>&1 | tail -3`
Expected: 编译成功。

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Motion/DevelopTransition.swift
git commit -m "feat(design): 新增『霜化开』显影转场动效"
```

---

## Task 12: 设计图鉴 catalog 视图 + App 端可视化验证 【前端】

把设计系统全部内容铺进一个可滚动的图鉴视图，再把它挂进 App，在 iPhone 17 模拟器跑起来截图 —— 设计系统从此可视、可验。同时把 `VoxlueDesign` 链入 App 工程。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueDesign/Catalog/DesignCatalogView.swift`
- Modify: `voxule/voxule/voxule.xcodeproj/project.pbxproj`（链入 VoxlueDesign）
- Modify: `voxule/voxule/voxule/DebugRootView.swift`

- [ ] **Step 1: 实现图鉴视图**

创建 `VoxlueKit/Sources/VoxlueDesign/Catalog/DesignCatalogView.swift`：

```swift
import SwiftUI

/// 设计系统图鉴 —— 把 VoxlueDesign 全部内容铺成一页，肉眼可验。
public struct DesignCatalogView: View {

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VoxlueSpacing.xxl) {
                header
                colorSection
                typographySection
                paperSection
                glassSection
                motionSection
            }
            .padding(VoxlueSpacing.xl)
        }
        .background(VoxlueColor.paper.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
            Text("voxlue")
                .font(VoxlueTypography.display)
                .foregroundStyle(VoxlueColor.ink)
            Text("设计系统图鉴 · v\(VoxlueDesign.version) · P3 Photographic Plate")
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.graphite)
        }
    }

    @ViewBuilder private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(VoxlueTypography.heading)
            .foregroundStyle(VoxlueColor.ink)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("纸 · 墨 · 朱 八色")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                      spacing: VoxlueSpacing.md) {
                ForEach(Array(VoxlueColor.palette.enumerated()), id: \.offset) { idx, color in
                    VStack(spacing: VoxlueSpacing.xs) {
                        RoundedRectangle(cornerRadius: VoxlueRadius.photo)
                            .fill(color)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: VoxlueRadius.photo)
                                    .strokeBorder(VoxlueColor.paperShadow, lineWidth: 0.5)
                            )
                        Text(VoxlueColor.paletteNames[idx])
                            .font(VoxlueTypography.meta)
                            .foregroundStyle(VoxlueColor.graphite)
                    }
                }
            }
        }
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("字阶与字体栈")
            Group {
                Text("voxlue · develop").font(VoxlueTypography.display)
                Text("一段待显影的声音").font(VoxlueTypography.serifTitle)
                Text("内容层永远是纸，不是屏幕的反光。").font(VoxlueTypography.serifBody)
                Text("31.21, 121.43 · 0:48").font(VoxlueTypography.meta)
            }
            .foregroundStyle(VoxlueColor.ink)
            MarginNote("Caveat 手写批注 —— 朱红色")
        }
    }

    private var paperSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("暗房纸感控件")
            PhotoCard(title: "咖啡馆的雨", meta: "31.21, 121.43 · 0:48 · 阴") {
                waveform
            }
            NegativeCard(title: "潜伏中的一段声", meta: "已埋下 · 等一个地点") {
                Rectangle().fill(VoxlueColor.graphite)
            }
            PaperCard {
                Text("PaperCard —— 纸感容器基元")
                    .font(VoxlueTypography.serifBody)
                    .foregroundStyle(VoxlueColor.ink)
            }
            HStack(spacing: VoxlueSpacing.md) {
                SealStamp(.buried)
                SealStamp(.developing)
                SealStamp(.developed)
                SealStamp(.opened)
            }
        }
    }

    private var glassSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("液态玻璃导航层")
            // 玻璃需衬深底才看得出折射 —— 用负片黑做背板。
            ZStack {
                RoundedRectangle(cornerRadius: VoxlueRadius.card)
                    .fill(VoxlueColor.negativeBlack)
                    .frame(height: 160)
                VStack(spacing: VoxlueSpacing.lg) {
                    GlassControlBar {
                        Image(systemName: "square.grid.2x2").foregroundStyle(VoxlueColor.paper)
                        Image(systemName: "map").foregroundStyle(VoxlueColor.paper)
                        Image(systemName: "person.2").foregroundStyle(VoxlueColor.paper)
                    }
                    DevelopingIslandLabel(capsuleTitle: "咖啡馆的雨", layout: .expanded)
                }
            }
        }
    }

    private var motionSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("『霜化开』显影动效")
            DevelopRevealDemo()
        }
    }

    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<28, id: \.self) { i in
                Capsule()
                    .fill(VoxlueColor.paper.opacity(0.85))
                    .frame(width: 3, height: CGFloat(12 + (i * 7) % 70))
            }
        }
    }
}

/// 图鉴内的显影动效互动小样。
private struct DevelopRevealDemo: View {
    @State private var developed = false

    var body: some View {
        VStack(spacing: VoxlueSpacing.md) {
            PhotoCard(title: "咖啡馆的雨", meta: "0:48 · 阴") {
                HStack(spacing: 3) {
                    ForEach(0..<28, id: \.self) { i in
                        Capsule()
                            .fill(VoxlueColor.paper.opacity(0.85))
                            .frame(width: 3, height: CGFloat(12 + (i * 7) % 70))
                    }
                }
            }
            .frostReveal(developed: developed)

            Button(developed ? "重新埋下" : "显影这一张") {
                withAnimation(DevelopAnimation.curve) { developed.toggle() }
            }
            .font(VoxlueTypography.meta)
            .foregroundStyle(VoxlueColor.vermillion)
        }
    }
}

#Preview {
    DesignCatalogView()
}
```

- [ ] **Step 2: 把 VoxlueDesign 链入 App 工程**

计划 01 已手改 `project.pbxproj` 接入 `VoxlueData`（见其修订记录）。照同样方式新增 `VoxlueDesign`。在 `voxule/voxule/voxule.xcodeproj/project.pbxproj` 里：

1. `PBXBuildFile` 段，仿 `VoxlueData in Frameworks` 那一行，新增一行 `VoxlueDesign in Frameworks`，分配一个新 UUID（如 `D1A0000000000000000000B3`），`productRef` 指向新的 `XCSwiftPackageProductDependency`（如 `D1A0000000000000000000B2`）。
2. App 目标的 `Frameworks` 构建阶段 `files` 列表里加入该 `PBXBuildFile` 引用。
3. `XCSwiftPackageProductDependency` 段新增一项 `D1A0000000000000000000B2`，`productName = VoxlueDesign`。
4. App 目标的 `packageProductDependencies` 列表里加入 `D1A0000000000000000000B2`。

（`XCLocalSwiftPackageReference` 已有 `../VoxlueKit`，无需重复加。）

- [ ] **Step 3: 在 DebugRootView 挂图鉴入口**

把 `voxule/voxule/voxule/DebugRootView.swift` 全文替换为（保留原数据层调试，新增一个跳到图鉴的 toolbar 入口）：

```swift
//
//  DebugRootView.swift
//  voxule
//
//  临时调试视图。计划 02 替换为样片墙。
//

import SwiftUI
import SwiftData
import VoxlueData
import VoxlueDesign

// 数据模型 `Capsule` 与 SwiftUI 内置形状 `SwiftUI.Capsule` 同名，
// 在同时 import SwiftUI 与 VoxlueData 的文件里须写全 `VoxlueData.Capsule` 消歧义。
struct DebugRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    var body: some View {
        NavigationStack {
            List(capsules) { capsule in
                VStack(alignment: .leading) {
                    Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                    Text(capsule.state.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("胶囊：\(capsules.count)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("设计图鉴") {
                        DesignCatalogView()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("加一枚样本") {
                        let store = CapsuleStore(context: context)
                        try? store.add(VoxlueData.Capsule(title: "样本 \(capsules.count + 1)"))
                    }
                }
            }
        }
    }
}

#Preview {
    DebugRootView()
        .modelContainer(for: VoxlueData.Capsule.self, inMemory: true)
}
```

- [ ] **Step 4: 全量构建 App（含 VoxlueDesign 的玻璃 API）**

Run: `cd /Users/cornna/project/voxule && xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 模拟器跑起来并截图验证**

启动模拟器、装 App、起 App，导航到图鉴并截图：

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator
cd /Users/cornna/project/voxule
APP=$(xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' -showBuildSettings CODE_SIGNING_ALLOWED=NO 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{d=$2}/ FULL_PRODUCT_NAME /{n=$2}END{print d"/"n}')
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.voxlue.app
```

然后在模拟器里点左上「设计图鉴」进入图鉴页，滚动浏览，确认：八色色板渲染、四套字体生效（标题斜体衬线、中文宋体、Space Mono 数字、Caveat 手写）、PhotoCard/NegativeCard/朱章成纸感、玻璃条在负片黑背板上有折射、点「显影这一张」能看到霜化开。截图存档：

```bash
xcrun simctl io booted screenshot /Users/cornna/project/voxule/docs/superpowers/plans/.catalog-04.png
```

Expected: 截图文件生成；图鉴页各 section 正常渲染。若中文/手写体显示成系统默认字体，回查 Task 3 字体文件名与 Task 4 注册器。

> `.catalog-04.png` 仅作验证留痕，不入库（`.gitignore` 已忽略 `.superpowers/`；该截图路径在 plans 目录下，提交时勿 `git add` 它）。

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueDesign/Catalog/DesignCatalogView.swift \
        voxule/voxule/voxule.xcodeproj/project.pbxproj \
        voxule/voxule/voxule/DebugRootView.swift
git commit -m "feat(design): 新增设计图鉴 catalog 并接入 App 端可视化验证"
```

---

## Task 13: 全量回归与计划收尾 【前端】

跑全部测试、全量构建，确认设计系统稳定可交付下游计划。

**Files:** 无新增。

- [ ] **Step 1: 跑 VoxlueKit 全部测试**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 全绿。`VoxlueDesignTests` 应为 **20 个测试通过**（1 冒烟 + 3 hex + 4 色 + 3 字体注册 + 5 字阶 + 4 间距）；`VoxlueDataTests` 计划 01 的 19 个仍全绿；总计 **39 个测试通过**。

- [ ] **Step 2: 全量构建 App**

Run: `cd /Users/cornna/project/voxule && xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 确认无遗留改动**

Run: `cd /Users/cornna/project/voxule && git status --short`
Expected: 工作区干净（无未提交改动；`.catalog-04.png` 若存在不应被 `git add`）。

- [ ] **Step 4: 计划完成**

`VoxlueDesign` 已就绪：tokens、字体、纸感控件、玻璃导航、显影动效、图鉴。前端轨即可进入计划 02 的 UI 任务，所有视图直接 `import VoxlueDesign` 取用本计划的控件与 tokens。

---

## 完成标准

- `swift test --package-path VoxlueKit` 全绿 —— `VoxlueDesignTests` 20 个 + `VoxlueDataTests` 19 个，共 39 个测试通过。
- `VoxlueDesign` 是 `VoxlueKit` 的第三个 library 目标，独立、不依赖 `VoxlueData` / `VoxlueServices`。
- 八色调色板 hex 值精确（纸基暖白、墨灰四阶、朱红强调），`Color(hex:)` 通道值正确。
- 四套开源字体（Crimson Pro、Noto Serif SC、Space Mono、Caveat）以 SPM 资源打包，经 `CTFontManagerRegisterFontsForURL` 注册成功。
- 五个暗房纸感控件（PaperCard、PhotoCard、NegativeCard、SealStamp、MarginNote）齐备，内容层全为纸。
- 液态玻璃导航层（暖色 tint、GlassControlBar、GlassFloatingButton、GlassSheetChrome、DevelopingIslandLabel）用 iOS 26 原生 `glassEffect` / `GlassEffectContainer`，玻璃只在 chrome。
- 「霜化开」显影转场（`DevelopTransition` / `.frostReveal`）可复用，时长曲线统一。
- `DesignCatalogView` 图鉴在 iPhone 17 模拟器渲染正常，已截图存档验证。
- App 全量构建 `** BUILD SUCCEEDED **`，`VoxlueDesign` 已链入工程。
- 全部改动已提交 git，每个 Task 一个提交。

下一份计划：**计划 02 · 录音→装裱→回放主循环**（前端轨在此首次用上 `VoxlueDesign`）。
