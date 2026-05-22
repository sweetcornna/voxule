# voxlue 计划 06 · 云端 agent 闭环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 voxlue v1 的云端陪伴 agent 闭环 —— 设备内 `SignalDistiller` 把 HealthKit 原始数据脱敏成抽象 `StateDigest`，`AgentGateway` 经 `RemoteModelClient` 调一个极薄的 serverless 代理走多步推理、接住 MCP 式工具调用并派发给本地服务，`IntelligenceService` 用端侧 Foundation Models 代写标题，最后把 BGTaskScheduler 的唤醒接到 `runSurfacingCycle()`，并补齐浮现卡 / cadence 设置 / HealthKit 授权三个 UI 触点。全部带测试，agent 闭环用假实现端到端可验。

**Architecture:** iOS 26 / SwiftUI 应用。本计划在 `VoxlueKit` 的 `VoxlueServices` 库目标（计划 02 新建）里**新增** agent 闭环服务，并新建一个仓库内 serverless 后端目录 `backend/agent-proxy/`。三段数据流（架构文档 §7）：① 设备内 `SignalDistiller` 脱敏闸门 —— HealthKit 原始数据（`HKStateOfMind` 心情、HRV、静息心率、睡眠）+ App 上下文 → 抽象 `StateDigest`；② 云端 voxlue agent —— `AgentGateway` 构建请求经 `RemoteModelClient` 调 serverless 代理，代理持有大模型 API key 转发，agent 回 MCP 式工具调用；③ 设备内执行 —— `AgentGateway` 把工具调用派发给 `TriggerEngineProtocol`（计划 03）与 `CapsuleStore`（`VoxlueData`），结果回传、必要时续轮。**网络边界铁律：只有 `StateDigest` 越过 —— 原始健康数据永不出设备。** 每个平台能力（HealthKit、远端模型）都包 wrapper（协议 + 真实现 + 假实现）。服务以 `@Observable final class` 或 `Sendable struct` 实现协议（MV 模式，无 ViewModel）。

**Tech Stack:** Swift 6.2 · SwiftUI · SwiftData · HealthKit · BackgroundTasks · FoundationModels（端侧）· Swift Testing · Xcode 26.5 · iOS 26 ｜ 后端：Cloudflare Workers · TypeScript

**前置条件:** 计划 01（`VoxlueData`）、计划 02（`VoxlueServices` 目标 + `AudioEngine`）、计划 03（`TriggerEngineProtocol`、`NotificationService`、平台 wrapper、BGTaskScheduler 唤醒入口）均已合入 `main`。已安装 Xcode 26.5+；已登录 Apple Developer 账号。已有一个 Cloudflare 账号（免费档即可），本机装好 `npm` 与 `npx wrangler`。持有一个可用的大模型 API key（Claude / GPT 任一）。

**对应设计文档:** `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md` 的 §6（情绪锁）、§7（云端 Agent 架构）、§10（隐私合规）、§11（MVP 范围）；路线图 `docs/superpowers/plans/2026-05-22-voxlue-v1-roadmap.md` 的 §1、§3.4（本计划契约）、§6（任务归属）。

---

## 文件结构

```
/Users/cornna/project/voxule/
├── VoxlueKit/
│   ├── Package.swift                            扩 VoxlueServices 依赖（无新增 target）
│   ├── Sources/VoxlueServices/
│   │   ├── Agent/
│   │   │   ├── StateDigest.swift                越过网络边界的抽象摘要（契约 §3.4）
│   │   │   ├── SignalDistilling.swift           脱敏闸门协议 + FakeSignalDistilling
│   │   │   ├── SignalDistiller.swift            真实现：HealthKit 原始数据 → StateDigest
│   │   │   ├── HealthProviding.swift            HealthKit wrapper 协议 + 真/假实现
│   │   │   ├── RemoteModelClient.swift          serverless 代理客户端协议 + 真/假实现
│   │   │   ├── AgentToolCall.swift              MCP 式工具调用 / 工具结果 DTO
│   │   │   ├── AgentGatewaying.swift            agent 网关协议 + SurfacingDecision + FakeAgentGateway
│   │   │   ├── AgentGateway.swift               真实现：构建请求、派发工具调用、循环
│   │   │   └── IntelligenceService.swift        IntelligenceServicing 协议 + 真/假实现
│   │   └── ...                                  （计划 02/03 已有文件）
│   └── Tests/VoxlueServicesTests/
│       ├── StateDigestTests.swift
│       ├── SignalDistillerTests.swift
│       ├── RemoteModelClientTests.swift
│       ├── AgentGatewayTests.swift
│       └── IntelligenceServiceTests.swift
├── backend/
│   └── agent-proxy/                             v1 唯一自建服务端（无状态、无数据库）
│       ├── src/index.ts                         Cloudflare Worker：转发到大模型，持有 key
│       ├── wrangler.toml                        Worker 配置
│       ├── package.json
│       ├── tsconfig.json
│       └── README.md                            部署步骤 + API key 设密钥说明
└── voxule/voxule/
    ├── Agent/
    │   ├── SurfacedCapsuleView.swift            浮现卡：一枚被浮现的情绪胶囊
    │   ├── CadenceSettingsView.swift            cadence 设置（轻轻地/偶尔/关）
    │   └── HealthAuthorizationView.swift        HealthKit 授权 + 隐私说明
    ├── voxuleApp.swift                          接线：BGTask 唤醒 → runSurfacingCycle()
    └── voxule.entitlements                      新增 HealthKit 能力
```

---

## Task 1: VoxlueServices 扩 agent 目录与 StateDigest 契约 【协作者】

落地越过网络边界的唯一健康相关数据结构 `StateDigest`（路线图 §3.4 VERBATIM）。这是脱敏闸门的产物，也是合规底线的载体。

**Files:**
- Modify: `VoxlueKit/Package.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/StateDigest.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/StateDigestTests.swift`

- [ ] **Step 1: 确认 VoxlueServices 目标存在**

本计划不新建 target —— `VoxlueServices` 由计划 02 创建。打开 `VoxlueKit/Package.swift` 确认已有 `.library(name: "VoxlueServices", ...)` 与对应 `.target` / `.testTarget`。若计划 02 已合入，`Package.swift` 形如：

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VoxlueKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "VoxlueData", targets: ["VoxlueData"]),
        .library(name: "VoxlueServices", targets: ["VoxlueServices"]),
    ],
    targets: [
        .target(name: "VoxlueData"),
        .testTarget(name: "VoxlueDataTests", dependencies: ["VoxlueData"]),
        .target(name: "VoxlueServices", dependencies: ["VoxlueData"]),
        .testTarget(name: "VoxlueServicesTests", dependencies: ["VoxlueServices"]),
    ]
)
```

本计划只往 `VoxlueServices` 的 `Sources` / `Tests` 里加文件，**不改 `Package.swift` 的 target 结构**。若 `VoxlueServices` 因故缺失，按上方片段补齐后再继续。

- [ ] **Step 2: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/StateDigestTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func stateDigestCodableRoundTrip() throws {
    let digest = StateDigest(
        tension: .high,
        sleep: .low,
        calmCapsulesAvailable: 4,
        daysSinceLastSurfacing: 9
    )
    let data = try JSONEncoder().encode(digest)
    let decoded = try JSONDecoder().decode(StateDigest.self, from: data)
    #expect(decoded.tension == .high)
    #expect(decoded.sleep == .low)
    #expect(decoded.calmCapsulesAvailable == 4)
    #expect(decoded.daysSinceLastSurfacing == 9)
}

@Test func levelHasThreeCases() {
    #expect(StateDigest.Level(rawValue: "low") == .low)
    #expect(StateDigest.Level(rawValue: "medium") == .medium)
    #expect(StateDigest.Level(rawValue: "high") == .high)
}

// 合规铁律：编码后的 JSON 里只能出现抽象 Level 与计数，
// 绝不能出现任何原始体征键名（心率/HRV/睡眠时长/心情分值等）。
@Test func stateDigestJSONContainsNoRawHealthValues() throws {
    let digest = StateDigest(
        tension: .medium, sleep: .medium,
        calmCapsulesAvailable: 2, daysSinceLastSurfacing: 3
    )
    let json = String(data: try JSONEncoder().encode(digest), encoding: .utf8)!
    let forbidden = ["heartRate", "hrv", "bpm", "sleepHours",
                     "restingHeartRate", "moodValence", "sdnn", "latitude", "longitude"]
    for key in forbidden {
        #expect(!json.lowercased().contains(key.lowercased()),
                "StateDigest JSON 不得包含原始体征字段：\(key)")
    }
    // 只允许这四个键。
    let object = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(digest)) as! [String: Any]
    #expect(Set(object.keys) == ["tension", "sleep", "calmCapsulesAvailable", "daysSinceLastSurfacing"])
}
```

- [ ] **Step 3: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter StateDigestTests`
Expected: 编译失败，提示找不到 `StateDigest`

- [ ] **Step 4: 实现 StateDigest**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/StateDigest.swift`：

