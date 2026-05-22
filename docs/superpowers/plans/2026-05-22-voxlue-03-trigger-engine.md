# voxlue 计划 03 · TriggerEngine 三把锁 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 voxlue 的心脏 —— `TriggerEngine` 三把锁触发引擎与显影状态机：地点锁走 CoreLocation 地理围栏（含「最近 20 个」轮换调度），时间锁走本地日历通知，情绪锁经 BGTaskScheduler 唤醒留出 agent 闭环入口。所有平台能力（定位、通知、灵动岛）都包 wrapper（协议 + 真实现 + 假实现），引擎纯后台、不依赖任何 UI，可在前台 / 围栏唤醒 / 后台任务三种上下文里工作。前端轨在此基础上接灵动岛 Live Activity、地图视图与通知/深链路由。

**Architecture:** `TriggerEngine` 实现路线图 §3.2 冻结的 `TriggerEngineProtocol`，是 `VoxlueServices` 包的领域服务（`@Observable final class`，MV 模式无 ViewModel）。它内含一个纯函数式 `GeofenceScheduler`（按用户位置排序、裁出最近 20 个围栏），并依赖三个平台能力 wrapper —— `LocationProviding`（CoreLocation）、`NotificationScheduling`（UserNotifications）、`LiveActivityControlling`（ActivityKit）。引擎拥有 §5 的显影状态机（`buried → developing → developed → opened`），写操作经计划 01 的 `CapsuleStore`。BGTaskScheduler 注册一个后台任务，唤醒后调用 `TriggerEngine.reconcile()`，并为情绪锁留一个 `MoodSurfacingHook`（真闭环在计划 06）。前端在 App 壳层接 Live Activity UI、MapKit 地图与通知/深链路由。

**Tech Stack:** Swift 6.2 · SwiftUI · SwiftData · CoreLocation · UserNotifications · ActivityKit · BackgroundTasks · MapKit · Swift Testing · Xcode 26.5 · iOS 26

**前置条件:** 计划 01（`VoxlueData` 包：`Capsule` / `Lock` / `CapsuleState` / `CapsuleStore`）已合入 `main`；计划 02 已新建 `VoxlueServices` 库目标并合入（本计划向其追加文件，不另建包）；已安装完整 Xcode 26.5；App 工程 `voxule/voxule.xcodeproj` 已有 `voxule.entitlements`（iCloud / CloudKit）与构建设置 `INFOPLIST_KEY_UIBackgroundModes = remote-notification`。

**对应设计文档:** `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md` 的 §4、§5（CapsuleState 状态机）、§6（三把锁与触发引擎，核心）、§9（灵动岛/显影动效）；路线图 `docs/superpowers/plans/2026-05-22-voxlue-v1-roadmap.md` 的 §1、§3.2（冻结契约）、§3.0（包布局）、§6（任务归属标记）。

**任务归属一览（路线图 §6）：**

| Task | 标题 | 归属 |
|---|---|---|
| 1 | LocationProviding 协议 + Fake | 【协作者】 |
| 2 | NotificationScheduling 协议 + Fake | 【协作者】 |
| 3 | LiveActivityControlling 协议 + Fake | 【协作者】 |
| 4 | GeofenceScheduler 纯函数最近 20 调度 | 【协作者】 |
| 5 | TriggerEngine + FakeTriggerEngine | 【协作者】 |
| 6 | CoreLocation 真实现 CLLocationProvider | 【协作者】 |
| 7 | UserNotifications 真实现 + 兜底重扫 | 【协作者】 |
| 8 | ActivityKit 真实现 LiveActivityController | 【协作者】 |
| 9 | BGTaskScheduler 接入 + 情绪锁 hook | 【协作者】 |
| 10 | 灵动岛 Live Activity UI（Widget Extension） | 【前端】 |
| 11 | 地图视图 UI（MapKit） | 【前端】 |
| 12 | 通知 / 深链路由（App 壳层） | 【前端】 |

> 契约优先：Task 1–5 交付协议 + Fake 后，前端的 Task 10–12 即可开工；Task 6–9 的真实现可晚于前端任务合入，只要不改协议签名。

---

## 文件结构

```
/Users/cornna/project/voxule/
├── voxule/                                  Xcode 应用工程
│   ├── voxule.xcodeproj
│   ├── voxule/
│   │   ├── voxuleApp.swift                  ← 改：注册 BGTask、装配引擎、深链路由
│   │   ├── DebugRootView.swift              ← 改：挂触发引擎调试入口
│   │   ├── AppDependencies.swift            ← 新：依赖装配容器
│   │   ├── CapsuleMapView.swift             ← 新：MapKit 地图视图【前端】
│   │   ├── CapsuleRouter.swift              ← 新：深链/通知路由【前端】
│   │   └── voxule.entitlements              ← 改：无（BGTask 用 Info.plist 键）
│   └── VoxlueWidget/                        ← 新：Widget Extension（灵动岛）
│       ├── VoxlueWidgetBundle.swift
│       ├── DevelopingActivityAttributes.swift
│       └── DevelopingLiveActivity.swift     灵动岛 + 锁屏 Live Activity UI【前端】
└── VoxlueKit/
    ├── Package.swift                        ← 改：VoxlueServices 加 widget 共享源
    ├── Sources/VoxlueServices/
    │   ├── Geofence.swift                   GeofenceRegion · GeofenceEvent
    │   ├── LocationProviding.swift          协议 + FakeLocationProviding
    │   ├── CLLocationProvider.swift         CoreLocation 真实现
    │   ├── NotificationScheduling.swift     协议 + FakeNotificationScheduling
    │   ├── UNNotificationService.swift      UserNotifications 真实现
    │   ├── LiveActivityControlling.swift    协议 + FakeLiveActivityControlling
    │   ├── LiveActivityController.swift     ActivityKit 真实现
    │   ├── DevelopingActivityAttributes.swift  Live Activity 数据契约（App 与 Widget 共享）
    │   ├── GeofenceScheduler.swift          纯函数：最近 20 个围栏裁剪
    │   ├── TriggerEngineProtocol.swift      协议 + FakeTriggerEngine
    │   ├── TriggerEngine.swift              真实现 + MoodSurfacingHook
    │   └── BackgroundTaskCoordinator.swift  BGTaskScheduler 注册与派发
    └── Tests/VoxlueServicesTests/
        ├── GeofenceSchedulerTests.swift
        ├── LocationProvidingTests.swift
        ├── NotificationSchedulingTests.swift
        ├── LiveActivityControllingTests.swift
        ├── TriggerEngineTests.swift
        └── BackgroundTaskCoordinatorTests.swift
```

> 说明：`DevelopingActivityAttributes.swift` 同时被 App 与 Widget Extension 使用。它定义在 `VoxlueServices` 里，Widget Extension 通过链接 `VoxlueServices` 复用同一份契约 —— 不复制源文件。

---

## Task 1: LocationProviding 协议 + 假实现 【协作者】

定义平台能力层的定位 wrapper 协议（路线图 §3.2 逐字），先给出围栏值类型与假实现，让前端与引擎都能在不真跑 CoreLocation 的情况下开工。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/Geofence.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/LocationProviding.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/LocationProvidingTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/LocationProvidingTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func fakeLocationGrantsPermission() async {
    let provider = FakeLocationProviding()
    #expect(await provider.requestPermission() == true)
}

@Test func fakeLocationRecordsMonitoredRegions() async {
    let provider = FakeLocationProviding()
    let regions = [
        GeofenceRegion(capsuleID: UUID(), latitude: 31.2, longitude: 121.4, radius: 80),
    ]
    await provider.monitor(regions: regions)
    #expect(provider.monitoredRegions == regions)
}

