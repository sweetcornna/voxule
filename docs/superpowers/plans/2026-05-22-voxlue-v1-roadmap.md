# voxlue v1 实现路线图与分工总览

> 日期：2026-05-22 · 状态：待执行
> 配套设计文档：`docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md`
> 配套分计划：本目录 `2026-05-22-voxlue-02..06-*.md`（共 5 份）

---

## 0. 这份文档是什么

这是 voxlue v1 核心档的**总路线图**。它把架构文档 §11「v1 核心·必做」拆成 6 份可独立执行的实现计划，并钉死两件事：

1. **分工边界** —— 谁做哪部分，见 §2。
2. **接口契约** —— 两个人之间的协议层，见 §3。锁死契约后，前端与协作者可以**并行开工、各自跑测试**，互不阻塞。

读者有两类：
- **你（前端轨）** —— 负责全部 SwiftUI 界面、设计系统、App 壳层。
- **协作者（协作者轨）** —— 负责数据层、领域服务层、平台能力层、云端 agent 与后端代理。

计划 01（数据层）已完成并合入 `main`，本路线图从计划 02 起。

---

## 1. v1 计划地图

| 计划 | 标题 | 主要产出 | 主责轨 | 依赖 |
|---|---|---|---|---|
| 01 | 项目骨架与数据层 | `VoxlueData` 包（4 个 @Model、容器、CapsuleStore） | 协作者 | —— ✅ 已完成 |
| 02 | 录音→装裱→回放主循环 | `AudioEngine` 服务；埋下/装裱/回放/样片墙 UI | 双轨 | 01 |
| 03 | TriggerEngine 三把锁 | `TriggerEngine`+`GeofenceScheduler`+`NotificationService`；灵动岛与地图 UI | 双轨 | 01、02 |
| 04 | 设计系统与液态玻璃 | `VoxlueDesign` 包（tokens、暗房控件、玻璃导航、显影动效） | 前端 | 无（可最先做） |
| 05 | 声音圈共享 | `CircleService`（CKShare）；声音圈 UI | 双轨 | 01、02 |
| 06 | 云端 agent 闭环 | `AgentGateway`+`SignalDistiller`+`IntelligenceService`；serverless 代理 | 双轨 | 01、02、03 |

### 依赖与并行图

```
            ┌─────────────────────────────────────────────┐
01 数据层 ✅ ─┤                                             │
            ├─▶ 02 录音主循环 ─┬─▶ 03 触发引擎 ─▶ 06 agent 闭环
            │                  └─▶ 05 声音圈              │
            └─────────────────────────────────────────────┘
04 设计系统 ── 无依赖，前端轨最先开工，贯穿 02/03/05/06 的所有 UI 任务
```

**关键并行点：** 计划 04（设计系统）不依赖任何后端，前端轨**第一件事就是做计划 04**。与此同时协作者轨开计划 02 的服务部分。两轨在计划 02 的 UI 任务处第一次汇合 —— 那时设计系统已就绪、服务已有假实现，UI 可顺畅落地。

---

## 2. 双轨分工

### 2.1 前端轨（你）

| 范围 | 内容 |
|---|---|
| 设计系统层 | `VoxlueDesign` 包全部 —— 计划 04 整份 |
| 功能模块层 | 全部 SwiftUI 视图：样片墙、地图、埋下流程、胶囊详情/回放、声音圈、我 —— 散落在计划 02/03/05/06 标 `【前端】` 的任务 |
| App 壳层 | App 入口、场景、深链/通知路由、依赖装配（DI 容器）—— 计划 02 起逐步搭，计划 03 完成路由 |

### 2.2 协作者轨

| 范围 | 内容 |
|---|---|
| 数据层 | `VoxlueData` —— 计划 01 ✅；后续计划按需扩 CapsuleStore 查询方法 |
| 领域服务层 | `VoxlueServices` 包：AudioEngine、TriggerEngine、CircleService、AgentGateway、SignalDistiller、IntelligenceService、NotificationService |
| 平台能力层 | 各平台能力的 wrapper（协议 + 真实现 + 假实现）：定位、音频会话、HealthKit、ActivityKit、远端模型客户端 |
| 后端 | agent 密钥中转 serverless 函数（v1 唯一自建服务端，无数据库） |

### 2.3 两轨如何不互相阻塞

契约优先（contract-first）：