```swift
import Foundation

/// 端侧脱敏后越过网络边界的抽象摘要 —— 唯一出设备的健康相关数据。
///
/// 合规铁律（架构文档 §7 / §10）：原始健康数据（心率、HRV、睡眠时长、
/// `HKStateOfMind` 心情分值）永不进入此结构。这里只存抽象的 `Level` 枚举
/// 与计数，无法回指到具体个人或具体体征读数。
public struct StateDigest: Sendable, Codable {
    /// 紧绷度。
    public let tension: Level
    /// 睡眠质量。
    public let sleep: Level
    /// 当前可用的「平静」类胶囊数量。
    public let calmCapsulesAvailable: Int
    /// 距上一次情绪浮现的天数。
    public let daysSinceLastSurfacing: Int

    /// 三档抽象等级 —— 不是分数、不是读数。
    public enum Level: String, Sendable, Codable {
        case low, medium, high
    }

    public init(
        tension: Level,
        sleep: Level,
        calmCapsulesAvailable: Int,
        daysSinceLastSurfacing: Int
    ) {
        self.tension = tension
        self.sleep = sleep
        self.calmCapsulesAvailable = calmCapsulesAvailable
        self.daysSinceLastSurfacing = daysSinceLastSurfacing
    }
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter StateDigestTests`
Expected: `Test run with 3 tests passed`

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Agent/StateDigest.swift VoxlueKit/Tests/VoxlueServicesTests/StateDigestTests.swift
git commit -m "feat(agent): 新增越过网络边界的抽象 StateDigest"
```

---

## Task 2: HealthProviding —— HealthKit 平台 wrapper 【协作者】

把 HealthKit 包成协议 + 真实现 + 假实现。真实现读 `HKStateOfMind`、HRV、静息心率、睡眠的**原始**读数；这些读数只在设备内、只交给 `SignalDistiller` —— 它们永不进 `StateDigest`、永不上网。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/HealthProviding.swift`

- [ ] **Step 1: 写失败的测试**

把以下内容追加到 `VoxlueKit/Tests/VoxlueServicesTests/SignalDistillerTests.swift`（文件 Task 3 才正式建，这里先建只含本 Step 的版本）：

创建 `VoxlueKit/Tests/VoxlueServicesTests/SignalDistillerTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func fakeHealthProviderReturnsScriptedSnapshot() async {
    let provider = FakeHealthProviding(
        snapshot: HealthSnapshot(
            moodValence: -0.4, hrvSDNN: 28, restingHeartRate: 72, sleepHours: 5.1
        ),
        authorized: true
    )
    let granted = await provider.requestAuthorization()
    #expect(granted)
    let snapshot = await provider.snapshot()
    #expect(snapshot?.sleepHours == 5.1)
}

@Test func fakeHealthProviderDeniedReturnsNilSnapshot() async {
    let provider = FakeHealthProviding(snapshot: nil, authorized: false)
    let granted = await provider.requestAuthorization()
    #expect(!granted)
    #expect(await provider.snapshot() == nil)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter SignalDistillerTests`
Expected: 编译失败，提示找不到 `FakeHealthProviding` / `HealthSnapshot`

- [ ] **Step 3: 实现 HealthProviding**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/HealthProviding.swift`：

```swift
import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// HealthKit 原始读数快照 —— **仅在设备内存在**。
/// 它是脱敏闸门 `SignalDistiller` 的输入，绝不被序列化上网。
public struct HealthSnapshot: Sendable, Equatable {
    /// `HKStateOfMind` 心情效价，区间约 -1...1（负=不愉快）。
    public let moodValence: Double?
    /// HRV（SDNN，毫秒）。
    public let hrvSDNN: Double?
    /// 静息心率（次/分）。
    public let restingHeartRate: Double?
    /// 最近一晚睡眠时长（小时）。
    public let sleepHours: Double?

    public init(
        moodValence: Double? = nil,
        hrvSDNN: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil
    ) {
        self.moodValence = moodValence
        self.hrvSDNN = hrvSDNN
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
    }
}

/// HealthKit 平台能力 wrapper。
/// 真实现读原始体征；预览/测试注入假实现。
public protocol HealthProviding: Sendable {
    /// 申请读取授权（HealthKit 须显式授权）。
    func requestAuthorization() async -> Bool
    /// 取一份原始读数快照；未授权或无数据返回 nil。
    func snapshot() async -> HealthSnapshot?
}

/// 假实现 —— 返回脚本化快照，供预览与单元测试。
public struct FakeHealthProviding: HealthProviding {
    private let scriptedSnapshot: HealthSnapshot?
    private let authorized: Bool

    public init(snapshot: HealthSnapshot?, authorized: Bool = true) {
        self.scriptedSnapshot = snapshot
        self.authorized = authorized
    }

    public func requestAuthorization() async -> Bool { authorized }
    public func snapshot() async -> HealthSnapshot? { authorized ? scriptedSnapshot : nil }
}

#if canImport(HealthKit)
/// 真实现 —— 经 HealthKit 读 `HKStateOfMind`、HRV、静息心率、睡眠。
/// 这些原始读数只在设备内流转，只交给 `SignalDistiller` 脱敏。
public struct HealthKitHealthProvider: HealthProviding {
    private let store = HKHealthStore()

    public init() {}

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        types.insert(HKObjectType.stateOfMindType())
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(rhr)
        }
        types.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        return types
    }

    public func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    public func snapshot() async -> HealthSnapshot? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        async let mood = latestMoodValence()
        async let hrv = latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let rhr = latestQuantity(.restingHeartRate,
                                       unit: HKUnit.count().unitDivided(by: .minute()))
        async let sleep = lastNightSleepHours()
        return HealthSnapshot(
            moodValence: await mood,
            hrvSDNN: await hrv,
            restingHeartRate: await rhr,
            sleepHours: await sleep
        )
    }

    private func latestMoodValence() async -> Double? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.stateOfMindType(),
                predicate: nil, limit: 1, sortDescriptors: [sort]
            ) { _, samples, _ in
                let valence = (samples?.first as? HKStateOfMind)?.valence
                continuation.resume(returning: valence)
            }
            store.execute(query)
        }
    }

    private func latestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func lastNightSleepHours() async -> Double? {
        let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let asleep = (samples as? [HKCategorySample])?.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                        || $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                        || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                        || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                } ?? []
                guard !asleep.isEmpty else {
                    continuation.resume(returning: nil); return
                }
                let seconds = asleep.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: seconds / 3600.0)
            }
            store.execute(query)
        }
    }
}
#endif
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter SignalDistillerTests`
Expected: `Test run with 2 tests passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Agent/HealthProviding.swift VoxlueKit/Tests/VoxlueServicesTests/SignalDistillerTests.swift
git commit -m "feat(agent): 新增 HealthProviding —— HealthKit wrapper（协议+真/假实现）"
```

---

## Task 3: SignalDistiller —— 端侧脱敏闸门 【协作者】

实现 `SignalDistilling`（路线图 §3.4 VERBATIM）。`SignalDistiller` 把 `HealthSnapshot` 原始读数 + `CapsuleStore` 上下文压成抽象 `StateDigest`：原始读数在函数内被映射成 `Level`，函数返回时已无法回指任何具体读数。`FakeSignalDistilling` 同包提供。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/SignalDistilling.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/SignalDistiller.swift`
- Test: 续写 `VoxlueKit/Tests/VoxlueServicesTests/SignalDistillerTests.swift`

- [ ] **Step 1: 写失败的测试**

把以下内容追加到 `VoxlueKit/Tests/VoxlueServicesTests/SignalDistillerTests.swift`：