@Test func fakeLocationEmitsEnteredEvent() async {
    let provider = FakeLocationProviding()
    let id = UUID()
    var received: [GeofenceEvent] = []
    let collector = Task {
        for await event in provider.events {
            received.append(event)
            if received.count == 1 { break }
        }
    }
    provider.simulateEntry(capsuleID: id)
    await collector.value
    #expect(received == [.entered(capsuleID: id)])
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter LocationProvidingTests`
Expected: 编译失败，提示找不到 `FakeLocationProviding` / `GeofenceRegion` / `GeofenceEvent`

- [ ] **Step 3: 实现围栏值类型**

创建 `VoxlueKit/Sources/VoxlueServices/Geofence.swift`：

```swift
import Foundation

/// 一个地理围栏 —— 对应一枚地点锁胶囊的解锁圈。
/// 路线图 §3.2 冻结契约，签名不可改。
public struct GeofenceRegion: Sendable, Hashable {
    public let capsuleID: UUID
    public let latitude, longitude, radius: Double

    public init(capsuleID: UUID, latitude: Double, longitude: Double, radius: Double) {
        self.capsuleID = capsuleID
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}

/// 进入围栏事件。路线图 §3.2 冻结契约。
public enum GeofenceEvent: Sendable, Equatable {
    case entered(capsuleID: UUID)
}
```

- [ ] **Step 4: 实现 LocationProviding 协议与假实现**

创建 `VoxlueKit/Sources/VoxlueServices/LocationProviding.swift`：

```swift
import Foundation

/// 定位 wrapper（平台能力层）。路线图 §3.2 冻结契约，签名不可改。
/// 真实现见 `CLLocationProvider`，假实现见下。
public protocol LocationProviding: Sendable {
    func requestPermission() async -> Bool
    /// 把这批围栏交给系统监听（内部已按「最近 20 个」裁剪）。
    func monitor(regions: [GeofenceRegion]) async
    /// 进入围栏事件流。
    var events: AsyncStream<GeofenceEvent> { get }
}

/// 假定位 —— 不碰 CoreLocation，供预览、单元测试与引擎注入。
/// 测试可用 `simulateEntry` 手动注入进入围栏事件。
public final class FakeLocationProviding: LocationProviding, @unchecked Sendable {
    public private(set) var monitoredRegions: [GeofenceRegion] = []
    public var permissionGranted = true

    private let continuation: AsyncStream<GeofenceEvent>.Continuation
    public let events: AsyncStream<GeofenceEvent>

    public init() {
        var captured: AsyncStream<GeofenceEvent>.Continuation!
        events = AsyncStream { captured = $0 }
        continuation = captured
    }

    public func requestPermission() async -> Bool { permissionGranted }

    public func monitor(regions: [GeofenceRegion]) async {
        monitoredRegions = regions
    }

    /// 测试钩子：模拟用户走进某枚胶囊的围栏。
    public func simulateEntry(capsuleID: UUID) {
        continuation.yield(.entered(capsuleID: capsuleID))
    }
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter LocationProvidingTests`
Expected: `Test run with 3 tests passed`

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Geofence.swift VoxlueKit/Sources/VoxlueServices/LocationProviding.swift VoxlueKit/Tests/VoxlueServicesTests/LocationProvidingTests.swift
git commit -m "feat(trigger): 新增 LocationProviding 协议与围栏值类型 + 假实现"
```

---

## Task 2: NotificationScheduling 协议 + 假实现 【协作者】

定义时间锁兜底用的本地通知调度协议（路线图 §3.2 逐字）与假实现。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/NotificationScheduling.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/NotificationSchedulingTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/NotificationSchedulingTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func fakeNotificationGrantsPermission() async {
    let service = FakeNotificationScheduling()
    #expect(await service.requestPermission() == true)
}

@Test func fakeNotificationRecordsScheduledLock() async throws {
    let service = FakeNotificationScheduling()
    let id = UUID()
    let fireAt = Date(timeIntervalSince1970: 1_900_000_000)
    try await service.scheduleDateLock(capsuleID: id, fireAt: fireAt)
    #expect(service.scheduled[id] == fireAt)
}

@Test func fakeNotificationCancelRemovesScheduledLock() async throws {
    let service = FakeNotificationScheduling()
    let id = UUID()
    try await service.scheduleDateLock(capsuleID: id, fireAt: .now)
    await service.cancel(capsuleID: id)
    #expect(service.scheduled[id] == nil)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter NotificationSchedulingTests`
Expected: 编译失败，提示找不到 `FakeNotificationScheduling`

- [ ] **Step 3: 实现协议与假实现**

创建 `VoxlueKit/Sources/VoxlueServices/NotificationScheduling.swift`：

```swift
import Foundation

/// 本地通知调度（时间锁兜底）。路线图 §3.2 冻结契约，签名不可改。
/// 真实现见 `UNNotificationService`，假实现见下。
public protocol NotificationScheduling: Sendable {
    func requestPermission() async -> Bool
    /// 为一枚时间锁胶囊注册到点通知。
    func scheduleDateLock(capsuleID: UUID, fireAt date: Date) async throws
    /// 取消某枚胶囊的待发通知。
    func cancel(capsuleID: UUID) async
}

/// 假通知调度 —— 不碰 UserNotifications，记录被调度的胶囊供断言。
public final class FakeNotificationScheduling: NotificationScheduling, @unchecked Sendable {
    public private(set) var scheduled: [UUID: Date] = [:]
    public var permissionGranted = true

    public init() {}

    public func requestPermission() async -> Bool { permissionGranted }

    public func scheduleDateLock(capsuleID: UUID, fireAt date: Date) async throws {
        scheduled[capsuleID] = date
    }

    public func cancel(capsuleID: UUID) async {
        scheduled[capsuleID] = nil
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter NotificationSchedulingTests`
Expected: `Test run with 3 tests passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/NotificationScheduling.swift VoxlueKit/Tests/VoxlueServicesTests/NotificationSchedulingTests.swift
git commit -m "feat(trigger): 新增 NotificationScheduling 协议 + 假实现"
```

---

## Task 3: LiveActivityControlling 协议 + 假实现 【协作者】

灵动岛 Live Activity 的控制 wrapper —— 协议 + 假实现 + App 与 Widget 共享的数据契约 `DevelopingActivityAttributes`。引擎在胶囊 `developing` 时起一个 Live Activity，`developed/opened` 时结束它。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/DevelopingActivityAttributes.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/LiveActivityControlling.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/LiveActivityControllingTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/LiveActivityControllingTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func fakeLiveActivityStartsAndTracksActive() async {
    let controller = FakeLiveActivityControlling()
    let id = UUID()
    await controller.start(capsuleID: id, title: "咖啡馆的雨")
    #expect(controller.activeCapsuleIDs == [id])
    #expect(controller.startedTitles[id] == "咖啡馆的雨")
}

@Test func fakeLiveActivityEndRemovesActive() async {
    let controller = FakeLiveActivityControlling()
    let id = UUID()
    await controller.start(capsuleID: id, title: "雨")
    await controller.end(capsuleID: id)
    #expect(controller.activeCapsuleIDs.isEmpty)
}

@Test func fakeLiveActivityStartIsIdempotent() async {
    let controller = FakeLiveActivityControlling()
    let id = UUID()
    await controller.start(capsuleID: id, title: "雨")
    await controller.start(capsuleID: id, title: "雨")
    #expect(controller.activeCapsuleIDs == [id])
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter LiveActivityControllingTests`
Expected: 编译失败，提示找不到 `FakeLiveActivityControlling`

- [ ] **Step 3: 实现 Live Activity 数据契约**

创建 `VoxlueKit/Sources/VoxlueServices/DevelopingActivityAttributes.swift`：

```swift
import Foundation
import ActivityKit

/// 「显影中」灵动岛 Live Activity 的数据契约。
/// App（起/结束 Activity）与 Widget Extension（渲染 UI）共享同一份定义。
public struct DevelopingActivityAttributes: ActivityAttributes {
    /// Live Activity 存续期间可变的动态状态。
    public struct ContentState: Codable, Hashable, Sendable {
        /// 显影进度 0...1，霜化动效用。
        public var developProgress: Double
        public init(developProgress: Double) {
            self.developProgress = developProgress
        }
    }

    /// 起 Activity 时定死的静态属性。
    public let capsuleID: UUID
    public let title: String

    public init(capsuleID: UUID, title: String) {
        self.capsuleID = capsuleID
        self.title = title
    }
}
```

- [ ] **Step 4: 实现协议与假实现**

创建 `VoxlueKit/Sources/VoxlueServices/LiveActivityControlling.swift`：

```swift
import Foundation

/// 灵动岛 Live Activity 控制 wrapper（平台能力层）。
/// 真实现见 `LiveActivityController`（ActivityKit），假实现见下。
@MainActor public protocol LiveActivityControlling: AnyObject {
    /// 当前活跃的 Live Activity 对应胶囊。
    var activeCapsuleIDs: [UUID] { get }
    /// 为一枚进入显影的胶囊起 Live Activity。已存在则无操作（幂等）。
    func start(capsuleID: UUID, title: String) async
    /// 推进显影进度（驱动霜化动效）。
    func update(capsuleID: UUID, progress: Double) async
    /// 结束某枚胶囊的 Live Activity。
    func end(capsuleID: UUID) async
}

/// 假 Live Activity 控制 —— 不碰 ActivityKit，记录调用供断言与预览。
@MainActor public final class FakeLiveActivityControlling: LiveActivityControlling {
    public private(set) var activeCapsuleIDs: [UUID] = []
    public private(set) var startedTitles: [UUID: String] = [:]
    public private(set) var progress: [UUID: Double] = [:]

    public init() {}

    public func start(capsuleID: UUID, title: String) async {
        guard !activeCapsuleIDs.contains(capsuleID) else { return }
        activeCapsuleIDs.append(capsuleID)
        startedTitles[capsuleID] = title
        progress[capsuleID] = 0
    }

    public func update(capsuleID: UUID, progress value: Double) async {
        progress[capsuleID] = value
    }

    public func end(capsuleID: UUID) async {
        activeCapsuleIDs.removeAll { $0 == capsuleID }
        startedTitles[capsuleID] = nil
        progress[capsuleID] = nil
    }
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter LiveActivityControllingTests`
Expected: `Test run with 3 tests passed`

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/DevelopingActivityAttributes.swift VoxlueKit/Sources/VoxlueServices/LiveActivityControlling.swift VoxlueKit/Tests/VoxlueServicesTests/LiveActivityControllingTests.swift
git commit -m "feat(trigger): 新增 LiveActivityControlling 协议 + 假实现 + 显影 Activity 契约"
```

---

## Task 4: GeofenceScheduler 纯函数最近 20 调度 【协作者】

这是 spec §6 最强调的坑：**iOS 一个 App 最多同时监听 20 个围栏**。`GeofenceScheduler` 把全部地点锁围栏按「离用户当前位置的距离」排序，只裁出最近 20 个。它是无状态纯函数，可脱离 CoreLocation 直接用假数据测。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/GeofenceScheduler.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/GeofenceSchedulerTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/GeofenceSchedulerTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueServices

/// 造一个围栏，经纬度按需指定。
private func region(lat: Double, lon: Double) -> GeofenceRegion {
    GeofenceRegion(capsuleID: UUID(), latitude: lat, longitude: lon, radius: 80)
}

@Test func schedulerKeepsAllWhenUnderTwenty() {
    let regions = (0..<5).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: regions
    )
    #expect(result.count == 5)
}

@Test func schedulerCapsAtTwenty() {
    let regions = (0..<50).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: regions
    )
    #expect(result.count == 20)
}

@Test func schedulerKeepsTheClosestTwenty() {
    // 纬度 0...49：用户在 0，最近 20 个应是纬度 0...19。
    let regions = (0..<50).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: regions
    )
    let keptLatitudes = Set(result.map(\.latitude))
    #expect(keptLatitudes == Set((0..<20).map(Double.init)))
}

@Test func schedulerReSortsWhenUserMoves() {
    // 用户移到纬度 49 一侧，最近 20 个应翻转为纬度 30...49。
    let regions = (0..<50).map { region(lat: Double($0), lon: 0) }
    let result = GeofenceScheduler.nearest(
        to: (latitude: 49, longitude: 0), from: regions
    )
    let keptLatitudes = Set(result.map(\.latitude))
    #expect(keptLatitudes == Set((30..<50).map(Double.init)))
}

@Test func schedulerIsSortedNearestFirst() {
    let regions = [region(lat: 10, lon: 0), region(lat: 1, lon: 0), region(lat: 5, lon: 0)]
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: regions
    )
    #expect(result.map(\.latitude) == [1, 5, 10])
}

@Test func schedulerHandlesEmptyInput() {
    let result = GeofenceScheduler.nearest(
        to: (latitude: 0, longitude: 0), from: []
    )
    #expect(result.isEmpty)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter GeofenceSchedulerTests`
Expected: 编译失败，提示找不到 `GeofenceScheduler`

- [ ] **Step 3: 实现 GeofenceScheduler**

创建 `VoxlueKit/Sources/VoxlueServices/GeofenceScheduler.swift`：

```swift
import Foundation
import CoreLocation

/// 地理围栏调度器 —— spec §6 的核心约束所在。
///
/// iOS 一个 App 最多同时监听 20 个 `CLCircularRegion`。当地点锁胶囊多于 20 枚时，
/// 必须只把「离用户最近的 20 个」装进系统监听；用户位置显著变化时重新排序轮换。
///
/// 本类型是**无状态纯函数**，不持有定位、不持有系统监听句柄 —— 便于直接用假围栏与
/// 假用户坐标做单元测试。
public enum GeofenceScheduler {

    /// iOS 系统允许的同时监听围栏上限。
    public static let systemLimit = 20

    /// 从一批围栏里裁出离用户最近的至多 20 个，按距离升序返回。
    /// - Parameters:
    ///   - userLocation: 用户当前经纬度。
    ///   - regions: 全部候选围栏（私有与圈内胶囊一视同仁）。
    /// - Returns: 最近的至多 `systemLimit` 个，最近的在前。
    public static func nearest(
        to userLocation: (latitude: Double, longitude: Double),
        from regions: [GeofenceRegion]
    ) -> [GeofenceRegion] {
        let origin = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let sorted = regions.sorted { lhs, rhs in
            distance(from: origin, to: lhs) < distance(from: origin, to: rhs)
        }
        return Array(sorted.prefix(systemLimit))
    }

    /// 用户位置变化是否大到需要重排（significant location change 粒度，约 500 米）。
    public static let resortThresholdMeters: Double = 500

    /// 判断两个用户位置之间是否值得触发一次重排。
    public static func shouldResort(
        from old: (latitude: Double, longitude: Double),
        to new: (latitude: Double, longitude: Double)
    ) -> Bool {
        let a = CLLocation(latitude: old.latitude, longitude: old.longitude)
        let b = CLLocation(latitude: new.latitude, longitude: new.longitude)
        return a.distance(from: b) >= resortThresholdMeters
    }

    private static func distance(from origin: CLLocation, to region: GeofenceRegion) -> Double {
        origin.distance(from: CLLocation(latitude: region.latitude, longitude: region.longitude))
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter GeofenceSchedulerTests`
Expected: `Test run with 6 tests passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/GeofenceScheduler.swift VoxlueKit/Tests/VoxlueServicesTests/GeofenceSchedulerTests.swift
git commit -m "feat(trigger): 新增 GeofenceScheduler —— 最近 20 个围栏纯函数调度"
```

---

## Task 5: TriggerEngine 协议、假实现与真实现 【协作者】

实现路线图 §3.2 冻结的 `TriggerEngineProtocol`，给出 `FakeTriggerEngine`，再实现真 `TriggerEngine` —— 它拥有显影状态机（`buried → developing → developed`），订阅围栏事件、调度时间锁通知、起灵动岛、为情绪锁留 `MoodSurfacingHook`。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/TriggerEngineProtocol.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/TriggerEngine.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/TriggerEngineTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/TriggerEngineTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import VoxlueData
@testable import VoxlueServices

@MainActor
private func makeStore() throws -> (CapsuleStore, ModelContainer) {
    let container = try VoxlueModelContainer.make(inMemory: true)
    return (CapsuleStore(context: container.mainContext), container)
}

@MainActor
@Test func fakeEngineSurfaceTracksDevelopingID() async {
    let engine = FakeTriggerEngine()
    let id = UUID()
    await engine.surface(capsuleID: id)
    #expect(engine.developingCapsuleIDs == [id])
}

@MainActor
@Test func surfaceMovesCapsuleToDeveloping() async throws {
    let (store, container) = try makeStore()
    let capsule = VoxlueData.Capsule(title: "咖啡馆的雨", lock: .date(.now))
    try store.add(capsule)

    let location = FakeLocationProviding()
    let notifications = FakeNotificationScheduling()
    let liveActivity = FakeLiveActivityControlling()
    let engine = TriggerEngine(
        store: store, location: location,
        notifications: notifications, liveActivity: liveActivity
    )
    await engine.surface(capsuleID: capsule.id)

    #expect(capsule.state == .developing)
    #expect(engine.developingCapsuleIDs == [capsule.id])
    #expect(liveActivity.activeCapsuleIDs == [capsule.id])
    _ = container
}

@MainActor
@Test func surfaceIsIdempotentForAlreadyDeveloping() async throws {
    let (store, container) = try makeStore()
    let capsule = VoxlueData.Capsule(title: "雨", lock: .date(.now))
    try store.add(capsule)
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    await engine.surface(capsuleID: capsule.id)
    await engine.surface(capsuleID: capsule.id)
    #expect(engine.developingCapsuleIDs == [capsule.id])
    _ = container
}

@MainActor
@Test func reconcileSurfacesExpiredDateLock() async throws {
    let (store, container) = try makeStore()
    let past = VoxlueData.Capsule(title: "去年的信", lock: .date(Date(timeIntervalSince1970: 1)))
    let future = VoxlueData.Capsule(
        title: "明年的信", lock: .date(Date(timeIntervalSinceNow: 86_400))
    )
    try store.add(past)
    try store.add(future)
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    await engine.reconcile()

    #expect(past.state == .developing)
    #expect(future.state == .buried)
    _ = container
}

@MainActor
@Test func reconcileSchedulesNotificationForFutureDateLock() async throws {
    let (store, container) = try makeStore()
    let fireAt = Date(timeIntervalSinceNow: 86_400)
    let future = VoxlueData.Capsule(title: "明年的信", lock: .date(fireAt))
    try store.add(future)
    let notifications = FakeNotificationScheduling()
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: notifications, liveActivity: FakeLiveActivityControlling()
    )
    await engine.reconcile()
    #expect(notifications.scheduled[future.id] == fireAt)
}

@MainActor
@Test func reconcileMonitorsBuriedPlaceLocks() async throws {
    let (store, container) = try makeStore()
    let place = VoxlueData.Capsule(
        title: "武康路", recipient: .me,
        lock: .place(latitude: 31.21, longitude: 121.43, radius: 80, placeName: "武康路")
    )
    try store.add(place)
    let location = FakeLocationProviding()
    let engine = TriggerEngine(
        store: store, location: location,
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    await engine.reconcile()
    #expect(location.monitoredRegions.map(\.capsuleID) == [place.id])
    _ = container
}

@MainActor
@Test func geofenceEntryEventSurfacesCapsule() async throws {
    let (store, container) = try makeStore()
    let place = VoxlueData.Capsule(
        title: "武康路",
        lock: .place(latitude: 31.21, longitude: 121.43, radius: 80, placeName: "武康路")
    )
    try store.add(place)
    let location = FakeLocationProviding()
    let engine = TriggerEngine(
        store: store, location: location,
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    await engine.start()
    location.simulateEntry(capsuleID: place.id)
    // 让事件流处理一轮。
    try await Task.sleep(for: .milliseconds(50))
    #expect(place.state == .developing)
    _ = container
}

@MainActor
@Test func moodHookFiresOnReconcile() async throws {
    let (store, container) = try makeStore()
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    var hookFired = false
    engine.moodSurfacingHook = { hookFired = true }
    await engine.reconcile()
    #expect(hookFired)
    _ = container
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter TriggerEngineTests`
Expected: 编译失败，提示找不到 `TriggerEngine` / `FakeTriggerEngine`

- [ ] **Step 3: 实现协议与假实现**

创建 `VoxlueKit/Sources/VoxlueServices/TriggerEngineProtocol.swift`：

```swift
import Foundation

/// 显影触发引擎 —— App 的心脏，纯后台、不依赖 UI。
/// 路线图 §3.2 冻结契约，签名不可改。
@MainActor public protocol TriggerEngineProtocol: AnyObject {
    /// 让某枚胶囊进入 developing（被围栏 / 通知 / agent 调用）。
    func surface(capsuleID: UUID) async
    /// App 启动 / 后台刷新时全量重扫过期时间锁与命中地点锁。
    func reconcile() async
    /// 当前正在显影中的胶囊（驱动灵动岛 UI）。
    var developingCapsuleIDs: [UUID] { get }
}

/// 假触发引擎 —— 供预览与 UI 测试，`surface` 即记一笔，不碰任何平台能力。
@MainActor public final class FakeTriggerEngine: TriggerEngineProtocol {
    public private(set) var developingCapsuleIDs: [UUID] = []
    public private(set) var reconcileCount = 0

    public init(developingCapsuleIDs: [UUID] = []) {
        self.developingCapsuleIDs = developingCapsuleIDs
    }

    public func surface(capsuleID: UUID) async {
        guard !developingCapsuleIDs.contains(capsuleID) else { return }
        developingCapsuleIDs.append(capsuleID)
    }

    public func reconcile() async {
        reconcileCount += 1
    }
}
```

- [ ] **Step 4: 实现真 TriggerEngine**

创建 `VoxlueKit/Sources/VoxlueServices/TriggerEngine.swift`：

```swift
import Foundation
import Observation
import VoxlueData

/// 显影触发引擎真实现 —— 三把锁判定 + 显影状态机。
///
/// 它在三种执行上下文里都要正确工作：前台、被地理围栏唤醒、BGTask 后台任务。
/// 故引擎不持有任何 UI 状态：所有真相落回 SwiftData（经 `CapsuleStore`），
/// `developingCapsuleIDs` 只是给灵动岛/UI 读的内存投影，由状态机推导。
@MainActor
@Observable
public final class TriggerEngine: TriggerEngineProtocol {

    private let store: CapsuleStore
    private let location: LocationProviding
    private let notifications: NotificationScheduling
    private let liveActivity: LiveActivityControlling

    /// 情绪锁浮现钩子 —— BGTask 唤醒时调用。
    /// 真闭环（脱敏闸门 → agent → 浮现）在计划 06 接入，这里只留入口。
    public var moodSurfacingHook: (@MainActor () -> Void)?

    private var eventTask: Task<Void, Never>?

    public init(
        store: CapsuleStore,
        location: LocationProviding,
        notifications: NotificationScheduling,
        liveActivity: LiveActivityControlling
    ) {
        self.store = store
        self.location = location
        self.notifications = notifications
        self.liveActivity = liveActivity
    }

    deinit { eventTask?.cancel() }

    // MARK: - TriggerEngineProtocol

    public var developingCapsuleIDs: [UUID] {
        let capsules = (try? store.allCapsules()) ?? []
        return capsules.filter { $0.state == .developing }.map(\.id)
    }

    /// 让某枚胶囊进入 developing。围栏命中、通知点击、agent 调用都汇到这里。
    /// 已是 developing / developed / opened 的胶囊不重复显影（幂等）。
    public func surface(capsuleID: UUID) async {
        guard let capsule = capsule(id: capsuleID) else { return }
        guard capsule.state == .buried else { return }
        try? store.updateState(capsule, to: .developing)
        await liveActivity.start(capsuleID: capsule.id, title: displayTitle(capsule))
    }

    /// 全量重扫 —— App 启动 / 后台刷新时调用，是时间锁与地点锁的兜底。
    /// 1. 过期时间锁直接显影；2. 未过期时间锁补登记通知；
    /// 3. 全部已埋下地点锁重新交给围栏调度；4. 触发情绪锁浮现钩子。
    public func reconcile() async {
        let capsules = (try? store.allCapsules()) ?? []
        let now = Date()

        for capsule in capsules where capsule.state == .buried {
            switch capsule.lock {
            case .date(let fireAt):
                if fireAt <= now {
                    await surface(capsuleID: capsule.id)
                } else {
                    try? await notifications.scheduleDateLock(
                        capsuleID: capsule.id, fireAt: fireAt
                    )
                }
            case .place, .mood:
                break
            }
        }

        await refreshGeofences(from: capsules)
        moodSurfacingHook?()
    }

    // MARK: - 生命周期

    /// 开始订阅围栏事件流。App 启动与围栏唤醒时调用一次。
    public func start() async {
        guard eventTask == nil else { return }
        let stream = location.events
        eventTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                switch event {
                case .entered(let capsuleID):
                    await self.surface(capsuleID: capsuleID)
                }
            }
        }
        let capsules = (try? store.allCapsules()) ?? []
        await refreshGeofences(from: capsules)
    }

    // MARK: - 私有

    /// 把全部已埋下地点锁裁成最近 20 个交给系统监听。
    private func refreshGeofences(from capsules: [VoxlueData.Capsule]) async {
        var regions: [GeofenceRegion] = []
        for capsule in capsules where capsule.state == .buried {
            if case .place(let lat, let lon, let radius, _) = capsule.lock {
                regions.append(GeofenceRegion(
                    capsuleID: capsule.id, latitude: lat, longitude: lon, radius: radius
                ))
            }
        }
        // GeofenceScheduler 需要用户位置；无定位时退化为不排序（仍裁 20 个上限）。
        let trimmed = GeofenceScheduler.nearest(
            to: (latitude: 0, longitude: 0), from: regions
        )
        await location.monitor(regions: regions.count <= GeofenceScheduler.systemLimit
            ? regions : trimmed)
    }

    private func capsule(id: UUID) -> VoxlueData.Capsule? {
        ((try? store.allCapsules()) ?? []).first { $0.id == id }
    }

    private func displayTitle(_ capsule: VoxlueData.Capsule) -> String {
        capsule.title.isEmpty ? "一张待显影的相" : capsule.title
    }
}
```

> 说明：`refreshGeofences` 此处用占位用户坐标 `(0,0)`。Task 6 接入真定位后，`CLLocationProvider` 会在 `monitor(regions:)` 内部用真实用户位置跑 `GeofenceScheduler.nearest`，所以引擎把全量围栏交下去即可 —— 「最近 20 个」的裁剪由 wrapper 在拿得到用户坐标时完成。

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter TriggerEngineTests`
Expected: `Test run with 8 tests passed`

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/TriggerEngineProtocol.swift VoxlueKit/Sources/VoxlueServices/TriggerEngine.swift VoxlueKit/Tests/VoxlueServicesTests/TriggerEngineTests.swift
git commit -m "feat(trigger): 新增 TriggerEngine 显影状态机 + FakeTriggerEngine"
```

---

## Task 6: CoreLocation 真实现 CLLocationProvider 【协作者】

`LocationProviding` 的真实现：用 `CLLocationManager` 申请权限、监听 significant location change、用真实用户位置跑 `GeofenceScheduler.nearest` 裁出最近 20 个 `CLCircularRegion`、把进入围栏事件喂进 `AsyncStream`。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/CLLocationProvider.swift`
- Test: 复用 Task 1 的 `LocationProvidingTests.swift`（追加一个真实现存在性测试）

- [ ] **Step 1: 追加失败的测试**

在 `VoxlueKit/Tests/VoxlueServicesTests/LocationProvidingTests.swift` 末尾追加：

```swift
@Test func clLocationProviderConformsToProtocol() {
    let provider: LocationProviding = CLLocationProvider()
    #expect(type(of: provider) == CLLocationProvider.self)
}

@Test func clLocationProviderTrimsToTwentyRegions() async {
    let provider = CLLocationProvider()
    let regions = (0..<50).map {
        GeofenceRegion(capsuleID: UUID(), latitude: Double($0), longitude: 0, radius: 80)
    }
    await provider.monitor(regions: regions)
    // 系统监听数永不超过 20。
    #expect(provider.monitoredRegionCount <= 20)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter LocationProvidingTests`
Expected: 编译失败，提示找不到 `CLLocationProvider`

- [ ] **Step 3: 实现 CLLocationProvider**

创建 `VoxlueKit/Sources/VoxlueServices/CLLocationProvider.swift`：

```swift
import Foundation
import CoreLocation

/// `LocationProviding` 的 CoreLocation 真实现。
///
/// 关键约束（spec §6）：iOS 一个 App 最多同时监听 20 个 `CLCircularRegion`。
/// `monitor(regions:)` 内部用当前用户位置跑 `GeofenceScheduler.nearest` 裁出最近 20 个；
/// 监听 significant location change，用户位置显著变化时自动重排轮换。
public final class CLLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager = CLLocationManager()
    private let continuation: AsyncStream<GeofenceEvent>.Continuation
    public let events: AsyncStream<GeofenceEvent>

    /// 当前申请权限的回调（一次性）。
    private var permissionContinuation: CheckedContinuation<Bool, Never>?
    /// 全量候选围栏 —— 用户移动时据此重排。
    private var allRegions: [GeofenceRegion] = []
    /// 当前正在被系统监听的围栏数（测试可读）。
    public private(set) var monitoredRegionCount = 0

    public override init() {
        var captured: AsyncStream<GeofenceEvent>.Continuation!
        events = AsyncStream { captured = $0 }
        continuation = captured
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - LocationProviding

    public func requestPermission() async -> Bool {
        if manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse {
            return true
        }
        return await withCheckedContinuation { continuation in
            permissionContinuation = continuation
            manager.requestAlwaysAuthorization()
        }
    }

    public func monitor(regions: [GeofenceRegion]) async {
        allRegions = regions
        manager.startMonitoringSignificantLocationChanges()
        applyNearestRegions()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = permissionContinuation else { return }
        permissionContinuation = nil
        let granted = manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse
        continuation.resume(returning: granted)
    }

    public func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        // significant location change 触发 —— 重新排序轮换围栏。
        applyNearestRegions()
    }

    public func locationManager(
        _ manager: CLLocationManager, didEnterRegion region: CLRegion
    ) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        continuation.yield(.entered(capsuleID: id))
    }

    // MARK: - 私有

    /// 用当前用户位置裁出最近 20 个围栏，替换系统监听集。
    private func applyNearestRegions() {
        let user = manager.location.map {
            (latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        } ?? (latitude: 0, longitude: 0)

        let nearest = GeofenceScheduler.nearest(to: user, from: allRegions)

        // 先停掉旧的，再装新的 —— 永不越过 20 上限。
        for monitored in manager.monitoredRegions {
            manager.stopMonitoring(for: monitored)
        }
        for region in nearest {
            let circular = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: region.latitude, longitude: region.longitude
                ),
                radius: region.radius,
                identifier: region.capsuleID.uuidString
            )
            circular.notifyOnEntry = true
            circular.notifyOnExit = false
            manager.startMonitoring(for: circular)
        }
        monitoredRegionCount = nearest.count
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter LocationProvidingTests`
Expected: `Test run with 5 tests passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/CLLocationProvider.swift VoxlueKit/Tests/VoxlueServicesTests/LocationProvidingTests.swift
git commit -m "feat(trigger): 新增 CLLocationProvider —— CoreLocation 围栏真实现"
```

---

## Task 7: UserNotifications 真实现 + 兜底重扫 【协作者】

`NotificationScheduling` 的真实现：用 `UNCalendarNotificationTrigger` 注册时间锁到点通知，保证 App 没开也能提醒；通知 `userInfo` 带 `capsuleID` 供深链路由。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/UNNotificationService.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/NotificationSchedulingTests.swift`（追加）

- [ ] **Step 1: 追加失败的测试**

在 `VoxlueKit/Tests/VoxlueServicesTests/NotificationSchedulingTests.swift` 末尾追加：

```swift
@Test func unNotificationServiceConformsToProtocol() {
    let service: NotificationScheduling = UNNotificationService()
    #expect(type(of: service) == UNNotificationService.self)
}

@Test func unNotificationServiceBuildsRequestWithCapsuleID() {
    let id = UUID()
    let fireAt = Date(timeIntervalSinceNow: 86_400)
    let request = UNNotificationService.makeRequest(capsuleID: id, fireAt: fireAt)
    #expect(request.identifier == id.uuidString)
    #expect(request.content.userInfo["capsuleID"] as? String == id.uuidString)
    #expect(request.trigger is UNCalendarNotificationTrigger)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter NotificationSchedulingTests`
Expected: 编译失败，提示找不到 `UNNotificationService`

- [ ] **Step 3: 实现 UNNotificationService**

创建 `VoxlueKit/Sources/VoxlueServices/UNNotificationService.swift`：

```swift
import Foundation
import UserNotifications

/// `NotificationScheduling` 的 UserNotifications 真实现。
///
/// 时间锁机制（spec §6）：注册本地日历通知 `UNCalendarNotificationTrigger`，
/// 保证 App 没开也能在到点提醒。通知 `userInfo` 带 `capsuleID`，供点击后深链到详情。
/// 兜底：App 启动 / 后台刷新由 `TriggerEngine.reconcile()` 再扫一遍过期胶囊。
public final class UNNotificationService: NotificationScheduling, @unchecked Sendable {

    /// 通知 `userInfo` 里 capsuleID 的键名 —— 深链路由按此读取。
    public static let capsuleIDKey = "capsuleID"

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func scheduleDateLock(capsuleID: UUID, fireAt date: Date) async throws {
        let request = Self.makeRequest(capsuleID: capsuleID, fireAt: date)
        try await center.add(request)
    }

    public func cancel(capsuleID: UUID) async {
        center.removePendingNotificationRequests(withIdentifiers: [capsuleID.uuidString])
    }

    /// 构建一条时间锁通知请求 —— 纯函数，便于单元测试。
    public static func makeRequest(capsuleID: UUID, fireAt date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "有一张相显影了"
        content.body = "你埋下的声音，到了重逢的时候。"
        content.sound = .default
        content.userInfo = [capsuleIDKey: capsuleID.uuidString]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: capsuleID.uuidString, content: content, trigger: trigger
        )
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter NotificationSchedulingTests`
Expected: `Test run with 5 tests passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/UNNotificationService.swift VoxlueKit/Tests/VoxlueServicesTests/NotificationSchedulingTests.swift
git commit -m "feat(trigger): 新增 UNNotificationService —— 时间锁日历通知真实现"
```

---

## Task 8: ActivityKit 真实现 LiveActivityController 【协作者】

`LiveActivityControlling` 的真实现：用 ActivityKit 的 `Activity.request` 起「显影中」Live Activity、`update` 推进霜化进度、`end` 结束。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/LiveActivityController.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/LiveActivityControllingTests.swift`（追加）

- [ ] **Step 1: 追加失败的测试**

在 `VoxlueKit/Tests/VoxlueServicesTests/LiveActivityControllingTests.swift` 末尾追加：

```swift
@MainActor
@Test func liveActivityControllerConformsToProtocol() {
    let controller: LiveActivityControlling = LiveActivityController()
    #expect(type(of: controller) == LiveActivityController.self)
}

@MainActor
@Test func liveActivityControllerStartsEmpty() {
    let controller = LiveActivityController()
    #expect(controller.activeCapsuleIDs.isEmpty)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter LiveActivityControllingTests`
Expected: 编译失败，提示找不到 `LiveActivityController`

- [ ] **Step 3: 实现 LiveActivityController**

创建 `VoxlueKit/Sources/VoxlueServices/LiveActivityController.swift`：

```swift
import Foundation
import ActivityKit

/// `LiveActivityControlling` 的 ActivityKit 真实现。
///
/// 胶囊进入 `developing` 时起一个「显影中」Live Activity（灵动岛 + 锁屏卡片），
/// 显影动效进度经 `update` 推进，胶囊被看到 / 播放后 `end`。
/// Live Activity 的 UI 在 Widget Extension（Task 10）里渲染，本类型只管生命周期。
@MainActor
public final class LiveActivityController: LiveActivityControlling {

    /// capsuleID → 活跃 Activity 句柄。
    private var activities: [UUID: Activity<DevelopingActivityAttributes>] = [:]

    public init() {}

    public var activeCapsuleIDs: [UUID] { Array(activities.keys) }

    public func start(capsuleID: UUID, title: String) async {
        guard activities[capsuleID] == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = DevelopingActivityAttributes(capsuleID: capsuleID, title: title)
        let initialState = DevelopingActivityAttributes.ContentState(developProgress: 0)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            activities[capsuleID] = activity
        } catch {
            // Live Activity 起不来不影响主流程 —— 胶囊状态仍由 SwiftData 持有。
        }
    }

    public func update(capsuleID: UUID, progress: Double) async {
        guard let activity = activities[capsuleID] else { return }
        let state = DevelopingActivityAttributes.ContentState(developProgress: progress)
        await activity.update(.init(state: state, staleDate: nil))
    }

    public func end(capsuleID: UUID) async {
        guard let activity = activities[capsuleID] else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        activities[capsuleID] = nil
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter LiveActivityControllingTests`
Expected: `Test run with 5 tests passed`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/LiveActivityController.swift VoxlueKit/Tests/VoxlueServicesTests/LiveActivityControllingTests.swift
git commit -m "feat(trigger): 新增 LiveActivityController —— ActivityKit 显影 Live Activity 真实现"
```

---

## Task 9: BGTaskScheduler 接入 + 情绪锁 hook 【协作者】

注册一个后台任务，唤醒后调用 `TriggerEngine.reconcile()` —— 这同时是时间锁兜底重扫与情绪锁浮现的后台入口。`MoodSurfacingHook` 的真闭环（脱敏闸门 → agent → 浮现）在计划 06 接入，本任务只提供注册、调度与派发骨架。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/BackgroundTaskCoordinator.swift`
- Test: `VoxlueKit/Tests/VoxlueServicesTests/BackgroundTaskCoordinatorTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/BackgroundTaskCoordinatorTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import VoxlueData
@testable import VoxlueServices

@MainActor
@Test func backgroundTaskIdentifierIsStable() {
    #expect(BackgroundTaskCoordinator.reconcileTaskIdentifier == "com.voxlue.app.reconcile")
}

@MainActor
@Test func handleReconcileRunsEngineReconcile() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    var moodHookFired = false
    engine.moodSurfacingHook = { moodHookFired = true }

    let coordinator = BackgroundTaskCoordinator(engine: engine)
    await coordinator.handleReconcile()

    // reconcile 跑过 → 情绪锁 hook 被触发。
    #expect(moodHookFired)
    _ = container
}

@MainActor
@Test func handleReconcileSurfacesExpiredDateLockInBackground() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let past = VoxlueData.Capsule(title: "去年", lock: .date(Date(timeIntervalSince1970: 1)))
    try store.add(past)
    let engine = TriggerEngine(
        store: store, location: FakeLocationProviding(),
        notifications: FakeNotificationScheduling(), liveActivity: FakeLiveActivityControlling()
    )
    let coordinator = BackgroundTaskCoordinator(engine: engine)
    await coordinator.handleReconcile()
    #expect(past.state == .developing)
    _ = container
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test --filter BackgroundTaskCoordinatorTests`
Expected: 编译失败，提示找不到 `BackgroundTaskCoordinator`

- [ ] **Step 3: 实现 BackgroundTaskCoordinator**

创建 `VoxlueKit/Sources/VoxlueServices/BackgroundTaskCoordinator.swift`：

```swift
import Foundation
import BackgroundTasks

/// BGTaskScheduler 接入 —— 后台唤醒入口。
///
/// 注册一个 `BGAppRefreshTask`，系统在安静时段唤醒后调用 `TriggerEngine.reconcile()`：
/// 既是时间锁的兜底重扫，也是情绪锁浮现的入口（`reconcile` 内会触发 `moodSurfacingHook`，
/// 真 agent 闭环在计划 06 接上）。
///
/// 注册标识符须同时写进 App 的 Info.plist `BGTaskSchedulerPermittedIdentifiers`。
@MainActor
public final class BackgroundTaskCoordinator {

    /// 后台重扫任务标识符 —— 须与 Info.plist 中登记一致。
    public static let reconcileTaskIdentifier = "com.voxlue.app.reconcile"

    /// 两次后台重扫之间的最短间隔。
    public static let minimumInterval: TimeInterval = 4 * 3600

    private let engine: TriggerEngineProtocol

    public init(engine: TriggerEngineProtocol) {
        self.engine = engine
    }

    /// App 启动时调用一次 —— 向系统注册后台任务处理器。
    public func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.reconcileTaskIdentifier, using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.runReconcileTask(refreshTask)
        }
    }

    /// 排下一次后台重扫 —— 每次任务跑完都要重新排，否则只跑一次。
    public func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: Self.reconcileTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.minimumInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// 跑一轮重扫 —— 围栏唤醒、后台任务、手动重扫都汇到这里。
    public func handleReconcile() async {
        await engine.reconcile()
    }

    // MARK: - 私有

    private func runReconcileTask(_ task: BGAppRefreshTask) {
        scheduleNext()  // 先排下一次，保证持续唤醒。
        let work = Task {
            await handleReconcile()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
```

- [ ] **Step 4: 运行全部包测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 末行 `Test run with N tests passed`，N = 计划 01 的 19 + 计划 02 的若干 + 本计划 30（3 location + 3 notification + 3 liveActivity + 6 scheduler + 8 engine + 2 cl + 2 un + 2 controller + 3 bgtask 已含于前）

> 实际数以仓库为准；判据是 `swift test` 末行 `passed`、无 `failed`。

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/BackgroundTaskCoordinator.swift VoxlueKit/Tests/VoxlueServicesTests/BackgroundTaskCoordinatorTests.swift
git commit -m "feat(trigger): 新增 BackgroundTaskCoordinator —— BGTask 后台重扫接入"
```

---

## Task 10: 灵动岛 Live Activity UI 【前端】

新建一个 Widget Extension 目标承载灵动岛 + 锁屏 Live Activity 的 SwiftUI 视图。数据契约 `DevelopingActivityAttributes` 复用 `VoxlueServices` 里已定义的那份（Task 3），不复制源文件。

**Files:**
- Create: Widget Extension 目标 `VoxlueWidget`（Xcode 生成）
- Create: `voxule/VoxlueWidget/VoxlueWidgetBundle.swift`
- Create: `voxule/VoxlueWidget/DevelopingLiveActivity.swift`
- Modify: App target Info.plist 构建设置（`NSSupportsLiveActivities`）

- [ ] **Step 1: 在 Xcode 新建 Widget Extension 目标**

在 Xcode：File ▸ New ▸ Target ▸ iOS ▸ **Widget Extension**，填写：

| 字段 | 值 |
|---|---|
| Product Name | `VoxlueWidget` |
| Include Live Activity | ✅ 勾选 |
| Include Configuration App Intent | ✗ 不勾 |

点 Finish ▸ 弹出「Activate scheme?」选 **Activate**。Xcode 会生成 `voxule/VoxlueWidget/` 目录与模板文件。

- [ ] **Step 2: 让 Widget 目标链接 VoxlueServices**

在 Xcode：TARGETS ▸ VoxlueWidget ▸ General ▸ Frameworks and Libraries ▸ `+` ▸ 添加 `VoxlueServices`（本地包已加为依赖，下拉可见）。
TARGETS ▸ VoxlueWidget ▸ Minimum Deployments ▸ iOS 设为 `26.0`。

- [ ] **Step 3: 开启 App 的 Live Activities 支持**

在 Xcode：TARGETS ▸ voxule ▸ Build Settings ▸ 搜索 `Info.plist` ▸ 在 `INFOPLIST_KEY_NSSupportsLiveActivities` 设为 `YES`（无此键则点 `+` 新增 User-Defined 设置 `INFOPLIST_KEY_NSSupportsLiveActivities = YES`）。

- [ ] **Step 4: 删模板、写 Live Activity 视图**

删除 Xcode 生成的模板文件 `VoxlueWidget.swift` 与 `AppIntent.swift`（若有）。保留或覆盖 `VoxlueWidgetBundle.swift`，内容替换为：

```swift
import SwiftUI
import WidgetKit

@main
struct VoxlueWidgetBundle: WidgetBundle {
    var body: some Widget {
        DevelopingLiveActivity()
    }
}
```

创建 `voxule/VoxlueWidget/DevelopingLiveActivity.swift`：

```swift
import SwiftUI
import WidgetKit
import ActivityKit
import VoxlueServices

/// 「显影中」灵动岛 + 锁屏 Live Activity。
/// 胶囊从 buried → developing 时由 `LiveActivityController` 起。
/// 暗房美学：锁屏卡片是一张正在显影的相纸，霜化进度由 developProgress 驱动。
struct DevelopingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DevelopingActivityAttributes.self) { context in
            // 锁屏 / 通知中心展开态。
            lockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开态。
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("显影中")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.developProgress)
                        .tint(.white)
                }
            } compactLeading: {
                Image(systemName: "photo")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text("\(Int(context.state.developProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "photo")
                    .foregroundStyle(.white)
            }
            // 点灵动岛跳到该胶囊详情 —— 深链由 Task 12 路由处理。
            .widgetURL(URL(string: "voxlue://capsule/\(context.attributes.capsuleID.uuidString)"))
        }
    }

    @ViewBuilder
    private func lockScreenView(
        context: ActivityViewContext<DevelopingActivityAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.white)
                Text("一张相正在显影")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            Text(context.attributes.title)
                .font(.title3)
                .foregroundStyle(.white)
                .lineLimit(2)
            ProgressView(value: context.state.developProgress)
                .tint(.white)
        }
    }
}
```

- [ ] **Step 5: 构建并验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: 末行 `** BUILD SUCCEEDED **`（App 与 VoxlueWidget 两个目标都编过）

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule
git commit -m "feat(trigger): 新增灵动岛 Live Activity UI 与 Widget Extension"
```

