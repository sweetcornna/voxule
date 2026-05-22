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
