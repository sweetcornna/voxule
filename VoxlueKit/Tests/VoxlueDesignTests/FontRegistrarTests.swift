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