---

## Task 11: 地图视图 UI 【前端】

用 MapKit 做一张地图，标出全部 `buried` 的地点锁胶囊位置与正在 `developing` 的显影点。读数据用 `@Query`，不写数据。

**Files:**
- Create: `voxule/voxule/CapsuleMapView.swift`

- [ ] **Step 1: 写地图视图**

创建 `voxule/voxule/CapsuleMapView.swift`：

```swift
import SwiftUI
import SwiftData
import MapKit
import VoxlueData

/// 地图视图 —— 标出已埋下地点锁胶囊与正在显影的点。
/// 暗房美学：埋下点是一枚暗的相角标记，显影中点是高亮的朱色标记。
struct CapsuleMapView: View {
    @Query private var capsules: [VoxlueData.Capsule]

    /// 一个可标注的地点锁胶囊。
    private struct Pin: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let title: String
        let isDeveloping: Bool
    }

    /// 从全部胶囊里挑出有地点锁、且尚未开启的，转成地图标注。
    private var pins: [Pin] {
        capsules.compactMap { capsule in
            guard case .place(let lat, let lon, _, let placeName) = capsule.lock else {
                return nil
            }
            guard capsule.state != .opened else { return nil }
            return Pin(
                id: capsule.id,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                title: capsule.title.isEmpty ? placeName : capsule.title,
                isDeveloping: capsule.state == .developing
            )
        }
    }

    var body: some View {
        Map {
            ForEach(pins) { pin in
                Annotation(pin.title, coordinate: pin.coordinate) {
                    Image(systemName: pin.isDeveloping
                          ? "photo.fill" : "mappin.circle")
                        .font(.title2)
                        .foregroundStyle(pin.isDeveloping ? .red : .secondary)
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .navigationTitle("埋下的地方")
        .overlay(alignment: .bottom) {
            if pins.isEmpty {
                Text("还没有埋在某个地点的相")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CapsuleMapView()
            .modelContainer(for: VoxlueData.Capsule.self, inMemory: true)
    }
}
```