1. **协作者每个服务先交「协议 + 假实现」再交真实现。** 计划里每个服务任务的第一步就是定义协议与一个 `Fake*` 假实现（返回固定假数据）。假实现一旦合入，前端就能 `import VoxlueServices`、用假实现驱动视图与 `#Preview`，不必等真实现。
2. **前端先交设计系统（计划 04）。** 所有 UI 任务依赖 `VoxlueDesign` 的控件与 tokens。
3. **SwiftData 模型已固定（计划 01）。** UI 读数据直接用 `@Query`，写数据走 `CapsuleStore`，两轨都依赖同一份已合入的 `VoxlueData`。

> 约定：标 `【协作者】` 的任务必须先于同计划里标 `【前端】` 的对应任务合入「协议 + 假实现」。真实现可晚于前端任务，只要不改协议签名。

---

## 3. 接口契约（前后端边界）

以下协议是两轨的**唯一耦合面**。协议放在 `VoxlueServices` 包；每个协议都配一个 `Fake*` 假实现（同包，供预览与 UI 测试）。**协议签名一经合入即冻结**，要改须双轨同意并同步更新本节。

服务以 `@Observable final class` 实现协议（MV 模式，无 ViewModel）。视图层注入时持有具体类型或 `@Observable` 包装以保留 SwiftUI 观察；各计划给出具体注入写法。`VoxlueData` 已有的 `CapsuleStore` 是具体类（非协议），读数据用 `@Query`。

### 3.0 包布局

`VoxlueKit` 是仓库唯一的本地 SPM 包，内含三个 library 目标，对应架构文档 §4 的三包划分：

| 目标 | 内容 | 落地计划 |
|---|---|---|
| `VoxlueData` | SwiftData 模型、容器、`CapsuleStore` | 01 ✅ |
| `VoxlueServices` | §3 全部服务协议、`Fake*` 假实现、真实现 | 02 新建，03/05/06 扩充 |
| `VoxlueDesign` | 设计 tokens、暗房控件、玻璃导航、显影动效 | 04 新建 |

依赖方向：`VoxlueServices` → `VoxlueData`；`VoxlueDesign` 独立、不依赖另两者；App target 接入全部三个。新增目标只改同一份 `VoxlueKit/Package.swift`，不另建包。

### 3.1 AudioEngine（计划 02）

```swift
/// 一次录音的产物。
public struct RecordingResult: Sendable, Equatable, Hashable {
    public let audioData: Data
    public let duration: TimeInterval
    public let waveform: [Float]   // 归一化 0...1，60–120 个采样点
}

/// 录音器。
@MainActor public protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    var elapsed: TimeInterval { get }            // 录制中实时秒数，驱动 UI
    func requestPermission() async -> Bool
    func start() throws
    func stop() async throws -> RecordingResult
    func cancel()
}

/// 播放器。
@MainActor public protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    var progress: Double { get }                 // 0...1
    func load(_ data: Data) throws
    func play()
    func pause()
    func seek(toProgress progress: Double)
}
```

实现：`AudioEngine`（真，AVFoundation）、`FakeAudioRecording` / `FakeAudioPlaying`（假，返回固定 8 秒假波形）。

### 3.2 TriggerEngine / NotificationService（计划 03）

```swift
/// 显影触发引擎 —— App 的心脏，纯后台、不依赖 UI。
@MainActor public protocol TriggerEngineProtocol: AnyObject {
    /// 让某枚胶囊进入 developing（被围栏/通知/agent 调用）。
    func surface(capsuleID: UUID) async
    /// App 启动/后台刷新时全量重扫过期时间锁与命中地点锁。
    func reconcile() async
    /// 当前正在显影中的胶囊（驱动灵动岛 UI）。
    var developingCapsuleIDs: [UUID] { get }
}

/// 本地通知调度（时间锁兜底）。
public protocol NotificationScheduling: Sendable {
    func requestPermission() async -> Bool
    func scheduleDateLock(capsuleID: UUID, fireAt date: Date) async throws
    func cancel(capsuleID: UUID) async
}

/// 定位 wrapper（平台能力层）。
public protocol LocationProviding: Sendable {
    func requestPermission() async -> Bool
    /// 把这批围栏交给系统监听（内部已按「最近 20 个」裁剪）。
    func monitor(regions: [GeofenceRegion]) async
    var events: AsyncStream<GeofenceEvent> { get }   // 进入围栏事件流
}
public struct GeofenceRegion: Sendable, Hashable {
    public let capsuleID: UUID
    public let latitude, longitude, radius: Double
}
public enum GeofenceEvent: Sendable { case entered(capsuleID: UUID) }
```

`GeofenceScheduler` 是 `TriggerEngine` 内部组件（就近取 20 个围栏轮换），不对前端暴露。

### 3.3 CircleService（计划 05）