```swift
import VoxlueData
import SwiftData

@Test func fakeSignalDistillingReturnsScriptedDigest() async {
    let scripted = StateDigest(tension: .high, sleep: .low,
                               calmCapsulesAvailable: 1, daysSinceLastSurfacing: 12)
    let distiller = FakeSignalDistilling(digest: scripted)
    let digest = await distiller.distill()
    #expect(digest.tension == .high)
    #expect(digest.daysSinceLastSurfacing == 12)
}

@MainActor
@Test func distillerMapsPoorSleepToLowLevel() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let health = FakeHealthProviding(
        snapshot: HealthSnapshot(moodValence: -0.5, hrvSDNN: 18,
                                 restingHeartRate: 80, sleepHours: 4.0)
    )
    let distiller = SignalDistiller(health: health, store: store)
    let digest = await distiller.distill()
    // 4 小时睡眠 → low；低 HRV + 高静息心率 + 负心情 → tension high。
    #expect(digest.sleep == .low)
    #expect(digest.tension == .high)
}

@MainActor
@Test func distillerCountsCalmCapsules() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    // 两枚带「平静」标签的情绪锁胶囊。
    try store.add(VoxlueData.Capsule(title: "海", lock: .mood(notBefore: nil)).tagged("平静"))
    try store.add(VoxlueData.Capsule(title: "雨", lock: .mood(notBefore: nil)).tagged("平静"))
    try store.add(VoxlueData.Capsule(title: "闹市", lock: .mood(notBefore: nil)))
    let distiller = SignalDistiller(
        health: FakeHealthProviding(snapshot: nil), store: store
    )
    let digest = await distiller.distill()
    #expect(digest.calmCapsulesAvailable == 2)
}

// 合规铁律：脱敏闸门的产物里不得残留任何原始读数。
@MainActor
@Test func distilledDigestCarriesNoRawHealthValues() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let rawSleep = 4.0
    let distiller = SignalDistiller(
        health: FakeHealthProviding(
            snapshot: HealthSnapshot(moodValence: -0.5, hrvSDNN: 18,
                                     restingHeartRate: 80, sleepHours: rawSleep)
        ),
        store: store
    )
    let digest = await distiller.distill()
    let json = String(data: try JSONEncoder().encode(digest), encoding: .utf8)!
    // 原始睡眠 4.0 这个数值绝不应出现在越过边界的摘要里。
    #expect(!json.contains("4.0"))
    #expect(!json.contains("18"))
    #expect(!json.contains("80"))
}

private extension VoxlueData.Capsule {
    func tagged(_ tag: String) -> VoxlueData.Capsule { self.tags = [tag]; return self }
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter SignalDistillerTests`
Expected: 编译失败，提示找不到 `FakeSignalDistilling` / `SignalDistiller`

- [ ] **Step 3: 实现 SignalDistilling 协议与假实现**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/SignalDistilling.swift`：

```swift
import Foundation

/// 端侧脱敏闸门：HealthKit 原始数据 → StateDigest。原始数据永不出设备。
public protocol SignalDistilling: Sendable {
    func distill() async -> StateDigest
}

/// 假实现 —— 返回脚本化摘要，供预览与单元测试。
public struct FakeSignalDistilling: SignalDistilling {
    private let scripted: StateDigest

    public init(digest: StateDigest) {
        self.scripted = digest
    }

    /// 一个中性默认值，便于预览。
    public init() {
        self.scripted = StateDigest(
            tension: .medium, sleep: .medium,
            calmCapsulesAvailable: 3, daysSinceLastSurfacing: 5
        )
    }

    public func distill() async -> StateDigest { scripted }
}
```

- [ ] **Step 4: 实现 SignalDistiller 真实现**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/SignalDistiller.swift`：

```swift
import Foundation
import VoxlueData

/// 端侧脱敏闸门真实现。
///
/// 职责：把 `HealthSnapshot` 原始读数 + `CapsuleStore` 上下文映射为抽象
/// `StateDigest`。**原始读数只在本类内部存在，函数返回时只剩 `Level` 与计数。**
///
/// 注意（架构文档 §6）：这里不是在「打分」或「做规则诊断」—— 它只是把
/// 连续读数收敛到三档抽象，真正决定是否浮现的是云端 agent，不是这些阈值。
public struct SignalDistiller: SignalDistilling {
    private let health: HealthProviding
    private let store: CapsuleStore

    public init(health: HealthProviding, store: CapsuleStore) {
        self.health = health
        self.store = store
    }

    public func distill() async -> StateDigest {
        let snapshot = await health.snapshot()
        let tension = Self.tensionLevel(from: snapshot)
        let sleep = Self.sleepLevel(from: snapshot?.sleepHours)
        let calm = await calmCapsuleCount()
        let days = await daysSinceLastSurfacing()
        return StateDigest(
            tension: tension,
            sleep: sleep,
            calmCapsulesAvailable: calm,
            daysSinceLastSurfacing: days
        )
    }

    // MARK: - 原始读数 → 抽象 Level（映射只在设备内）

    /// 紧绷度：综合负心情、低 HRV、高静息心率。无数据时取 medium。
    static func tensionLevel(from snapshot: HealthSnapshot?) -> StateDigest.Level {
        guard let snapshot else { return .medium }
        var score = 0
        if let v = snapshot.moodValence { score += v < -0.2 ? 1 : (v > 0.2 ? -1 : 0) }
        if let hrv = snapshot.hrvSDNN { score += hrv < 25 ? 1 : (hrv > 55 ? -1 : 0) }
        if let rhr = snapshot.restingHeartRate { score += rhr > 75 ? 1 : (rhr < 58 ? -1 : 0) }
        if score >= 2 { return .high }
        if score <= -1 { return .low }
        return .medium
    }

    /// 睡眠质量。无数据时取 medium。
    static func sleepLevel(from hours: Double?) -> StateDigest.Level {
        guard let hours else { return .medium }
        if hours < 5.5 { return .low }
        if hours >= 7.0 { return .high }
        return .medium
    }

    // MARK: - App 上下文（非健康，可粗粒度参与摘要）

    @MainActor
    private func calmCapsuleCount() async -> Int {
        let all = (try? store.allCapsules()) ?? []
        let calmTags: Set<String> = ["平静", "calm", "安心", "海", "雨"]
        return all.filter { capsule in
            capsule.lock.kind == .mood
                && !Set(capsule.tags).isDisjoint(with: calmTags)
        }.count
    }

    @MainActor
    private func daysSinceLastSurfacing() async -> Int {
        let all = (try? store.allCapsules()) ?? []
        // 最近一次「已显影/已开启」的情绪胶囊的 openedAt（或 createdAt）。
        let surfaced = all
            .filter { $0.lock.kind == .mood && ($0.state == .developed || $0.state == .opened) }
            .compactMap { $0.openedAt ?? $0.createdAt }
            .max()
        guard let last = surfaced else { return 99 }
        return max(0, Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0)
    }
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter SignalDistillerTests`
Expected: `Test run with 6 tests passed`（2 health + 4 distiller）

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Agent/SignalDistilling.swift VoxlueKit/Sources/VoxlueServices/Agent/SignalDistiller.swift VoxlueKit/Tests/VoxlueServicesTests/SignalDistillerTests.swift
git commit -m "feat(agent): 新增 SignalDistiller 端侧脱敏闸门 + SignalDistilling 协议"
```

---

## Task 4: AgentToolCall —— MCP 式工具调用 DTO 【协作者】

定义 agent 与设备之间的工具调用协议数据结构：agent 回的工具调用（`surfaceCapsule` / `searchCapsules` / `composeStory` / `draftTitle` / `adjustCadence`）与设备回传的工具结果。这是 `RemoteModelClient` 与 `AgentGateway` 共用的 DTO。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/AgentToolCall.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/RemoteModelClientTests.swift`（先只放本 Step 的工具调用测试，Task 5 续写）：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func toolCallDecodesSurfaceCapsule() throws {
    let json = """
    { "name": "surfaceCapsule", "arguments": { "capsuleID": "\(UUID().uuidString)" } }
    """
    let call = try JSONDecoder().decode(AgentToolCall.self, from: Data(json.utf8))
    #expect(call.name == .surfaceCapsule)
    #expect(call.arguments["capsuleID"] != nil)
}

@Test func toolCallDecodesAdjustCadence() throws {
    let json = #"{ "name": "adjustCadence", "arguments": { "cadence": "rarely" } }"#
    let call = try JSONDecoder().decode(AgentToolCall.self, from: Data(json.utf8))
    #expect(call.name == .adjustCadence)
    #expect(call.arguments["cadence"] == "rarely")
}

