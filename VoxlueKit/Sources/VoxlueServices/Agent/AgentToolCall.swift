import Foundation

/// agent 工具集（MCP 式，架构文档 §7）。v1 闭环只必跑 surfaceCapsule，
/// 其余工具同样可派发，闭环跑通即可、不追工具集满。
public enum AgentToolName: String, Sendable, Codable {
    case surfaceCapsule    // 让某枚情绪胶囊显影
    case searchCapsules    // 按条件查胶囊（自然语言回顾）
    case composeStory      // 家人故事集（v1 加分）
    case draftTitle        // 代写标题（v1 加分）
    case adjustCadence     // 调浮现频率
}

/// agent 回的一次工具调用。`arguments` 用扁平字符串字典，跨网络稳。
public struct AgentToolCall: Sendable, Codable {
    public let name: AgentToolName
    public let arguments: [String: String]

    public init(name: AgentToolName, arguments: [String: String]) {
        self.name = name
        self.arguments = arguments
    }
}

/// 设备执行完一个工具后回传 agent 的结果。
public struct ToolResult: Sendable, Codable {
    public let name: AgentToolName
    public let output: String   // JSON 或纯文本，由工具语义定

    public init(name: AgentToolName, output: String) {
        self.name = name
        self.output = output
    }
}

/// agent 一轮的回复：要么给出待执行的工具调用，要么给出最终决定。
public struct AgentReply: Sendable, Codable {
    /// 本轮 agent 要设备执行的工具调用（可为空）。
    public let toolCalls: [AgentToolCall]
    /// agent 是否已结束推理；true 时 toolCalls 应为空。
    public let finished: Bool
    /// agent 结束时的最终决定（finished 时有意义）。可为 nil。
    public let surfaceCapsuleID: String?

    public init(toolCalls: [AgentToolCall], finished: Bool, surfaceCapsuleID: String? = nil) {
        self.toolCalls = toolCalls
        self.finished = finished
        self.surfaceCapsuleID = surfaceCapsuleID
    }
}

/// 设备发给 agent 的一轮输入：上一轮的工具结果 + 是否还要继续。
public struct AgentTurn: Sendable, Codable {
    public let toolResults: [ToolResult]
    public let finished: Bool

    public init(toolResults: [ToolResult], finished: Bool) {
        self.toolResults = toolResults
        self.finished = finished
    }
}