```swift
public struct ShareInvitation: Sendable {
    public let url: URL          // CKShare 链接，用于 iMessage/分享
}

@MainActor public protocol CircleServicing: AnyObject {
    func createCircle(name: String) async throws -> Circle
    /// 为圈生成共享邀请。
    func makeInvitation(for circle: Circle) async throws -> ShareInvitation
    /// 接受他人共享链接。
    func acceptShare(from url: URL) async throws
    func circles() async throws -> [Circle]
}
```

实现：`CircleService`（真，SwiftData 原生共享 / CKShare）、`FakeCircleServicing`（假）。

### 3.4 Agent 闭环（计划 06）

```swift
/// 端侧脱敏后越过网络边界的抽象摘要 —— 唯一出设备的健康相关数据。
public struct StateDigest: Sendable, Codable {
    public let tension: Level        // 紧绷度
    public let sleep: Level          // 睡眠质量
    public let calmCapsulesAvailable: Int
    public let daysSinceLastSurfacing: Int
    public enum Level: String, Sendable, Codable { case low, medium, high }
}

/// 端侧脱敏闸门：HealthKit 原始数据 → StateDigest。原始数据永不出设备。
public protocol SignalDistilling: Sendable {
    func distill() async -> StateDigest
}

/// 云端 agent 网关：构建请求、接收工具调用、派发、循环。
@MainActor public protocol AgentGatewaying: AnyObject {
    /// 跑一轮情绪浮现闭环；返回 agent 是否决定浮现及浮现哪枚。
    func runSurfacingCycle() async throws -> SurfacingDecision
}
public enum SurfacingDecision: Sendable { case surface(capsuleID: UUID), hold }

/// 端侧 Foundation Models（自动标题/标签、离线兜底）。
public protocol IntelligenceServicing: Sendable {
    func draftTitle(forTranscriptHint hint: String) async -> String?
}
```

`AgentGateway` 经 `RemoteModelClient` 调 serverless 代理；代理只转发、持有 API key、无数据库。

---

## 4. 排期与里程碑

建议排期（两轨并行）：

| 阶段 | 前端轨 | 协作者轨 |
|---|---|---|
| 第 1 周 | 计划 04 设计系统 | 计划 02 的 AudioEngine 协议+假实现+真实现 |
| 第 2 周 | 计划 02 的 UI（埋下/装裱/回放/样片墙） | 计划 03 的 TriggerEngine + 平台 wrapper |
| 第 3 周 | 计划 03 的 UI（灵动岛/地图）+ 壳层路由 | 计划 05 的 CircleService |
| 第 4 周 | 计划 05 的 UI（声音圈）+ 计划 06 的 UI 触点 | 计划 06 的 agent 闭环 + serverless 代理 |
| 第 5 周 | 联调、demo 打磨 | 联调、demo 打磨 |

**Demo 里程碑（v1 核心完成判据）：** 录一段声 → 选一把锁装裱埋下 → 锁条件满足 → 灵动岛显影提醒 → 打开回放；声音圈可建可邀请；情绪锁能由 agent 闭环浮现一次。对应架构文档 §11「v1 核心·必做」全绿。

---

## 5. 仓库与协作约定

- **分支：** 每份计划开一条 `plan-0N-<name>` 分支，计划内每个 Task 一个提交，完成后开 PR 合入 `main`。
- **提交信息：** 沿用计划 01 风格 —— `feat(audio): …` / `test(trigger): …`，中文 conventional commits。
- **认领：** 协作者认领计划 02/03/05/06 的 `【协作者】` 任务；你认领计划 04 整份及各计划 `【前端】` 任务。每个计划顶部的任务清单标了归属。
- **执行方式：** 每份计划文件头部标注了 superpowers 执行子技能；可用 `subagent-driven-development` 逐 Task 执行。
- **契约变更：** 任何要改 §3 协议签名的需求，先改本文件 §3 并知会对轨，再动代码。

---

## 6. 任务归属标记约定（各分计划内使用）

每份分计划的每个 Task 标题后带一个归属标记：

- `【协作者】` —— 协作者轨负责（服务、数据、平台、agent、后端）。
- `【前端】` —— 前端轨负责（你：视图、设计系统、壳层）。
- `【协作者→前端】` —— 交接点：协作者交付协议+假实现后，前端据此开工。

分计划清单：
- `2026-05-22-voxlue-02-recording-loop.md` —— 录音→装裱→回放主循环
- `2026-05-22-voxlue-03-trigger-engine.md` —— TriggerEngine 三把锁
- `2026-05-22-voxlue-04-design-system.md` —— 设计系统与液态玻璃
- `2026-05-22-voxlue-05-circle-sharing.md` —— 声音圈共享
- `2026-05-22-voxlue-06-agent-loop.md` —— 云端 agent 闭环