@Test func agentTurnEncodesToolResults() throws {
    let turn = AgentTurn(
        toolResults: [ToolResult(name: .searchCapsules, output: #"["a","b"]"#)],
        finished: false
    )
    let data = try JSONEncoder().encode(turn)
    let decoded = try JSONDecoder().decode(AgentTurn.self, from: data)
    #expect(decoded.toolResults.first?.name == .searchCapsules)
    #expect(decoded.finished == false)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter RemoteModelClientTests`
Expected: 编译失败，提示找不到 `AgentToolCall` / `AgentTurn` / `ToolResult`

- [ ] **Step 3: 实现 AgentToolCall**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/AgentToolCall.swift`：

```swift
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
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter RemoteModelClientTests`
Expected: `Test run with 3 tests passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Agent/AgentToolCall.swift VoxlueKit/Tests/VoxlueServicesTests/RemoteModelClientTests.swift
git commit -m "feat(agent): 新增 MCP 式工具调用 DTO（AgentToolCall/AgentReply/AgentTurn）"
```

---

## Task 5: RemoteModelClient —— serverless 代理客户端 【协作者】

把「调云端 agent」包成协议 + 真 HTTP 实现 + 假实现。真实现只跟自建 serverless 代理通信，**绝不内嵌大模型 API key** —— key 由代理持有。`FakeRemoteModelClient` 返回脚本化的多轮 `AgentReply` 序列，让 `AgentGateway` 闭环可在离线、无 key 情况下端到端测试。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/RemoteModelClient.swift`
- Test: 续写 `VoxlueKit/Tests/VoxlueServicesTests/RemoteModelClientTests.swift`

- [ ] **Step 1: 写失败的测试**

把以下内容追加到 `VoxlueKit/Tests/VoxlueServicesTests/RemoteModelClientTests.swift`：

```swift
@Test func fakeClientReplaysScriptedReplies() async throws {
    let cid = UUID().uuidString
    let scripted: [AgentReply] = [
        AgentReply(toolCalls: [AgentToolCall(name: .searchCapsules,
                                             arguments: ["query": "calm"])], finished: false),
        AgentReply(toolCalls: [AgentToolCall(name: .surfaceCapsule,
                                             arguments: ["capsuleID": cid])], finished: false),
        AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: cid),
    ]
    let client = FakeRemoteModelClient(replies: scripted)
    let digest = StateDigest(tension: .high, sleep: .low,
                             calmCapsulesAvailable: 2, daysSinceLastSurfacing: 9)

    let r0 = try await client.startSurfacing(digest: digest, context: AgentContext.empty)
    #expect(r0.toolCalls.first?.name == .searchCapsules)
    let r1 = try await client.continueTurn(AgentTurn(toolResults: [], finished: false))
    #expect(r1.toolCalls.first?.name == .surfaceCapsule)
    let r2 = try await client.continueTurn(AgentTurn(toolResults: [], finished: false))
    #expect(r2.finished)
    #expect(r2.surfaceCapsuleID == cid)
}

@Test func fakeClientRecordsRequestForKeyLeakAssertion() async throws {
    let client = FakeRemoteModelClient(replies: [AgentReply(toolCalls: [], finished: true)])
    _ = try await client.startSurfacing(
        digest: StateDigest(tension: .low, sleep: .high,
                            calmCapsulesAvailable: 1, daysSinceLastSurfacing: 1),
        context: AgentContext.empty
    )
    // 客户端绝不内嵌 API key —— 发出的请求体里不得出现任何疑似 key 的字段。
    let body = client.lastRequestBody ?? ""
    for suspicious in ["sk-", "api_key", "apiKey", "authorization", "Bearer"] {
        #expect(!body.contains(suspicious))
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter RemoteModelClientTests`
Expected: 编译失败，提示找不到 `FakeRemoteModelClient` / `AgentContext` / `RemoteModelClient`

- [ ] **Step 3: 实现 RemoteModelClient**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/RemoteModelClient.swift`：

```swift
import Foundation

/// 随 StateDigest 一同上行的**非敏感**上下文（架构文档 §7）。
/// 只含胶囊库元数据与粗粒度地名 —— 不含音频、不含原始体征、不含精确坐标。
public struct AgentContext: Sendable, Codable {
    /// 候选情绪胶囊的元数据（id + 标题 + 标签 + 粗地名）。
    public struct CapsuleMeta: Sendable, Codable {
        public let id: String
        public let title: String
        public let tags: [String]
        public let placeName: String?
        public init(id: String, title: String, tags: [String], placeName: String?) {
            self.id = id; self.title = title; self.tags = tags; self.placeName = placeName
        }
    }
    public let candidates: [CapsuleMeta]
    /// 当前浮现频率档（轻轻地/偶尔/关）。
    public let cadence: String

    public init(candidates: [CapsuleMeta], cadence: String) {
        self.candidates = candidates
        self.cadence = cadence
    }

    public static let empty = AgentContext(candidates: [], cadence: "occasionally")
}

/// serverless 代理客户端。真实现只跟自建代理通信，绝不内嵌大模型 API key。
public protocol RemoteModelClient: Sendable {
    /// 开一轮情绪浮现会话；上行 StateDigest + 非敏感上下文。
    func startSurfacing(digest: StateDigest, context: AgentContext) async throws -> AgentReply
    /// 把上一轮工具结果回传，取 agent 下一轮回复。
    func continueTurn(_ turn: AgentTurn) async throws -> AgentReply
}

public enum RemoteModelError: Error, Sendable {
    case transport(String)
    case badStatus(Int)
    case decoding(String)
    case sessionExhausted   // 假实现脚本用尽
}

/// 真实现 —— 调自建 serverless 代理。
/// 代理地址通过初始化注入；**API key 不在客户端，由代理持有**。
public final class HTTPRemoteModelClient: RemoteModelClient, @unchecked Sendable {
    private let proxyURL: URL
    private let session: URLSession
    /// 一次浮现会话的 ID，让代理把多轮请求串起来（代理仍无状态 —— ID 仅由请求体携带）。
    private let sessionID = UUID().uuidString

    public init(proxyURL: URL, session: URLSession = .shared) {
        self.proxyURL = proxyURL
        self.session = session
    }

    public func startSurfacing(digest: StateDigest, context: AgentContext) async throws -> AgentReply {
        struct StartBody: Codable {
            let sessionID: String
            let phase: String
            let digest: StateDigest
            let context: AgentContext
        }
        return try await post(StartBody(
            sessionID: sessionID, phase: "start", digest: digest, context: context
        ))
    }

    public func continueTurn(_ turn: AgentTurn) async throws -> AgentReply {
        struct ContinueBody: Codable {
            let sessionID: String
            let phase: String
            let turn: AgentTurn
        }
        return try await post(ContinueBody(
            sessionID: sessionID, phase: "continue", turn: turn
        ))
    }

    private func post<Body: Encodable>(_ body: Body) async throws -> AgentReply {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 注意：这里没有 Authorization 头 —— key 由代理持有，客户端不碰。
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RemoteModelError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw RemoteModelError.transport("非 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RemoteModelError.badStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(AgentReply.self, from: data)
        } catch {
            throw RemoteModelError.decoding(error.localizedDescription)
        }
    }
}

/// 假实现 —— 顺序回放脚本化的 AgentReply 序列，供 AgentGateway 闭环端到端测试。
public final class FakeRemoteModelClient: RemoteModelClient, @unchecked Sendable {
    private var replies: [AgentReply]
    private var cursor = 0
    /// 最近一次发出的请求体（编码成 JSON 字符串），供「不泄漏 key」断言。
    public private(set) var lastRequestBody: String?

    public init(replies: [AgentReply]) {
        self.replies = replies
    }

    public func startSurfacing(digest: StateDigest, context: AgentContext) async throws -> AgentReply {
        struct StartBody: Codable { let digest: StateDigest; let context: AgentContext }
        lastRequestBody = String(
            data: (try? JSONEncoder().encode(StartBody(digest: digest, context: context))) ?? Data(),
            encoding: .utf8
        )
        return try next()
    }

    public func continueTurn(_ turn: AgentTurn) async throws -> AgentReply {
        lastRequestBody = String(
            data: (try? JSONEncoder().encode(turn)) ?? Data(), encoding: .utf8
        )
        return try next()
    }

    private func next() throws -> AgentReply {
        guard cursor < replies.count else { throw RemoteModelError.sessionExhausted }
        defer { cursor += 1 }
        return replies[cursor]
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter RemoteModelClientTests`
Expected: `Test run with 5 tests passed`（3 DTO + 2 client）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Agent/RemoteModelClient.swift VoxlueKit/Tests/VoxlueServicesTests/RemoteModelClientTests.swift
git commit -m "feat(agent): 新增 RemoteModelClient —— serverless 代理客户端（不内嵌 API key）"
```

---

## Task 6: AgentGateway —— agent 闭环网关 【协作者】

实现 `AgentGatewaying` 与 `SurfacingDecision`（路线图 §3.4 VERBATIM）。`AgentGateway.runSurfacingCycle()` 跑完整闭环：脱敏 → 起会话 → 循环接工具调用并派发给 `TriggerEngineProtocol` / `CapsuleStore` → 回传结果 → 直到 agent `finished` → 返回 `SurfacingDecision`。`FakeAgentGateway` 同包提供给前端做预览。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/AgentGatewaying.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/AgentGateway.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/AgentGatewayTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/AgentGatewayTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import VoxlueServices
import VoxlueData

/// 测试用最小 TriggerEngine 替身 —— 记录被 surface 的胶囊。
/// 真协议在计划 03 的 VoxlueServices 里；这里复用同包类型。
@MainActor
final class SpyTriggerEngine: TriggerEngineProtocol {
    private(set) var surfaced: [UUID] = []
    var developingCapsuleIDs: [UUID] { surfaced }
    func surface(capsuleID: UUID) async { surfaced.append(capsuleID) }
    func reconcile() async {}
}

@MainActor
@Test func surfacingCycleDispatchesScriptedToolCallsAndSurfaces() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = VoxlueData.Capsule(title: "外婆的院子", lock: .mood(notBefore: nil))
    try store.add(capsule)
    let cid = capsule.id

    let trigger = SpyTriggerEngine()
    let client = FakeRemoteModelClient(replies: [
        AgentReply(toolCalls: [AgentToolCall(name: .searchCapsules,
                                             arguments: ["query": "院子"])], finished: false),
        AgentReply(toolCalls: [AgentToolCall(name: .surfaceCapsule,
                                             arguments: ["capsuleID": cid.uuidString])], finished: false),
        AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: cid.uuidString),
    ])
    let gateway = AgentGateway(
        distiller: FakeSignalDistilling(),
        client: client,
        trigger: trigger,
        store: store
    )

    let decision = try await gateway.runSurfacingCycle()

    #expect(decision == .surface(capsuleID: cid))
    // surfaceCapsule 工具调用确实被派发给了 TriggerEngine。
    #expect(trigger.surfaced == [cid])
}

@MainActor
@Test func surfacingCycleHoldsWhenAgentDecidesNotToSurface() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let trigger = SpyTriggerEngine()
    let client = FakeRemoteModelClient(replies: [
        AgentReply(toolCalls: [], finished: true, surfaceCapsuleID: nil),
    ])
    let gateway = AgentGateway(
        distiller: FakeSignalDistilling(),
        client: client, trigger: trigger, store: store
    )
    let decision = try await gateway.runSurfacingCycle()
    #expect(decision == .hold)
    #expect(trigger.surfaced.isEmpty)
}

@MainActor
@Test func surfacingCycleStopsAtMaxTurnsWithoutInfiniteLoop() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    // 一个永不 finished 的脚本 —— 网关须在 maxTurns 处止损并返回 hold。
    let neverEnding = Array(repeating:
        AgentReply(toolCalls: [AgentToolCall(name: .searchCapsules,
                                             arguments: [:])], finished: false),
        count: 50)
    let gateway = AgentGateway(
        distiller: FakeSignalDistilling(),
        client: FakeRemoteModelClient(replies: neverEnding),
        trigger: SpyTriggerEngine(), store: store
    )
    let decision = try await gateway.runSurfacingCycle()
    #expect(decision == .hold)
}

@MainActor
@Test func fakeAgentGatewayReturnsScriptedDecision() async throws {
    let cid = UUID()
    let gateway = FakeAgentGateway(decision: .surface(capsuleID: cid))
    #expect(try await gateway.runSurfacingCycle() == .surface(capsuleID: cid))
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter AgentGatewayTests`
Expected: 编译失败，提示找不到 `AgentGateway` / `AgentGatewaying` / `SurfacingDecision` / `FakeAgentGateway`

- [ ] **Step 3: 实现 AgentGatewaying 协议、SurfacingDecision 与假实现**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/AgentGatewaying.swift`：

```swift
import Foundation

/// 云端 agent 网关：构建请求、接收工具调用、派发、循环。
@MainActor public protocol AgentGatewaying: AnyObject {
    /// 跑一轮情绪浮现闭环；返回 agent 是否决定浮现及浮现哪枚。
    func runSurfacingCycle() async throws -> SurfacingDecision
}

/// 一轮闭环的最终决定。
public enum SurfacingDecision: Sendable, Equatable {
    case surface(capsuleID: UUID)
    case hold
}

/// 假实现 —— 返回脚本化决定，供前端预览浮现卡。
@MainActor
public final class FakeAgentGateway: AgentGatewaying {
    private let scripted: SurfacingDecision

    public init(decision: SurfacingDecision = .hold) {
        self.scripted = decision
    }

    public func runSurfacingCycle() async throws -> SurfacingDecision { scripted }
}
```

- [ ] **Step 4: 实现 AgentGateway 真实现**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/AgentGateway.swift`：

```swift
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
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter AgentGatewayTests`
Expected: `Test run with 4 tests passed`

- [ ] **Step 6: 跑全包测试确认无回归**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 末行 `Test run with N tests passed`，N 含计划 01/02/03 已有测试 + 本计划累计 18 个，全绿。

- [ ] **Step 7: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Agent/AgentGatewaying.swift VoxlueKit/Sources/VoxlueServices/Agent/AgentGateway.swift VoxlueKit/Tests/VoxlueServicesTests/AgentGatewayTests.swift
git commit -m "feat(agent): 新增 AgentGateway —— agent 闭环网关与工具派发"
```

---

## Task 7: IntelligenceService —— 端侧 Foundation Models 自动标题 【协作者】

实现 `IntelligenceServicing`（路线图 §3.4 VERBATIM）：用端侧 Foundation Models 给胶囊代写标题（`draftTitle`），并做离线兜底（模型不可用时回 nil，调用方按「（无题）」处理）。v1 加分项，保持轻量。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/Agent/IntelligenceService.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/IntelligenceServiceTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/IntelligenceServiceTests.swift`：

```swift
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
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter IntelligenceServiceTests`
Expected: 编译失败，提示找不到 `FakeIntelligenceServicing` / `IntelligenceService`

- [ ] **Step 3: 实现 IntelligenceService**

创建 `VoxlueKit/Sources/VoxlueServices/Agent/IntelligenceService.swift`：

```swift
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
                严禁出现「治疗」「诊断」「评估」「改善」「症状」一类词。
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
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter IntelligenceServiceTests`
Expected: `Test run with 3 tests passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Agent/IntelligenceService.swift VoxlueKit/Tests/VoxlueServicesTests/IntelligenceServiceTests.swift
git commit -m "feat(agent): 新增 IntelligenceService 端侧自动标题（Foundation Models）"
```

---

## Task 8: serverless 代理后端 —— Cloudflare Worker 【协作者】

建 v1 唯一自建服务端：一个极薄、无状态、无数据库的 Cloudflare Worker。它持有大模型 API key（作为 Worker secret），把客户端来的 `StateDigest + 上下文` 转成一次大模型调用、再把模型回复整形成 `AgentReply` 返回。客户端永不见 key。

**Files:**
- Create: `backend/agent-proxy/package.json`
- Create: `backend/agent-proxy/tsconfig.json`
- Create: `backend/agent-proxy/wrangler.toml`
- Create: `backend/agent-proxy/src/index.ts`
- Create: `backend/agent-proxy/README.md`
- Create: `backend/agent-proxy/.gitignore`

- [ ] **Step 1: 建后端目录与工程文件**

创建 `backend/agent-proxy/package.json`：

```json
{
  "name": "voxlue-agent-proxy",
  "version": "1.0.0",
  "private": true,
  "description": "voxlue v1 唯一自建服务端：极薄、无状态、无数据库的大模型转发代理",
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "wrangler": "^3.90.0",
    "@cloudflare/workers-types": "^4.20241127.0"
  }
}
```

创建 `backend/agent-proxy/tsconfig.json`：

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*.ts"]
}
```

创建 `backend/agent-proxy/wrangler.toml`：

```toml
name = "voxlue-agent-proxy"
main = "src/index.ts"
compatibility_date = "2026-05-22"

# 大模型 API key 不写在这里 —— 它是 secret，用 `wrangler secret put` 注入。
# 见 README.md「部署步骤」。
[vars]
# 非敏感配置可放这里。MODEL_ENDPOINT 默认指向 Anthropic Messages API。
MODEL_ENDPOINT = "https://api.anthropic.com/v1/messages"
MODEL_NAME = "claude-3-5-haiku-20241022"
```

创建 `backend/agent-proxy/.gitignore`：

```gitignore
node_modules/
.wrangler/
.dev.vars
dist/
```

- [ ] **Step 2: 写 Worker 主体**

创建 `backend/agent-proxy/src/index.ts`：

```typescript
/**
 * voxlue agent 代理 —— v1 唯一自建服务端。
 *
 * 设计原则（架构文档 §7）：极薄、无状态、无数据库。
 * 唯一职责：持有大模型 API key（作为 secret），把设备来的
 * { StateDigest + 非敏感上下文 } 转成一次大模型调用，再把模型回复
 * 整形成设备端约定的 AgentReply 返回。设备端永不见 key。
 *
 * 它不存任何用户数据、不记日志正文、不做鉴权之外的状态保持。
 */

export interface Env {
  // 经 `wrangler secret put MODEL_API_KEY` 注入，不入代码库。
  MODEL_API_KEY: string;
  MODEL_ENDPOINT: string;
  MODEL_NAME: string;
}

// ---- 与设备端约定的数据结构（对应 Swift 侧 DTO）----

interface StateDigest {
  tension: 'low' | 'medium' | 'high';
  sleep: 'low' | 'medium' | 'high';
  calmCapsulesAvailable: number;
  daysSinceLastSurfacing: number;
}

interface CapsuleMeta {
  id: string;
  title: string;
  tags: string[];
  placeName: string | null;
}

interface AgentContext {
  candidates: CapsuleMeta[];
  cadence: string;
}

interface ToolCall {
  name: string;
  arguments: Record<string, string>;
}

interface AgentReply {
  toolCalls: ToolCall[];
  finished: boolean;
  surfaceCapsuleID: string | null;
}

interface RequestBody {
  sessionID?: string;
  phase: 'start' | 'continue';
  digest?: StateDigest;
  context?: AgentContext;
  turn?: { toolResults: { name: string; output: string }[]; finished: boolean };
}

// agent 的系统提示词 —— 陪伴定位，严禁临床措辞。
const SYSTEM_PROMPT = `你是 voxlue 的陪伴 agent。voxlue 把环境声做成「声音胶囊」，
情绪锁胶囊由你判断何时「浮现」给用户。

你的角色是一个安静的、旧派的冲洗师，是「陪伴」不是医疗。
严禁任何临床措辞：不得出现「治疗」「诊断」「评估」「改善症状」「疗效」一类词。
你不读体征、不打分 —— 你只看到一份抽象摘要（紧绷度/睡眠/可用平静胶囊数/距上次浮现天数）。

根据摘要与候选胶囊元数据，决定是否浮现一枚情绪胶囊、浮现哪枚。
克制：宁可 hold，也不要打扰。距上次浮现太近、或没有合适候选时，就 hold。

只输出一个 JSON 对象，不要任何额外文字，结构：
{ "toolCalls": [ { "name": "surfaceCapsule", "arguments": { "capsuleID": "<id>" } } ],
  "finished": true, "surfaceCapsuleID": "<id 或 null>" }
决定不浮现时：{ "toolCalls": [], "finished": true, "surfaceCapsuleID": null }`;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') {
      return jsonResponse({ error: 'method not allowed' }, 405);
    }
    if (!env.MODEL_API_KEY) {
      return jsonResponse({ error: 'proxy misconfigured: missing key' }, 500);
    }

    let body: RequestBody;
    try {
      body = (await request.json()) as RequestBody;
    } catch {
      return jsonResponse({ error: 'invalid JSON' }, 400);
    }

    // 把设备来的摘要 + 上下文整形成给大模型的用户消息。
    const userContent =
      body.phase === 'start'
        ? `状态摘要：${JSON.stringify(body.digest)}\n` +
          `候选胶囊：${JSON.stringify(body.context?.candidates ?? [])}\n` +
          `浮现频率档：${body.context?.cadence ?? 'occasionally'}\n` +
          `请决定是否浮现，并按约定 JSON 输出。`
        : `上一轮工具结果：${JSON.stringify(body.turn?.toolResults ?? [])}\n` +
          `请给出最终决定，并按约定 JSON 输出。`;

    // 调大模型（Anthropic Messages API 形态）。key 在此处、且仅在此处使用。
    let modelResponse: Response;
    try {
      modelResponse = await fetch(env.MODEL_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.MODEL_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: env.MODEL_NAME,
          max_tokens: 512,
          system: SYSTEM_PROMPT,
          messages: [{ role: 'user', content: userContent }],
        }),
      });
    } catch (e) {
      return jsonResponse({ error: 'upstream transport failed' }, 502);
    }

    if (!modelResponse.ok) {
      return jsonResponse({ error: `upstream status ${modelResponse.status}` }, 502);
    }

    // 从模型回复里抽出那段 JSON，整形成 AgentReply。
    let reply: AgentReply = { toolCalls: [], finished: true, surfaceCapsuleID: null };
    try {
      const data = (await modelResponse.json()) as {
        content?: { type: string; text?: string }[];
      };
      const text = data.content?.find((c) => c.type === 'text')?.text ?? '';
      const match = text.match(/\{[\s\S]*\}/);
      if (match) {
        const parsed = JSON.parse(match[0]) as Partial<AgentReply>;
        reply = {
          toolCalls: Array.isArray(parsed.toolCalls) ? parsed.toolCalls : [],
          finished: parsed.finished !== false,
          surfaceCapsuleID: parsed.surfaceCapsuleID ?? null,
        };
      }
    } catch {
      // 解析失败 —— 安全兜底为 hold，绝不误浮现。
      reply = { toolCalls: [], finished: true, surfaceCapsuleID: null };
    }

    return jsonResponse(reply);
  },
};
```

- [ ] **Step 3: 写 README 部署说明**

创建 `backend/agent-proxy/README.md`：

````markdown
# voxlue agent 代理

voxlue v1 唯一自建服务端：一个极薄、无状态、无数据库的 Cloudflare Worker。
持有大模型 API key（作为 Worker secret），把设备端的脱敏摘要转发给大模型。
**设备端永不内嵌 key。**

## 本地开发

```bash
cd backend/agent-proxy
npm install
# 本地开发时把 key 放进 .dev.vars（已被 .gitignore，绝不入库）：
echo 'MODEL_API_KEY = "sk-你的key"' > .dev.vars
npm run dev          # 本地起在 http://localhost:8787
npm run typecheck    # 类型检查
```

## 部署步骤

1. 安装并登录 Cloudflare：

   ```bash
   npm install
   npx wrangler login
   ```

2. **把大模型 API key 设为 secret**（不写进任何文件、不入代码库）：

   ```bash
   npx wrangler secret put MODEL_API_KEY
   # 终端会提示粘贴 key，输入后回车 —— key 加密存于 Cloudflare，代码与仓库都看不到它。
   ```

3. 部署：

   ```bash
   npm run deploy
   ```

   部署成功后终端打印 Worker 地址，形如
   `https://voxlue-agent-proxy.<你的子域>.workers.dev`。

4. 把该地址填进 App 端 `HTTPRemoteModelClient(proxyURL:)` 的注入点
   （见计划 06 Task 9 的依赖装配）。

## 切换大模型

`wrangler.toml` 的 `[vars]` 里改 `MODEL_ENDPOINT` 与 `MODEL_NAME` 即可
（默认 Anthropic Messages API）。换 OpenAI 时同时改 `src/index.ts` 里的
请求头与回复解析。key 始终走 `wrangler secret put`，不进 vars。

## 合规边界

- 代理只转发，不落库、不记请求正文。
- 越过网络边界的只有抽象 `StateDigest` + 非敏感胶囊元数据 —— 原始健康数据
  在设备端 `SignalDistiller` 就被拦下，永不到达此服务。
````

- [ ] **Step 4: 类型检查 Worker**

Run: `cd /Users/cornna/project/voxule/backend/agent-proxy && npm install && npm run typecheck`
Expected: `tsc --noEmit` 无报错退出（退出码 0，无输出即通过）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add backend/agent-proxy
git commit -m "feat(backend): 新增 agent 代理 Cloudflare Worker（无状态、持有 API key）"
```

---

## Task 9: BGTaskScheduler 接线 + 依赖装配 【协作者】

把计划 03 建好的 BGTaskScheduler 唤醒入口接到 `AgentGateway.runSurfacingCycle()`：安静时段后台被唤醒 → 跑一轮闭环 → 若 agent 决定浮现，`TriggerEngine.surface` 已在闭环内被调用、灵动岛随即起。同时在 App 壳层装配 agent 闭环的依赖图。

**Files:**
- Modify: `voxule/voxule/voxuleApp.swift`
- Create: `voxule/voxule/Agent/AgentContainer.swift`

- [ ] **Step 1: 建 agent 依赖容器**

创建 `voxule/voxule/Agent/AgentContainer.swift`：

```swift
import Foundation
import SwiftData
import VoxlueData
import VoxlueServices

/// agent 闭环的依赖装配点（App 壳层）。
/// MV 模式：直接持有具体服务，不套 ViewModel。
@MainActor
final class AgentContainer {
    let gateway: any AgentGatewaying
    let intelligence: any IntelligenceServicing

    /// 生产装配 —— 真服务 + 真代理。
    /// - Parameter proxyURL: serverless 代理地址（Task 8 部署后得到）。
    init(modelContext: ModelContext, proxyURL: URL) {
        let store = CapsuleStore(context: modelContext)
        #if canImport(HealthKit)
        let health: any HealthProviding = HealthKitHealthProvider()
        #else
        let health: any HealthProviding = FakeHealthProviding(snapshot: nil)
        #endif
        let distiller = SignalDistiller(health: health, store: store)
        let client = HTTPRemoteModelClient(proxyURL: proxyURL)
        // TriggerEngine 由计划 03 提供；这里取其在壳层已装配的实例。
        let trigger = TriggerEngineLocator.shared.engine(for: modelContext)
        self.gateway = AgentGateway(
            distiller: distiller, client: client, trigger: trigger, store: store
        )
        self.intelligence = IntelligenceService()
    }

    /// 预览/测试装配 —— 全假实现。
    init(previewDecision: SurfacingDecision = .hold) {
        self.gateway = FakeAgentGateway(decision: previewDecision)
        self.intelligence = FakeIntelligenceServicing(title: "窗外的雨声")
    }

    /// 后台唤醒入口 —— BGTaskScheduler 在安静时段调它。
    /// 跑一轮情绪浮现闭环；浮现决定已在闭环内派发给 TriggerEngine。
    func handleBackgroundSurfacing() async {
        do {
            let decision = try await gateway.runSurfacingCycle()
            switch decision {
            case .surface:
                break   // surface 已在闭环内调用 TriggerEngine.surface，灵动岛随即起。
            case .hold:
                break   // 本轮不打扰。
            }
        } catch {
            // 后台任务失败静默 —— 不打扰用户，下次唤醒再试。
        }
    }
}
```

> 说明：`TriggerEngineLocator` 是计划 03 在壳层建立的 TriggerEngine 单例定位点。若计划 03 的实际命名不同，按计划 03 已合入的命名取实例 —— 本计划只要求「拿到那个已装配的 `TriggerEngineProtocol` 实例」，不重新装配 TriggerEngine。

- [ ] **Step 2: 把 BGTask 唤醒接到闭环**

修改 `voxule/voxule/voxuleApp.swift` —— 在 `body` 的场景上挂 BGTask 处理。把现有文件改为：

```swift
//
//  voxuleApp.swift
//  voxule
//

import SwiftUI
import SwiftData
import BackgroundTasks
import VoxlueData
import VoxlueServices

@main
struct voxuleApp: App {
    private let modelContainer: ModelContainer

    /// serverless 代理地址 —— Task 8 部署后填入。
    private static let agentProxyURL = URL(string: "https://voxlue-agent-proxy.example.workers.dev")!

    /// 情绪浮现后台任务标识 —— 须与 Info.plist `BGTaskSchedulerPermittedIdentifiers` 一致。
    /// 该标识由计划 03 注册；本计划复用同一标识、接上 agent 闭环。
    static let surfacingTaskID = "com.voxlue.app.agent.surfacing"

    init() {
        if let cloudContainer = try? VoxlueModelContainer.make() {
            modelContainer = cloudContainer
        } else {
            do {
                modelContainer = try ModelContainer(
                    for: VoxlueModelContainer.schema,
                    configurations: ModelConfiguration(
                        schema: VoxlueModelContainer.schema,
                        cloudKitDatabase: .none
                    )
                )
            } catch {
                fatalError("无法创建本地 ModelContainer：\(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            DebugRootView()
        }
        .modelContainer(modelContainer)
        // 安静时段被唤醒 → 跑一轮 agent 情绪浮现闭环。
        .backgroundTask(.appRefresh(Self.surfacingTaskID)) {
            let context = await modelContainer.mainContext
            let container = await AgentContainer(
                modelContext: context, proxyURL: Self.agentProxyURL
            )
            await container.handleBackgroundSurfacing()
            await Self.scheduleNextSurfacing()
        }
    }

    /// 排下一次浮现唤醒。频率按 cadence 设置调整（轻轻地/偶尔/关）。
    static func scheduleNextSurfacing() async {
        let cadence = CadenceSetting.current
        guard cadence != .off else { return }   // 「关」则不再排。
        let request = BGAppRefreshTaskRequest(identifier: surfacingTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: cadence.interval)
        try? BGTaskScheduler.shared.submit(request)
    }
}
```

> 说明：`.backgroundTask(.appRefresh:)` 的标识必须已在 Info.plist `BGTaskSchedulerPermittedIdentifiers` 登记 —— 该登记由计划 03 完成。本计划只是把唤醒处理体换成 agent 闭环。`CadenceSetting` 在 Task 11 定义。

- [ ] **Step 3: 构建 App 确认接线无误**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
（在仓库根 `/Users/cornna/project/voxule` 下执行）
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Agent/AgentContainer.swift voxule/voxule/voxuleApp.swift
git commit -m "feat(agent): BGTaskScheduler 唤醒接线到 AgentGateway 浮现闭环"
```

---

## Task 10: HealthKit 能力与隐私说明配置 【协作者】

给 App 加 HealthKit 能力、entitlement 与 Info.plist 隐私说明字符串。HealthKit 须显式授权（架构文档 §10），隐私文案定位「陪伴」，严禁临床措辞。

**Files:**
- Modify: `voxule/voxule/voxule.entitlements`
- Modify: Xcode 工程构建设置（Info.plist 键）

- [ ] **Step 1: 加 HealthKit 能力**

在 Xcode：TARGETS ▸ voxule ▸ Signing & Capabilities ▸ `+ Capability` ▸ 添加 **HealthKit**。这会向 `voxule/voxule/voxule.entitlements` 写入 `com.apple.developer.healthkit` 键。确认 entitlements 文件含：

```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
```

- [ ] **Step 2: 加隐私说明字符串**

在 Xcode：TARGETS ▸ voxule ▸ Build Settings ▸ 搜 `INFOPLIST_KEY` ▸ 用 `+` 加一条自定义键，或直接在 Info 标签页加。须加 `NSHealthShareUsageDescription`，值为：

```
voxlue 读取你的心情、心率与睡眠记录，只为在合适的安静时刻陪你重听一段你埋下的声音。这些数据全程留在你的设备上，永不上传。
```

> 文案审查：此句定位「陪伴」「重听」，无「治疗/诊断/评估/改善」任何临床词。HealthKit 不写入数据，故不需要 `NSHealthUpdateUsageDescription`。

- [ ] **Step 3: 构建确认能力配置无误**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
（在仓库根 `/Users/cornna/project/voxule` 下执行）
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/voxule.entitlements voxule/voxule.xcodeproj
git commit -m "chore(agent): 配置 HealthKit 能力与隐私说明文案"
```

---

## Task 11: cadence 设置与浮现频率持久化 【前端】

做 cadence 设置界面（轻轻地 / 偶尔 / 关，架构文档 §6）与其持久化。`CadenceSetting` 是 Task 9 后台排程读取的频率源。

**Files:**
- Create: `voxule/voxule/Agent/CadenceSettingsView.swift`

- [ ] **Step 1: 实现 CadenceSetting 与设置界面**

创建 `voxule/voxule/Agent/CadenceSettingsView.swift`：

```swift
import SwiftUI

/// 情绪胶囊浮现频率（架构文档 §6）。用户可调，「关」则 agent 不再主动浮现。
enum CadenceSetting: String, CaseIterable, Identifiable {
    case gentle = "gentle"        // 轻轻地
    case occasionally = "occasionally"  // 偶尔
    case off = "off"              // 关

    var id: String { rawValue }

    /// 显示名 —— 陪伴语气，无临床措辞。
    var label: String {
        switch self {
        case .gentle: "轻轻地"
        case .occasionally: "偶尔"
        case .off: "关"
        }
    }

    /// 一句说明。
    var caption: String {
        switch self {
        case .gentle: "更常浮现，像偶尔路过的旧友"
        case .occasionally: "久一点才浮现一次"
        case .off: "不再主动浮现；你随时能在 App 里手动打开"
        }
    }

    /// 后台唤醒的最短间隔（秒）。
    var interval: TimeInterval {
        switch self {
        case .gentle: 60 * 60 * 24          // 约一天
        case .occasionally: 60 * 60 * 24 * 4 // 约四天
        case .off: .infinity
        }
    }

    private static let storageKey = "voxlue.cadence"

    /// 当前设置 —— 持久化在 UserDefaults，后台排程与设置界面共用。
    static var current: CadenceSetting {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey)
            return raw.flatMap(CadenceSetting.init(rawValue:)) ?? .occasionally
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}

/// cadence 设置界面。
struct CadenceSettingsView: View {
    @State private var selection = CadenceSetting.current

    var body: some View {
        Form {
            Section {
                ForEach(CadenceSetting.allCases) { cadence in
                    Button {
                        selection = cadence
                        CadenceSetting.current = cadence
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cadence.label)
                                    .foregroundStyle(.primary)
                                Text(cadence.caption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if cadence == selection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("浮现频率")
            } footer: {
                Text("情绪胶囊由陪伴 agent 在安静时刻为你浮现。这是陪伴，不是提醒事项 —— 你随时可以调慢，或关掉。")
            }
        }
        .navigationTitle("浮现")
    }
}

#Preview {
    NavigationStack { CadenceSettingsView() }
}
```

- [ ] **Step 2: 构建确认**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Agent/CadenceSettingsView.swift
git commit -m "feat(agent): 新增 cadence 浮现频率设置界面"
```

---

## Task 12: HealthKit 授权与隐私说明界面 【前端】

做 HealthKit 授权引导界面：清楚说明读什么、为什么、数据去哪（架构文档 §10）。文案定位「陪伴」，严禁临床措辞。

**Files:**
- Create: `voxule/voxule/Agent/HealthAuthorizationView.swift`

- [ ] **Step 1: 实现授权界面**

创建 `voxule/voxule/Agent/HealthAuthorizationView.swift`：

```swift
import SwiftUI
import VoxlueServices

/// HealthKit 授权与隐私说明界面。
/// 显式授权（架构文档 §10）：先讲清楚，再请求。
struct HealthAuthorizationView: View {
    /// 注入的 HealthKit wrapper —— 生产传真实现，预览传假实现。
    let health: any HealthProviding
    /// 授权完成回调。
    var onFinish: (Bool) -> Void = { _ in }

    @State private var requesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("让陪伴恰到好处")
                    .font(.title2.weight(.semibold))

                Text("voxlue 想读一点你的状态 —— 心情、心率与睡眠 —— 只为在一个合适的安静时刻，把你埋下的某段声音轻轻递到你面前。")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    privacyRow(icon: "iphone",
                               text: "原始数据全程留在你的设备上，永不上传。")
                    privacyRow(icon: "wand.and.sparkles",
                               text: "上网的只是一份抽象摘要，无法回指到你的任何具体读数。")
                    privacyRow(icon: "hand.raised",
                               text: "这是陪伴，不做任何健康判断。你随时可以在系统设置里收回授权。")
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task {
                        requesting = true
                        let granted = await health.requestAuthorization()
                        requesting = false
                        onFinish(granted)
                    }
                } label: {
                    Text(requesting ? "请求中…" : "继续")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(requesting)

                Button("以后再说") { onFinish(false) }
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("陪伴授权")
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(text)
                .font(.callout)
        }
    }
}

#Preview {
    NavigationStack {
        HealthAuthorizationView(health: FakeHealthProviding(snapshot: nil))
    }
}
```

- [ ] **Step 2: 构建确认**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Agent/HealthAuthorizationView.swift
git commit -m "feat(agent): 新增 HealthKit 授权与隐私说明界面"
```

---

## Task 13: 浮现卡界面 【前端】

做浮现卡 —— 一枚被 agent 浮现的情绪胶囊的呈现。它由灵动岛/通知点开后进入，是 agent 闭环在前端的落点。

**Files:**
- Create: `voxule/voxule/Agent/SurfacedCapsuleView.swift`

- [ ] **Step 1: 实现浮现卡**

创建 `voxule/voxule/Agent/SurfacedCapsuleView.swift`：

```swift
import SwiftUI
import SwiftData
import VoxlueData

/// 浮现卡 —— 一枚被陪伴 agent 浮现的情绪胶囊。
/// 由灵动岛/通知点开进入；agent 闭环在前端的落点。
struct SurfacedCapsuleView: View {
    /// 被浮现胶囊的 id（agent 决定，经深链传入）。
    let capsuleID: UUID

    @Environment(\.modelContext) private var context
    @Query private var capsules: [VoxlueData.Capsule]

    init(capsuleID: UUID) {
        self.capsuleID = capsuleID
        _capsules = Query(filter: #Predicate { $0.id == capsuleID })
    }

    private var capsule: VoxlueData.Capsule? { capsules.first }

    var body: some View {
        VStack(spacing: 24) {
            if let capsule {
                Spacer()
                Text("一段你埋下的声音，浮上来了")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                    .font(.title.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let place = capsule.placeName {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    let store = CapsuleStore(context: context)
                    try? store.updateState(capsule, to: .opened)
                } label: {
                    Label("听听看", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("不急。它会一直在这里，等你想听的时候。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                ContentUnavailableView("这枚胶囊不在了", systemImage: "questionmark.circle")
            }
        }
        .padding(32)
    }
}

#Preview {
    let container = try! VoxlueModelContainer.make(inMemory: true)
    let capsule = VoxlueData.Capsule(title: "外婆喊吃饭", lock: .mood(notBefore: nil))
    container.mainContext.insert(capsule)
    return SurfacedCapsuleView(capsuleID: capsule.id)
        .modelContainer(container)
}
```

- [ ] **Step 2: 构建确认**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Agent/SurfacedCapsuleView.swift
git commit -m "feat(agent): 新增浮现卡界面"
```

---

## Task 14: 临床措辞合规扫描 【协作者】

架构文档 §10 硬约束：全产品定位「陪伴」，严禁「治疗/诊断/评估/改善症状」一类临床措辞。本任务对所有 UI 文案与 agent 提示词做一次正则扫描，作为可重复执行的合规闸门。

**Files:**
- Create: `scripts/check-clinical-words.sh`

- [ ] **Step 1: 写合规扫描脚本**

创建 `scripts/check-clinical-words.sh`：

```bash
#!/usr/bin/env bash
# 临床措辞合规扫描（架构文档 §10）。
# 产品定位「陪伴」，UI 文案与 agent 提示词严禁出现临床/医疗措辞。
# 命中任一禁用词即失败退出。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 禁用词 —— 临床/医疗语义。
FORBIDDEN='治疗|诊断|评估|改善症状|疗效|症状|病情|医疗建议|心理咨询|抑郁|焦虑症'

# 扫描范围：App 端 UI 文案、agent 提示词、隐私说明。
TARGETS=(
  "$ROOT/voxule/voxule"
  "$ROOT/VoxlueKit/Sources/VoxlueServices"
  "$ROOT/backend/agent-proxy/src"
)

hits=0
for dir in "${TARGETS[@]}"; do
  [ -d "$dir" ] || continue
  if grep -rnE "$FORBIDDEN" "$dir" --include='*.swift' --include='*.ts' \
       --include='*.strings' 2>/dev/null; then
    hits=1
  fi
done

if [ "$hits" -ne 0 ]; then
  echo "❌ 发现临床措辞 —— 产品定位「陪伴」，请改为非临床表达。"
  exit 1
fi
echo "✅ 未发现临床措辞，文案合规。"
```

- [ ] **Step 2: 运行扫描，确认通过**

Run: `chmod +x /Users/cornna/project/voxule/scripts/check-clinical-words.sh && /Users/cornna/project/voxule/scripts/check-clinical-words.sh`
Expected: 输出 `✅ 未发现临床措辞，文案合规。`，退出码 0

> 若命中：到对应文件把临床词改成陪伴语气（如「评估你的状态」→「读一点你的状态」），重跑直到通过。

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add scripts/check-clinical-words.sh
git commit -m "chore(agent): 新增临床措辞合规扫描脚本"
```

---

## Task 15: 全量回归与端到端验证 【协作者】

跑全包测试、构建 App、跑合规扫描、类型检查 Worker，确认 agent 闭环 v1 整体绿。

**Files:** 无新增，仅验证。

- [ ] **Step 1: 全包测试**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 末行 `Test run with N tests passed` —— 含计划 01/02/03 已有测试 + 本计划 21 个新测试（StateDigest 3 + SignalDistiller 6 + RemoteModelClient 5 + AgentGateway 4 + IntelligenceService 3），全绿。

- [ ] **Step 2: App 无签名构建**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
（在仓库根 `/Users/cornna/project/voxule` 下执行）
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 合规扫描**

Run: `/Users/cornna/project/voxule/scripts/check-clinical-words.sh`
Expected: `✅ 未发现临床措辞，文案合规。`

- [ ] **Step 4: Worker 类型检查**

Run: `cd /Users/cornna/project/voxule/backend/agent-proxy && npm run typecheck`
Expected: `tsc --noEmit` 无报错退出（退出码 0）

- [ ] **Step 5: 模拟器端到端走查**

在 Xcode 用 iPhone 17 模拟器运行 App。手动验证（接线已在前序 Task 完成，此处确认 UI 可达）：
- 打开 `HealthAuthorizationView` —— 隐私说明三条清晰、文案无临床词。
- 打开 `CadenceSettingsView` —— 三档可切换，重启 App 后选择保持（UserDefaults 持久化）。
- 用 `FakeAgentGateway(decision: .surface(...))` 驱动 `SurfacedCapsuleView` 预览 —— 浮现卡正常显示、「听听看」可推进状态到 `opened`。

- [ ] **Step 6: 收尾提交（如有走查中的微调）**

```bash
cd /Users/cornna/project/voxule
git add -A
git commit -m "test(agent): 计划 06 全量回归与端到端验证通过"
```

---

## 完成标准

- `swift test`（`VoxlueKit` 包）全绿，含本计划 21 个新测试。
- 关键合规测试通过：`stateDigestJSONContainsNoRawHealthValues`、`distilledDigestCarriesNoRawHealthValues` —— 证明越过网络边界的 `StateDigest` 只含抽象 `Level` 与计数，无任何原始体征值。
- `RemoteModelClient` 不内嵌 API key，`fakeClientRecordsRequestForKeyLeakAssertion` 通过。
- agent 闭环用 `FakeRemoteModelClient` 脚本端到端可验：`AgentGateway` 派发工具调用、`runSurfacingCycle()` 返回正确的 `SurfacingDecision`；触顶不死循环。
- App 在 iPhone 17 模拟器无签名构建 `** BUILD SUCCEEDED **`。
- serverless 代理 Worker 类型检查通过；`backend/agent-proxy/README.md` 给出完整部署步骤与 `wrangler secret put` 设密钥说明。
- BGTaskScheduler 唤醒已接到 `AgentGateway.runSurfacingCycle()`；cadence 设置可调并持久化。
- HealthKit 能力 + entitlement + `NSHealthShareUsageDescription` 已配置；隐私文案定位「陪伴」。
- `scripts/check-clinical-words.sh` 通过 —— 全产品 UI 文案与 agent 提示词无「治疗/诊断/评估/改善症状」临床措辞。
- 全部改动已提交 git。

至此架构文档 §11「v1 核心·必做」的「云端 agent 闭环（脱敏闸门→agent→显影）」与「HealthKit 信号接入」两项完成，方向 C（声音情绪疗愈）的陪伴叙事在 v1 完整跑通：BGTask 唤醒 → 脱敏 → 云端 agent 判断 → 浮现卡。v1 核心六份计划全部落地。