> 说明：此文件 `import SwiftUI` 与 `VoxlueData` 同在，`VoxlueData.Capsule` 须写全消歧义；`overlay` 里的 `Capsule` 指 `SwiftUI.Capsule` 形状（无歧义，因为那是形状上下文）。

- [ ] **Step 2: 构建并验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: 末行 `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/CapsuleMapView.swift
git commit -m "feat(trigger): 新增 MapKit 地图视图 —— 标注地点锁与显影点"
```

---

## Task 12: 通知 / 深链路由 + 依赖装配 【前端】

App 壳层收尾：装配触发引擎依赖、注册 BGTask、把通知点击与 Live Activity 深链路由到胶囊详情。这是计划 03 完成 App 壳层路由的部分（路线图 §2.1）。

**Files:**
- Create: `voxule/voxule/AppDependencies.swift`
- Create: `voxule/voxule/CapsuleRouter.swift`
- Modify: `voxule/voxule/voxuleApp.swift`
- Modify: `voxule/voxule/DebugRootView.swift`
- Modify: App target Info.plist 构建设置（`BGTaskSchedulerPermittedIdentifiers`、URL Scheme）

- [ ] **Step 1: 配置 Info.plist 键与 Background Modes**

在 Xcode：
1. TARGETS ▸ voxule ▸ Signing & Capabilities ▸ Background Modes（已有 Remote notifications）▸ 追加勾选 **Background fetch** 与 **Location updates**。
2. Build Settings ▸ 新增 User-Defined 设置 `INFOPLIST_KEY_BGTaskSchedulerPermittedIdentifiers` —— 值为数组单元素 `com.voxlue.app.reconcile`。若构建设置不便填数组，改在 App target 的 `Info.plist` 里手填：
   ```xml
   <key>BGTaskSchedulerPermittedIdentifiers</key>
   <array><string>com.voxlue.app.reconcile</string></array>
   ```
