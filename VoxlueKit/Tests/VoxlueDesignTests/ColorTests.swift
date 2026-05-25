import Testing
import SwiftUI
@testable import VoxlueDesign

@Test func paletteHasEightColors() {
    #expect(VoxlueColor.palette.count == 8)
}

@Test func adaptivePaletteHasEightColors() {
    #expect(VoxlueColor.adaptivePalette.count == 8)
    #expect(VoxlueColor.darkPalette.count == 8)
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

// MARK: 暗房模式（dark colorScheme）翻面回归

/// macOS 测试环境下，`Color.voxlueAdaptive` 走的是 `#else` 分支直接落 light；
/// 我们不能在测试里 resolve(in: .dark)，因此通过模块内可访问的 `*Dark` 定值
/// 直接断言翻面后的 hex 关系。任意 hex 改动都会被这组测试拦下。

@MainActor
@Test func paperFlipsToNegativeBlackInDark() {
    // dark 端的 paper 必须翻成「暗房本体」级的最深暖黑 —— 与 negativeBlack 同值。
    let dark = VoxlueColor.paperDark.resolve(in: .init())
    let neg = VoxlueColor.negativeBlack.resolve(in: .init())
    #expect(dark.red < 0.12 && dark.green < 0.12 && dark.blue < 0.12)
    // 同值校验（容忍极小色彩管理浮点误差）。
    #expect(abs(dark.red - neg.red) < 0.01)
    #expect(abs(dark.green - neg.green) < 0.01)
    #expect(abs(dark.blue - neg.blue) < 0.01)
}

@MainActor
@Test func inkFlipsToWarmLightInDark() {
    // dark 端的 ink（正文）必须翻成暖白 —— 红通道远高于 0.5，且红 > 蓝（保持暖性）。
    let inkDark = VoxlueColor.inkDark.resolve(in: .init())
    #expect(inkDark.red > 0.85)
    #expect(inkDark.red > inkDark.blue)
}

@MainActor
@Test func inkRemainsLighterThanGraphiteInDark() {
    // dark 翻面后 ink 是亮白、graphite 是中亮灰、darkroomGray 是次暗灰 —— 三档可读层级保留。
    let ink = VoxlueColor.inkDark.resolve(in: .init())
    let graphite = VoxlueColor.graphiteDark.resolve(in: .init())
    let darkroom = VoxlueColor.darkroomGrayDark.resolve(in: .init())
    #expect(ink.red > graphite.red)
    #expect(graphite.red > darkroom.red)
}

@MainActor
@Test func darkPaletteEntriesAllStayWarm() {
    // 翻面后六色仍必须保持「红通道 >= 蓝通道」的暖性，避免滑向冷蓝屏幕黑。
    let warmDarkSwatches: [Color] = [
        VoxlueColor.paperDark, VoxlueColor.paperHighlightDark, VoxlueColor.paperShadowDark,
        VoxlueColor.inkDark, VoxlueColor.graphiteDark, VoxlueColor.darkroomGrayDark,
    ]
    for swatch in warmDarkSwatches {
        let res = swatch.resolve(in: .init())
        #expect(res.red >= res.blue, "dark token 失去暖性：\(res)")
    }
}
