import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 端侧 Foundation Models（自动标题/标签、离线兜底）。
public protocol IntelligenceServicing: Sendable {
    /// 据一段转写提示词代写一个标题；模型不可用时返回 nil（离线兜底）。
    func draftTitle(forTranscriptHint hint: String) async -> String?
}

/// 假实现 —— 返回脚本化标题，供预览与单元测试。
public struct FakeIntelligenceServicing: IntelligenceServicing {
    private let scripted: String?

    public init(title: String?) {
        self.scripted = title
    }

    public func draftTitle(forTranscriptHint hint: String) async -> String? { scripted }
}

/// 真实现 —— 端侧 Foundation Models。完全在设备内，不联网。
public struct IntelligenceService: IntelligenceServicing {
    public init() {}

    public func draftTitle(forTranscriptHint hint: String) async -> String? {
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.availability == .available else { return nil }   // 离线兜底
        do {
            let session = LanguageModelSession(
                instructions: """
                你是一位旧派的相片冲洗师。根据用户给的几个关键词，\
                为一段声音胶囊起一个安静、含蓄、不超过 10 个字的中文标题。\
                只输出标题本身，不要标点、不要解释。\
                始终用陪伴语气，不用任何临床或医疗措辞。
                """
            )
            let response = try await session.respond(to: "关键词：\(trimmed)")
            let title = response.content.trimmingCharacters(
                in: CharacterSet(charactersIn: " \n\t“”\"。.")
            )
            return title.isEmpty ? nil : String(title.prefix(20))
        } catch {
            return nil   // 任何失败都走离线兜底
        }
        #else
        return nil
        #endif
    }
}