3. TARGETS ▸ voxule ▸ Info ▸ URL Types ▸ `+` ▸ URL Schemes 填 `voxlue`（供深链 `voxlue://capsule/<id>`）。
4. 定位与通知用途说明：Info ▸ 新增 `NSLocationAlwaysAndWhenInUseUsageDescription` = `voxlue 用你的位置在你回到埋下声音的地方时，轻轻提醒你。` 与 `NSLocationWhenInUseUsageDescription` 同文案。

- [ ] **Step 2: 写依赖装配容器**

创建 `voxule/voxule/AppDependencies.swift`：

```swift
import Foundation
import SwiftData
import VoxlueData
import VoxlueServices

/// App 壳层依赖装配 —— 一处构造全部领域服务的真实现，注入到视图树。
/// MV 模式：服务是 @Observable 具体类型，视图经 .environment 取用。
@MainActor
@Observable
final class AppDependencies {
    let store: CapsuleStore
    let engine: TriggerEngine
    let backgroundTasks: BackgroundTaskCoordinator
    let router: CapsuleRouter

    init(modelContainer: ModelContainer) {
        let store = CapsuleStore(context: modelContainer.mainContext)
        let engine = TriggerEngine(
            store: store,
            location: CLLocationProvider(),
            notifications: UNNotificationService(),
            liveActivity: LiveActivityController()
        )
        self.store = store
        self.engine = engine
        self.backgroundTasks = BackgroundTaskCoordinator(engine: engine)
        self.router = CapsuleRouter()
    }

    /// App 启动时跑一遍：注册后台任务、订阅围栏、首次兜底重扫。
    func bootstrap() async {
        backgroundTasks.register()
        backgroundTasks.scheduleNext()
        await engine.start()
        await engine.reconcile()
    }
}
```

