import Foundation
import VoxlueData

/// 云端 agent 网关真实现 —— 设备内执行段（架构文档 §7 ③）。
///
/// 闭环：`SignalDistiller` 脱敏 → `RemoteModelClient` 起会话 → 循环接 agent
/// 工具调用、派发给本地服务、回传结果 → agent `finished` → 返回 `SurfacingDecision`。
/// v1 闭环聚焦情绪浮现 —— `runSurfacingCycle()` 跑通即满足 MVP（架构文档 §11）。
@MainActor
public final class AgentGateway: AgentGatewaying {
    private let distiller: SignalDistilling
    private let client: RemoteModelClient
    private let trigger: TriggerEngineProtocol
    private let store: CapsuleStore
    /// 闭环最多轮数 —— 防 agent 脚本异常时无限循环。
    private let maxTurns: Int

    public init(
        distiller: SignalDistilling,
        client: RemoteModelClient,
        trigger: TriggerEngineProtocol,
        store: CapsuleStore,
        maxTurns: Int = 8
    ) {
        self.distiller = distiller
        self.client = client
        self.trigger = trigger
        self.store = store
        self.maxTurns = maxTurns
    }

    public func runSurfacingCycle() async throws -> SurfacingDecision {
        // ① 设备内脱敏 —— 原始健康数据到此为止，下面只传 digest。
        let digest = await distiller.distill()
        let context = buildContext()

        // ② 起会话。
        var reply = try await client.startSurfacing(digest: digest, context: context)

        // ③ 循环派发工具调用，直到 agent finished 或触顶。
        var turns = 0
        while !reply.finished && turns < maxTurns {
            var results: [ToolResult] = []
            for call in reply.toolCalls {
                results.append(await dispatch(call))
            }
            reply = try await client.continueTurn(
                AgentTurn(toolResults: results, finished: false)
            )
            turns += 1
        }

        // ④ 触顶仍未结束 —— 止损，按 hold 处理。
        guard reply.finished else { return .hold }

        if let idString = reply.surfaceCapsuleID, let id = UUID(uuidString: idString) {
            return .surface(capsuleID: id)
        }
        return .hold
    }

    // MARK: - 非敏感上下文

    /// 只收集胶囊库元数据与粗地名 —— 不含音频、不含体征、不含精确坐标。
    private func buildContext() -> AgentContext {
        let all = (try? store.allCapsules()) ?? []
        let candidates = all
            .filter { $0.lock.kind == .mood && $0.state == .buried }
            .map { capsule in
                AgentContext.CapsuleMeta(
                    id: capsule.id.uuidString,
                    title: capsule.title,
                    tags: capsule.tags,
                    placeName: capsule.placeName
                )
            }
        return AgentContext(candidates: candidates, cadence: "occasionally")
    }

    // MARK: - 工具派发

    /// 把一次工具调用派发给对应本地服务，回传 ToolResult。
    private func dispatch(_ call: AgentToolCall) async -> ToolResult {
        switch call.name {
        case .surfaceCapsule:
            guard let idString = call.arguments["capsuleID"],
                  let id = UUID(uuidString: idString) else {
                return ToolResult(name: .surfaceCapsule, output: #"{"ok":false}"#)
            }
            await trigger.surface(capsuleID: id)
            return ToolResult(name: .surfaceCapsule, output: #"{"ok":true}"#)

        case .searchCapsules:
            let query = (call.arguments["query"] ?? "").lowercased()
            let all = (try? store.allCapsules()) ?? []
            let hits = all.filter { capsule in
                query.isEmpty
                    || capsule.title.lowercased().contains(query)
                    || capsule.tags.contains { $0.lowercased().contains(query) }
            }
            let ids = hits.map { $0.id.uuidString }
            let json = (try? JSONEncoder().encode(ids)).flatMap { String(data: $0, encoding: .utf8) }
            return ToolResult(name: .searchCapsules, output: json ?? "[]")

        case .adjustCadence:
            // v1：网关不持久化 cadence（cadence 由设置 UI 写入 UserDefaults）。
            // 此处回执即可，真正写入在 CadenceSettingsView。
            return ToolResult(name: .adjustCadence,
                              output: #"{"ok":true,"note":"cadence handled by settings"}"#)

        case .draftTitle, .composeStory:
            // v1 加分项工具 —— 闭环可派发但不强求实现，先回空。
            return ToolResult(name: call.name, output: #"{"ok":true}"#)
        }
    }
}
