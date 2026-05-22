import Testing
import Foundation
@testable import VoxlueServices

@Test func fakeIntelligenceReturnsScriptedTitle() async {
    let service = FakeIntelligenceServicing(title: "窗外的雨声")
    let title = await service.draftTitle(forTranscriptHint: "雨 屋檐 安静")
    #expect(title == "窗外的雨声")
}

@Test func fakeIntelligenceOfflineFallbackReturnsNil() async {
    let service = FakeIntelligenceServicing(title: nil)
    let title = await service.draftTitle(forTranscriptHint: "任意提示")
    #expect(title == nil)
}

@Test func intelligenceServiceHandlesEmptyHintGracefully() async {
    // 真实现：空提示不应崩溃，返回 nil 或非空字符串均可。
    let service = IntelligenceService()
    let title = await service.draftTitle(forTranscriptHint: "")
    if let title { #expect(!title.isEmpty) }
}