- [ ] **Step 2.5: 运行包测试确认装配依赖未破坏契约**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 末行 `passed`、无 `failed`

- [ ] **Step 3: 写深链路由**

创建 `voxule/voxule/CapsuleRouter.swift`：

```swift
import Foundation
import SwiftUI
import VoxlueServices

/// 深链 / 通知路由 —— 把外部入口（通知点击、Live Activity 点击、URL Scheme）
/// 统一解析成「要打开哪枚胶囊」，驱动导航。
@MainActor
@Observable
final class CapsuleRouter {
    /// 当前要展示详情的胶囊 —— 详情视图绑定它。
    var routedCapsuleID: UUID?

    /// 解析一条深链 URL，形如 `voxlue://capsule/<uuid>`。
    func handle(url: URL) {
        guard url.scheme == "voxlue", url.host == "capsule" else { return }
        let idString = url.lastPathComponent
        guard let id = UUID(uuidString: idString) else { return }
        routedCapsuleID = id
    }

    /// 解析一条通知的 userInfo（时间锁通知带 capsuleID）。
    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let idString = userInfo[UNNotificationService.capsuleIDKey] as? String,
              let id = UUID(uuidString: idString) else { return }
        routedCapsuleID = id
    }
}
```

- [ ] **Step 4: 改 App 入口接入装配与路由**

把 `voxule/voxule/voxuleApp.swift` 全文替换为：

```swift
import SwiftUI
import SwiftData
import VoxlueData

