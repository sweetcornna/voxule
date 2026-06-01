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
    /// 当前浮现频率档（用户 cadence 设置）—— 随上下文上行供 agent 权衡。
    private let cadence: String
    /// 闭环最多轮数 —— 防 agent 脚本异常时无限循环。
    private let maxTurns: Int

    public init(
        distiller: SignalDistilling,
        client: RemoteModelClient,
        trigger: TriggerEngineProtocol,
        store: CapsuleStore,
        cadence: String = "occasionally",
        maxTurns: Int = 8
    ) {
        self.distiller = distiller
        self.client = client
        self.trigger = trigger
        self.store = store
        self.cadence = cadence
        self.maxTurns = maxTurns
    }

    public func runSurfacingCycle() async throws -> SurfacingDecision {
        // ① 设备内脱敏 —— 原始健康数据到此为止，下面只传 digest。
        let digest = await distiller.distill()
        let context = buildContext()
        // 候选集 = 情绪锁 + 已埋下的胶囊。agent 只能在候选集内检索 / 浮现（D3/D13）。
        let candidates = context.candidates
        let candidateIDs = Set(candidates.compactMap { UUID(uuidString: $0.id) })

        // ② 起会话。
        var reply = try await client.startSurfacing(digest: digest, context: context)

        // ③ 循环派发工具调用。
        // 关键修复（D1）：每一条 reply 的 toolCalls 都要派发 —— 包括 finished:true 的
        // 那条。SYSTEM_PROMPT 让模型在单条 reply 里同时给 toolCalls + finished:true，
        // 旧的 `while !finished` 会整段跳过派发，导致 surfaceCapsule 永不执行、胶囊永不浮现。
        var surfacedID: UUID?
        var turns = 0
        while true {
            var results: [ToolResult] = []
            for call in reply.toolCalls {
                results.append(await dispatch(call, candidates: candidates, candidateIDs: candidateIDs))
                // 记录确实被派发执行过的（合法候选）浮现，作为最终决定的事实来源。
                if call.name == .surfaceCapsule,
                   let arg = call.arguments["capsuleID"],
                   let sid = UUID(uuidString: arg),
                   candidateIDs.contains(sid) {
                    surfacedID = sid
                }
            }
            if reply.finished { break }
            turns += 1
            if turns >= maxTurns { return .hold }   // 触顶止损，按 hold 处理。
            reply = try await client.continueTurn(
                AgentTurn(toolResults: results, finished: false)
            )
        }

        // ④ 最终决定。优先以「确实派发执行过的浮现」为准；否则模型只在 surfaceCapsuleID
        // 字段给了决定（未发 surfaceCapsule 工具调用）时，由网关补一次浮现 —— 保证 .surface
        // 决定与实际副作用一致（D1）。任何浮现目标都必须在候选集内（D3/D13）。
        if let surfacedID {
            return .surface(capsuleID: surfacedID)
        }
        if let idString = reply.surfaceCapsuleID,
           let id = UUID(uuidString: idString),
           candidateIDs.contains(id) {
            await trigger.surface(capsuleID: id)
            return .surface(capsuleID: id)
        }
        return .hold
    }

    // MARK: - 非敏感上下文

    /// 只收集胶囊库元数据与粗地名 —— 不含音频、不含体征、不含精确坐标。
    private func buildContext() -> AgentContext {
        let all = (try? store.allCapsules()) ?? []
        let candidates = all
            .filter { $0.lockKind == .mood && $0.state == .buried }
            .map { capsule in
                AgentContext.CapsuleMeta(
                    id: capsule.id.uuidString,
                    title: capsule.title,
                    tags: capsule.tags,
                    placeName: capsule.placeName
                )
            }
        return AgentContext(candidates: candidates, cadence: cadence)
    }

    // MARK: - 工具派发

    /// 把一次工具调用派发给对应本地服务，回传 ToolResult。
    /// `candidates` / `candidateIDs` = 本轮合法候选集（情绪锁 + 已埋下），
    /// 检索与浮现都被约束在其中（D3/D13）。
    private func dispatch(
        _ call: AgentToolCall,
        candidates: [AgentContext.CapsuleMeta],
        candidateIDs: Set<UUID>
    ) async -> ToolResult {
        switch call.name {
        case .surfaceCapsule:
            // 只允许浮现候选集内（情绪锁 + 已埋下）的胶囊 —— 拒绝越权浮现 date/place
            // 锁或已开启胶囊（D3/D13），即便模型 / prompt 注入硬塞一个 ID。
            guard let idString = call.arguments["capsuleID"],
                  let id = UUID(uuidString: idString),
                  candidateIDs.contains(id) else {
                return ToolResult(name: .surfaceCapsule, output: #"{"ok":false}"#)
            }
            await trigger.surface(capsuleID: id)
            return ToolResult(name: .surfaceCapsule, output: #"{"ok":true}"#)

        case .searchCapsules:
            // 检索只在候选集内（D13）—— agent 既看不到也搜不到候选集之外的胶囊；
            // 同时复用 buildContext 已取的候选，避免重复全表 fetch（D21）。
            let query = (call.arguments["query"] ?? "").lowercased()
            let hits = candidates.filter { meta in
                query.isEmpty
                    || meta.title.lowercased().contains(query)
                    || meta.tags.contains { $0.lowercased().contains(query) }
            }
            let ids = hits.map { $0.id }
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