@main
struct voxuleApp: App {
    private let modelContainer: ModelContainer
    @State private var dependencies: AppDependencies

    init() {
        let container: ModelContainer
        if let cloudContainer = try? VoxlueModelContainer.make() {
            container = cloudContainer
        } else {
            do {
                container = try ModelContainer(
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
        modelContainer = container
        _dependencies = State(initialValue: AppDependencies(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            DebugRootView()
                .environment(dependencies)
                .task { await dependencies.bootstrap() }
                .onOpenURL { url in
                    dependencies.router.handle(url: url)
                }
        }
        .modelContainer(modelContainer)
    }
}
```

- [ ] **Step 5: 改调试视图挂触发引擎入口**

把 `voxule/voxule/DebugRootView.swift` 全文替换为：

```swift
import SwiftUI
import SwiftData
import VoxlueData

/// 临时调试视图 —— 验证数据层 + 触发引擎端到端可用。计划后续替换为样片墙。
struct DebugRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppDependencies.self) private var dependencies
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    var body: some View {
        NavigationStack {
            List(capsules) { capsule in
                HStack {
                    VStack(alignment: .leading) {
                        Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                        Text(capsule.state.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if capsule.state == .buried {
                        Button("显影") {
                            Task { await dependencies.engine.surface(capsuleID: capsule.id) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("胶囊：\(capsules.count)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("地图") { CapsuleMapView() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("加一枚样本") {
                        let store = CapsuleStore(context: context)
                        try? store.add(VoxlueData.Capsule(
                            title: "样本 \(capsules.count + 1)", lock: .date(.now)
                        ))
                    }
                }
            }
            .overlay(alignment: .top) {
                if let routed = dependencies.router.routedCapsuleID {
                    Text("深链命中胶囊：\(routed.uuidString.prefix(8))")
                        .font(.caption)
                        .padding(6)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
```

- [ ] **Step 6: 构建并端到端验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: 末行 `** BUILD SUCCEEDED **`

然后在 Xcode 用 iPhone 17 模拟器运行（⌘R）：点「加一枚样本」（锁为 `.date(.now)`，即过期时间锁）→ 该胶囊状态应在下次 `reconcile` 或点「显影」后变为 `developing`；点「显影」按钮后状态行变 `developing`。在终端跑深链验证：

Run: `xcrun simctl openurl booted "voxlue://capsule/00000000-0000-0000-0000-000000000001"`
Expected: App 切前台，顶部出现「深链命中胶囊：00000000」横幅

- [ ] **Step 7: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule
git commit -m "feat(trigger): App 壳层接入触发引擎装配、BGTask 注册与深链路由"
```

---

## 完成标准

- `cd /Users/cornna/project/voxule/VoxlueKit && swift test` 全绿，无 `failed` —— 含本计划新增的 GeofenceScheduler（6）、LocationProviding（5）、NotificationScheduling（5）、LiveActivityControlling（5）、TriggerEngine（8）、BackgroundTaskCoordinator（3）共约 32 个测试。
- App 与 `VoxlueWidget` 两个目标头无签名构建通过：`xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO` 末行 `** BUILD SUCCEEDED **`。
- `TriggerEngine` 实现路线图 §3.2 冻结的 `TriggerEngineProtocol`，签名逐字一致；`FakeTriggerEngine` 同包就绪。
- 三把锁各自闭环：地点锁经 `CLLocationProvider` + `GeofenceScheduler`「最近 20 个」轮换；时间锁经 `UNNotificationService` 日历通知 + `reconcile` 兜底重扫；情绪锁经 `BackgroundTaskCoordinator` 后台唤醒触发 `moodSurfacingHook`（真闭环留给计划 06）。
- `GeofenceScheduler.nearest` 是纯函数，已用假围栏 + 假用户坐标直接测出「裁 20 上限」「保留最近」「用户移动后重排」三条性质。
- 平台能力 wrapper 三件套（`LocationProviding` / `NotificationScheduling` / `LiveActivityControlling`）均备协议 + 真实现 + 假实现。
- 灵动岛 Live Activity UI、MapKit 地图、深链/通知路由三个【前端】任务落地，App 可端到端跑通「显影 → 灵动岛 → 点击深链回详情」。
- BGTask 标识符 `com.voxlue.app.reconcile` 已写进 Info.plist `BGTaskSchedulerPermittedIdentifiers`；Background Modes 含 Remote notifications + Background fetch + Location updates；`NSSupportsLiveActivities=YES`；URL Scheme `voxlue` 已注册。
- 全部改动已分 Task 提交 git。

下一份计划：**计划 05 · 声音圈共享**（或按排期先做计划 04 设计系统）；情绪锁真闭环见 **计划 06 · 云端 agent 闭环**。

---

## 备注 · 与契约 / 环境的对齐点

- **冻结契约逐字采用：** `TriggerEngineProtocol`、`NotificationScheduling`、`LocationProviding`、`GeofenceRegion`、`GeofenceEvent` 全部取自路线图 §3.2，签名未改。`AudioRecording` / `AudioPlaying`（§3.1）属计划 02，本计划不重定义、不引用。
- **命名冲突：** 凡同时 `import SwiftUI` 与 `VoxlueData` 的文件（`CapsuleMapView`、`DebugRootView`），模型一律写全 `VoxlueData.Capsule`，与计划 01 收尾记录一致。
- **包归属：** 全部服务与 wrapper 落 `VoxlueKit/Sources/VoxlueServices/`（计划 02 已建该目标），只改同一份 `VoxlueKit/Package.swift` 不另建包；`VoxlueServices` 依赖方向为 `→ VoxlueData`。
- **GeofenceScheduler 裁剪位置：** 引擎把全量地点锁围栏交给 `LocationProviding.monitor`，真正的「最近 20 个」裁剪由 `CLLocationProvider` 在能拿到用户实时坐标时执行 —— 因为只有 wrapper 持有 `CLLocationManager.location`。`GeofenceScheduler` 本身无状态、可被引擎与 wrapper 共用，并被单测直接覆盖。
- **BGTask 与情绪锁：** 本计划只交付后台唤醒入口与 `moodSurfacingHook` 钩子；脱敏闸门 → agent → 浮现的真闭环是计划 06 的范围。
- **Widget Extension：** 需在 Xcode 工程新建目标（Task 10 给出逐步操作）；`DevelopingActivityAttributes` 定义在 `VoxlueServices`，App 与 Widget 链接同一包共用，不复制源文件。
