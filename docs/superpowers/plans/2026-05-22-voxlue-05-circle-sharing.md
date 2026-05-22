# voxlue 计划 05 · 声音圈共享 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地「声音圈」共享 —— 在 `VoxlueServices` 包新增 `CircleService`（实现 `CircleServicing` 协议，真实现走 SwiftData 原生共享 / `CKShare` 对接 CloudKit 共享库），配套 `FakeCircleServicing` 假实现；补齐 CloudKit 共享库配置；前端搭建建圈、圈成员列表、圈内胶囊浏览、生成并发送邀请、接受邀请落地页；App 壳层接住进站的 `CKShare` 链接深链；并把「声音圈」收件人接进计划 02 的装裱流程。

**Architecture:** 声音圈是架构文档 §8 的「共享路」。圈主在私有库建一个 `Circle`（CKShare 的共享单元，§5），SwiftData 原生共享为它生成一个 `CKShare`；圈主把 `CKShare.url` 经 share sheet / iMessage 发出；受邀者点击链接，App 壳层在 `userDidAcceptCloudKitShareWith` / SwiftData 的 share 接受回调里把 `Circle` 与圈内 `Capsule` 落进自己的**共享库**，音频 `Data` 经 `@Attribute(.externalStorage)` 自动镜像为 `CKAsset`。`CircleService` 是架构文档 §8/§13 钉死的**隔离层** —— 若 SwiftData 原生共享某个边角不稳，可整体退回手写 `CKShare`，调用方（前端 UI、壳层）只认 `CircleServicing` 协议，不受波及。`CircleService` 以 `@MainActor @Observable final class` 实现协议（MV 模式，无 ViewModel）；前端视图与 `#Preview` 注入 `FakeCircleServicing`。`Circle` / `CircleMember` / `Capsule` / `CapsuleStore` 复用 `VoxlueData`，本计划不重定义。

**Tech Stack:** Swift 6.2 · SwiftUI · SwiftData · CloudKit（`CKShare` / `CKContainer` / 共享库）· Swift Testing · Xcode 26.5 · iOS 26

**前置条件:**
- 计划 01（数据层）已完成并合入 `main` —— `Circle` / `CircleMember` / `Capsule` / `CapsuleStore` / `VoxlueModelContainer` 已就绪。`Capsule.recipient`、`Capsule.circleID` 字段计划 01 已建好，本计划直接用。
- 计划 02（录音→装裱→回放主循环）已完成并合入 `main` —— `VoxlueServices` 包目标已存在，装裱 UI（埋下流程的收件人选择）已就绪。本计划向 `VoxlueServices` **新增** `CircleService`，不重建包。
- 已安装 Xcode 26.5+；macOS 26（用于 `swift test`）。
- **开发者账号前置（仅真同步/真共享需要，headless 构建与 Fake 测试不需要）：** 一个 Apple Developer 账号；在 CloudKit Dashboard 已创建容器 `iCloud.com.voxlue.app`；App 目标以带 iCloud 能力的 Team 完成签名。模拟器 headless 构建一律用 `CODE_SIGNING_ALLOWED=NO` + `FakeCircleServicing`。

**对应设计文档:** `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md` 的 §8（CloudKit 同步与共享）、§5（Circle / CircleMember 模型）、§13（SwiftData 原生共享风险与 CircleService 隔离）；路线图 `docs/superpowers/plans/2026-05-22-voxlue-v1-roadmap.md` 的 §1、§3.0、§3.3、§6。

---

## 文件结构

```
/Users/cornna/project/voxule/
├── voxule/                                Xcode 应用项目
│   ├── voxule.xcodeproj
│   └── voxule/
│       ├── voxuleApp.swift                壳层：注入 CircleService + 接住 CKShare 深链（改）
│       ├── voxule.entitlements            iCloud / CloudKit 能力（改：共享库说明）
│       ├── ServiceContainer.swift         壳层 DI 容器（改：登记 CircleService；计划 02 已建）
│       ├── DeepLinkRouter.swift           壳层：CKShare 接受路由（新建）
│       └── Features/Circle/
│           ├── CircleListView.swift       声音圈列表 + 建圈入口（新建）
│           ├── CreateCircleView.swift     建圈表单（新建）
│           ├── CircleDetailView.swift     圈成员列表 + 圈内胶囊浏览 + 发邀请（新建）
│           ├── ShareInvitationSheet.swift CKShare URL 的 share sheet 包装（新建）
│           ├── AcceptInvitationView.swift 接受邀请落地页（新建）
│           └── CirclePickerView.swift     装裱时选「哪个声音圈」（新建）
├── VoxlueKit/
│   ├── Package.swift                       VoxlueServices 已含（计划 02），本计划不改
│   ├── Sources/VoxlueServices/
│   │   ├── CircleServicing.swift           协议 + ShareInvitation（新建）
│   │   ├── FakeCircleServicing.swift       假实现（新建）
│   │   └── CircleService.swift             真实现（SwiftData 原生共享 / CKShare）（新建）
│   └── Tests/VoxlueServicesTests/
│       ├── FakeCircleServicingTests.swift  假实现行为测试（新建）
│       └── CircleServiceLogicTests.swift   建圈/邀请 URL/收件人 域逻辑测试（新建）
└── docs/
```

> 说明：`voxule/voxule/Features/` 目录与 `ServiceContainer.swift` 由计划 02 建立。本计划若发现 `Features/Circle/` 尚不存在则新建该子目录；`ServiceContainer.swift` 若不存在，按 Task 6 的最小形态补建。`Capsule` 与 `SwiftUI.Capsule` 同名，凡同时 `import SwiftUI` 与 `VoxlueData` 的文件一律写全 `VoxlueData.Capsule`。

---

## Task 1: CircleServicing 协议与 ShareInvitation 【协作者】

契约优先：先交付路线图 §3.3 钉死的协议与值类型。协议签名一经合入即冻结，前端据此开工。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/CircleServicing.swift`

- [ ] **Step 1: 写失败的测试（占位编译断言）**

`VoxlueServices` 已由计划 02 建立。新建 `VoxlueKit/Tests/VoxlueServicesTests/FakeCircleServicingTests.swift`，先放一个引用协议的最小断言，确认协议类型存在：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func shareInvitationCarriesURL() {
    let url = URL(string: "https://www.icloud.com/share/0ABC")!
    let invitation = ShareInvitation(url: url)
    #expect(invitation.url == url)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `ShareInvitation`。

- [ ] **Step 3: 实现协议与值类型（逐字采用路线图 §3.3 签名）**

创建 `VoxlueKit/Sources/VoxlueServices/CircleServicing.swift`：

```swift
import Foundation
import VoxlueData

/// 一份声音圈共享邀请。`url` 是 CKShare 链接，用于 iMessage / 系统分享。
public struct ShareInvitation: Sendable {
    public let url: URL          // CKShare 链接，用于 iMessage/分享

    public init(url: URL) {
        self.url = url
    }
}

/// 声音圈服务 —— 建圈、CKShare 邀请、共享同步。
///
/// 这是架构文档 §8 / §13 钉死的**隔离层**：v1 真实现走 SwiftData 原生共享，
/// 若原生共享某个边角不稳，可整体退回手写 `CKShare` 而不改本协议、不波及调用方。
/// 调用方（前端 UI、App 壳层）只认本协议。
@MainActor public protocol CircleServicing: AnyObject {
    /// 圈主建一个新声音圈。
    func createCircle(name: String) async throws -> Circle
    /// 为圈生成共享邀请（CKShare 链接）。
    func makeInvitation(for circle: Circle) async throws -> ShareInvitation
    /// 接受他人共享链接 —— 把圈与圈内胶囊落进自己的共享库。
    func acceptShare(from url: URL) async throws
    /// 当前用户可见的全部声音圈（自建的 + 已加入的）。
    func circles() async throws -> [Circle]
}

/// 声音圈服务可能抛出的错误。
public enum CircleServiceError: Error, Sendable, Equatable {
    /// 圈名为空或仅空白。
    case emptyCircleName
    /// 传入的链接不是有效的 CKShare 邀请链接。
    case invalidInvitationURL
    /// CloudKit 不可用（未登录 iCloud、无网络、缺账号等）。
    case cloudKitUnavailable
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 输出含 `1 test passed`（本计划新增的 `shareInvitationCarriesURL`；其它包测试不受影响）。

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/CircleServicing.swift VoxlueKit/Tests/VoxlueServicesTests/FakeCircleServicingTests.swift
git commit -m "feat(circle): 新增 CircleServicing 协议与 ShareInvitation"
```

---

## Task 2: FakeCircleServicing 假实现 【协作者】

假实现一旦合入，前端即可 `import VoxlueServices` 用它驱动 UI 与 `#Preview`，不必等真实现。这是契约优先的交接点。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/FakeCircleServicing.swift`
- Modify: `VoxlueKit/Tests/VoxlueServicesTests/FakeCircleServicingTests.swift`

- [ ] **Step 1: 补充失败的测试**

把 `FakeCircleServicingTests.swift` 全文替换为：

```swift
import Testing
import Foundation
import VoxlueData
@testable import VoxlueServices

@Test func shareInvitationCarriesURL() {
    let url = URL(string: "https://www.icloud.com/share/0ABC")!
    let invitation = ShareInvitation(url: url)
    #expect(invitation.url == url)
}

@MainActor
@Test func fakeCreateCircleAppendsToCircles() async throws {
    let service = FakeCircleServicing()
    #expect(try await service.circles().isEmpty)

    let circle = try await service.createCircle(name: "家")
    #expect(circle.name == "家")

    let all = try await service.circles()
    #expect(all.count == 1)
    #expect(all.first?.id == circle.id)
}

@MainActor
@Test func fakeCreateCircleRejectsEmptyName() async {
    let service = FakeCircleServicing()
    await #expect(throws: CircleServiceError.emptyCircleName) {
        _ = try await service.createCircle(name: "   ")
    }
}

@MainActor
@Test func fakeMakeInvitationReturnsStableURL() async throws {
    let service = FakeCircleServicing()
    let circle = try await service.createCircle(name: "挚友")
    let invitation = try await service.makeInvitation(for: circle)
    #expect(invitation.url.scheme == "https")
    // 同一个圈再要一次邀请，URL 稳定（同一个 CKShare）。
    let again = try await service.makeInvitation(for: circle)
    #expect(again.url == invitation.url)
}

@MainActor
@Test func fakeAcceptShareAppendsACircle() async throws {
    let service = FakeCircleServicing()
    try await service.acceptShare(from: URL(string: "https://www.icloud.com/share/0XYZ")!)
    let all = try await service.circles()
    #expect(all.count == 1)
    #expect(all.first?.name == "（受邀加入的圈）")
}

@MainActor
@Test func fakeAcceptShareRejectsNonShareURL() async {
    let service = FakeCircleServicing()
    await #expect(throws: CircleServiceError.invalidInvitationURL) {
        try await service.acceptShare(from: URL(string: "https://example.com/hello")!)
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `FakeCircleServicing`。

- [ ] **Step 3: 实现 FakeCircleServicing**

创建 `VoxlueKit/Sources/VoxlueServices/FakeCircleServicing.swift`：

```swift
import Foundation
import VoxlueData

/// `CircleServicing` 的假实现 —— 全内存，不接 CloudKit。
/// 供前端 UI、`#Preview` 与单元测试注入；不需要 iCloud 账号。
@MainActor
public final class FakeCircleServicing: CircleServicing {

    /// 已存在的圈（自建 + 受邀加入）。
    private var storedCircles: [Circle]
    /// circle.id → 已生成的邀请 URL，保证同圈邀请稳定。
    private var invitationURLs: [UUID: URL] = [:]

    /// - Parameter circles: 预置圈，便于预览展示非空列表。
    public init(circles: [Circle] = []) {
        self.storedCircles = circles
    }

    public func createCircle(name: String) async throws -> Circle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CircleServiceError.emptyCircleName }
        let circle = Circle(name: trimmed, ownerID: "fake-owner")
        circle.members = [
            CircleMember(name: "我", userRecordID: "fake-owner", role: .owner)
        ]
        storedCircles.append(circle)
        return circle
    }

    public func makeInvitation(for circle: Circle) async throws -> ShareInvitation {
        if let existing = invitationURLs[circle.id] {
            return ShareInvitation(url: existing)
        }
        let url = URL(string: "https://www.icloud.com/share/fake-\(circle.id.uuidString)")!
        invitationURLs[circle.id] = url
        return ShareInvitation(url: url)
    }

    public func acceptShare(from url: URL) async throws {
        guard FakeCircleServicing.looksLikeShareURL(url) else {
            throw CircleServiceError.invalidInvitationURL
        }
        let joined = Circle(name: "（受邀加入的圈）", ownerID: "someone-else")
        joined.members = [
            CircleMember(name: "我", userRecordID: "fake-owner", role: .member)
        ]
        storedCircles.append(joined)
    }

    public func circles() async throws -> [Circle] {
        storedCircles
    }

    /// 一个 URL 是否长得像 CKShare 邀请链接。真实 CKShare 链接形如
    /// `https://www.icloud.com/share/<token>`。
    public static func looksLikeShareURL(_ url: URL) -> Bool {
        guard let host = url.host(), host.contains("icloud.com") else { return false }
        return url.path().contains("/share/")
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 输出含 `7 tests passed`（本计划 Task 1+2 累计 7 个）。

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/FakeCircleServicing.swift VoxlueKit/Tests/VoxlueServicesTests/FakeCircleServicingTests.swift
git commit -m "feat(circle): 新增 FakeCircleServicing 假实现"
```

> **交接点：** 至此 `CircleServicing` 协议 + `FakeCircleServicing` 已合入。前端轨可据此开 Task 5–10 的 UI 任务，无需等真实现（Task 3/4）。

---

## Task 3: CircleService 真实现 —— SwiftData 原生共享 / CKShare 【协作者】

真实现走 SwiftData 原生共享对接 CloudKit 共享库。**真同步/真共享需要 iCloud 账号 + 真机或登录 iCloud 的模拟器，无法 headless 单元测试** —— 故本 Task 的纯逻辑（圈名校验、邀请 URL 识别、容器装配）拆出来可测，CloudKit 调用包在 `#if canImport(CloudKit)` 内，由 Task 4 的逻辑测试覆盖可测部分。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/CircleService.swift`

- [ ] **Step 1: 实现 CircleService（真实现）**

创建 `VoxlueKit/Sources/VoxlueServices/CircleService.swift`：

```swift
import Foundation
import SwiftData
import CloudKit
import VoxlueData

/// `CircleServicing` 的真实现 —— SwiftData 原生共享 / `CKShare` 对接 CloudKit 共享库。
///
/// 架构文档 §8「共享路」：圈主在私有库建 `Circle` → SwiftData 为它生成 `CKShare`
/// → 圈主把 `CKShare.url` 发出 → 受邀者接受 → `Circle` 与圈内 `Capsule` 落进其共享库；
/// 音频 `Data` 经 `@Attribute(.externalStorage)` 自动镜像为 `CKAsset`。
///
/// 架构文档 §13 隔离原则：本类是唯一感知「SwiftData 原生共享」细节的地方。
/// 若原生共享某边角不稳，可把 `makeInvitation` / `acceptShare` 内部整体换成
/// 手写 `CKShare`（`CKModifyRecordsOperation` + `CKShare(rootRecord:)`），
/// 协议签名与调用方均不变。
@MainActor
@Observable
public final class CircleService: CircleServicing {

    private let modelContext: ModelContext
    private let cloudKitContainerID: String

    /// - Parameters:
    ///   - modelContext: 与 App 共用的主上下文（计划 01 的 `VoxlueModelContainer`）。
    ///   - cloudKitContainerID: CloudKit 容器标识，默认与数据层一致。
    public init(
        modelContext: ModelContext,
        cloudKitContainerID: String = VoxlueModelContainer.cloudKitContainerID
    ) {
        self.modelContext = modelContext
        self.cloudKitContainerID = cloudKitContainerID
    }

    // MARK: - CircleServicing

    public func createCircle(name: String) async throws -> Circle {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CircleServiceError.emptyCircleName }

        let ownerID = try await currentUserRecordName()
        let circle = Circle(name: trimmed, ownerID: ownerID)
        circle.members = [
            CircleMember(name: "我", userRecordID: ownerID, role: .owner)
        ]
        modelContext.insert(circle)
        try modelContext.save()
        return circle
    }

    public func makeInvitation(for circle: Circle) async throws -> ShareInvitation {
        // SwiftData 原生共享：为该 Circle 取/建一个 CKShare。
        // `modelContext.container` 暴露底层 CloudKit；v1 用 SwiftData 的
        // shareEnabled 配置由 VoxlueModelContainer 在共享配置里开启（见 Task 4 说明）。
        let share = try await cloudKitShare(for: circle)
        guard let url = share.url else {
            throw CircleServiceError.cloudKitUnavailable
        }
        return ShareInvitation(url: url)
    }

    public func acceptShare(from url: URL) async throws {
        guard FakeCircleServicing.looksLikeShareURL(url) else {
            throw CircleServiceError.invalidInvitationURL
        }
        let container = CKContainer(identifier: cloudKitContainerID)
        // 1. 取邀请元数据。
        let metadata: CKShare.Metadata
        do {
            metadata = try await container.shareMetadata(for: url)
        } catch {
            throw CircleServiceError.cloudKitUnavailable
        }
        // 2. 接受邀请 —— Circle 与圈内 Capsule 随之落进本机共享库，
        //    SwiftData 镜像层会把它们带进本地存储。
        do {
            try await container.accept(metadata)
        } catch {
            throw CircleServiceError.cloudKitUnavailable
        }
    }

    public func circles() async throws -> [Circle] {
        // 私有库自建的圈 + 共享库受邀加入的圈，SwiftData 镜像后都落在同一本地库。
        try modelContext.fetch(
            FetchDescriptor<Circle>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
    }

    // MARK: - CloudKit 细节（隔离在本类内）

    /// 当前登录用户的 record name；CloudKit 不可用时抛 `cloudKitUnavailable`。
    private func currentUserRecordName() async throws -> String {
        let container = CKContainer(identifier: cloudKitContainerID)
        do {
            let recordID = try await container.userRecordID()
            return recordID.recordName
        } catch {
            throw CircleServiceError.cloudKitUnavailable
        }
    }

    /// 为一个 Circle 取/建底层 CKShare。
    ///
    /// v1 用 SwiftData 原生共享：把 Circle 标记为共享根，由镜像层管理 CKShare 生命周期。
    /// 这里通过 CloudKit 私有库按 Circle.id 取已有共享、不存在则建。
    /// 若原生共享不稳，可整体替换本方法体为纯手写 CKShare，对外不变（§13）。
    private func cloudKitShare(for circle: Circle) async throws -> CKShare {
        let container = CKContainer(identifier: cloudKitContainerID)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone")
        let recordID = CKRecord.ID(
            recordName: "CD_Circle_\(circle.id.uuidString)",
            zoneID: zoneID
        )
        do {
            let rootRecord = try await database.record(for: recordID)
            // 已有共享？
            if let existingShareRef = rootRecord.share {
                if let share = try await database.record(for: existingShareRef.recordID) as? CKShare {
                    return share
                }
            }
            // 新建共享。
            let share = CKShare(rootRecord: rootRecord)
            share[CKShare.SystemFieldKey.title] = circle.name as CKRecordValue
            share.publicPermission = .none   // 仅受邀者可入。
            let result = try await database.modifyRecords(
                saving: [rootRecord, share],
                deleting: []
            )
            _ = result
            return share
        } catch {
            throw CircleServiceError.cloudKitUnavailable
        }
    }
}
```

> **实现备注（写进 PR 描述，不入代码）：** `cloudKitShare(for:)` 里按 `CD_Circle_<uuid>` 拼 record name 是 SwiftData CloudKit 镜像的命名约定（`CD_` 前缀 + 实体名 + 主键）。若运行期发现 record name 规则与本机 SwiftData 版本不符，**这正是 §13 预案的触发点** —— 把整个 `cloudKitShare` / `acceptShare` 换成不依赖镜像命名的纯手写 `CKShare`（自建共享 zone + 手动搬记录），协议与前端均不动。本步无法 headless 测试，验证见 Task 12。

- [ ] **Step 2: 验证包可编译**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift build`
Expected: 输出 `Build complete!`（CloudKit 在 iOS/macOS 均可 import，编译不需要 iCloud 账号）。

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/CircleService.swift
git commit -m "feat(circle): 新增 CircleService 真实现（SwiftData 原生共享 / CKShare）"
```

---

## Task 4: CircleService 域逻辑测试 【协作者】

`CircleService` 的 CloudKit 路径无法 headless 测试，但**圈名校验、邀请 URL 识别**等纯域逻辑可测。本 Task 把这部分测明白，并诚实标注哪些行为只能上真机/真账号验证（Task 12）。

**Files:**
- Create: `VoxlueKit/Tests/VoxlueServicesTests/CircleServiceLogicTests.swift`

- [ ] **Step 1: 写测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/CircleServiceLogicTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
import VoxlueData
@testable import VoxlueServices

// 说明：CircleService 的 CKShare 生成 / 接受需要真 iCloud 账号，
// 无法在 headless CI 跑通 —— 见计划 Task 12 的真机验证清单。
// 本文件只测不依赖网络的纯域逻辑。

@MainActor
@Test func circleServiceRejectsEmptyName() async throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let service = CircleService(modelContext: container.mainContext)
    await #expect(throws: CircleServiceError.emptyCircleName) {
        _ = try await service.createCircle(name: "  \n ")
    }
}

@MainActor
@Test func circlesReadsBackInsertedCirclesNewestFirst() async throws {
    // circles() 只读本地 SwiftData 库，不触网 —— 可测。
    let container = try VoxlueModelContainer.make(inMemory: true)
    let context = container.mainContext
    let older = Circle(name: "旧圈", ownerID: "me", createdAt: Date(timeIntervalSince1970: 1000))
    let newer = Circle(name: "新圈", ownerID: "me", createdAt: Date(timeIntervalSince1970: 2000))
    context.insert(older)
    context.insert(newer)
    try context.save()

    let service = CircleService(modelContext: context)
    let all = try await service.circles()
    #expect(all.map(\.name) == ["新圈", "旧圈"])
}

@Test func shareURLRecognitionAcceptsICloudShareLinks() {
    #expect(FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://www.icloud.com/share/0ABCDEF")!))
    #expect(FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://www.icloud.com/share/fake-1234")!))
}

@Test func shareURLRecognitionRejectsNonShareLinks() {
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://example.com/share/abc")!))
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "https://www.icloud.com/photos/0ABC")!))
    #expect(!FakeCircleServicing.looksLikeShareURL(
        URL(string: "voxlue://capsule/123")!))
}
```

- [ ] **Step 2: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 输出含 `11 tests passed`（本计划累计：7 + 4）。`circleServiceRejectsEmptyName` 在校验抛错前不触网，故可在 headless 通过。

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Tests/VoxlueServicesTests/CircleServiceLogicTests.swift
git commit -m "test(circle): 补 CircleService 域逻辑测试（圈名校验/URL 识别/本地读取）"
```

---

## Task 5: CloudKit 共享库配置 【协作者】

计划 01 的 `voxule.entitlements` 已含 iCloud 容器 `iCloud.com.voxlue.app` 与 CloudKit 服务。声音圈共享额外需要：① 设备能接收 `CKShare` 接受事件；② App 声明能处理 `CKSharingSupported`。

**Files:**
- Modify: `voxule/voxule/voxule.entitlements`
- Modify: Xcode 工程的 `Info.plist` 配置（构建设置或 plist 文件）

- [ ] **Step 1: 确认 iCloud 能力已含 CloudKit（计划 01 已配，复核）**

打开 `voxule/voxule/voxule.entitlements`，确认含：

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array><string>iCloud.com.voxlue.app</string></array>
<key>com.apple.developer.icloud-services</key>
<array><string>CloudKit</string></array>
```

共享库（shared database）**不需要单独的 entitlement key** —— 它由同一个 `iCloud.com.voxlue.app` 容器承载，私有库 / 共享库 / 公共库都属于这一个容器。计划 01 的配置已足够，本步只复核，无需改 entitlements。

- [ ] **Step 2: 声明 App 支持接受 CloudKit 共享**

App 接受 `CKShare` 链接必须在 `Info.plist` 声明 `CKSharingSupported = YES`。本工程用构建设置注入 Info.plist 键（计划 01 已用 `INFOPLIST_KEY_UIBackgroundModes` 同款做法）。在 Xcode：TARGETS ▸ voxule ▸ Build Settings ▸ 搜索 `INFOPLIST_KEY` ▸ 用「+」加自定义键 `INFOPLIST_KEY_CKSharingSupported`，值设 `YES`。

> 若工程改用独立 `Info.plist` 文件，则在该文件加 `<key>CKSharingSupported</key><true/>`。Xcode 26 同步文件夹模板默认走构建设置注入。

- [ ] **Step 3: 确认 Background Modes 含 Remote notifications（计划 01 已配，复核）**

CloudKit 共享变更靠静默推送同步。计划 01 已配 `INFOPLIST_KEY_UIBackgroundModes = remote-notification`。在 Build Settings 搜 `UIBackgroundModes` 复核值为 `remote-notification`，无需改。

- [ ] **Step 4: headless 构建验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: 末行 `** BUILD SUCCEEDED **`（在仓库根目录 `/Users/cornna/project/voxule` 执行）。

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule.xcodeproj voxule/voxule/voxule.entitlements
git commit -m "chore(circle): 声明 CKSharingSupported，复核 CloudKit 共享库配置"
```

> **开发者账号前置（不进 git，写进 PR 描述）：** 真共享还需在 CloudKit Dashboard 为容器 `iCloud.com.voxlue.app` 部署 Schema（首次同步会自动建 `CD_*` record types，需在 Dashboard 把开发环境 Schema 部署到生产）；并以带 iCloud 能力的 Team 签名。这些是真机/真账号环节，headless 模拟器构建用 `CODE_SIGNING_ALLOWED=NO` 绕开。

---

## Task 6: 壳层 DI —— 把 CircleService 登记进 ServiceContainer 【前端】

App 壳层需把 `CircleServicing` 装配进依赖容器，供视图注入。计划 02 已建 `ServiceContainer`；本 Task 给它加一个 `circleService` 槽位。若计划 02 的 `ServiceContainer.swift` 尚不存在，按下面最小形态新建。

**Files:**
- Modify (或 Create): `voxule/voxule/ServiceContainer.swift`

- [ ] **Step 1: 在 ServiceContainer 登记 circleService**

打开 `voxule/voxule/ServiceContainer.swift`。**若文件已存在（计划 02 建）**，在其中加入 `circleService` 属性与构造逻辑；**若不存在**，新建为：

```swift
import Foundation
import SwiftData
import VoxlueData
import VoxlueServices

/// App 壳层的依赖容器 —— 集中装配领域服务，注入 SwiftUI 环境。
/// 计划 02 起逐计划扩充；本计划新增 `circleService`。
@MainActor
@Observable
public final class ServiceContainer {

    /// 声音圈服务（计划 05）。
    public let circleService: any CircleServicing

    public init(modelContext: ModelContext) {
        self.circleService = CircleService(modelContext: modelContext)
    }

    /// 预览 / UI 测试用 —— 全部服务走假实现。
    public static func preview() -> ServiceContainer {
        ServiceContainer(circleService: FakeCircleServicing(circles: [
            Circle(name: "家", ownerID: "me"),
            Circle(name: "大学室友", ownerID: "me"),
        ]))
    }

    private init(circleService: any CircleServicing) {
        self.circleService = circleService
    }
}
```

> 若计划 02 已建该文件：保留原有属性，仅新增 `circleService` 这一行属性、在 `init(modelContext:)` 里赋 `CircleService(modelContext:)`、在 `preview()` 里赋 `FakeCircleServicing(...)`。不要重写计划 02 的字段。

- [ ] **Step 2: 在环境里暴露 ServiceContainer**

确认 `ServiceContainer` 经 `.environment(_:)` 注入（计划 02 应已做）。若未做，在 Task 11 修改 `voxuleApp.swift` 时一并补 `.environment(serviceContainer)`。视图侧用 `@Environment(ServiceContainer.self)` 取。

- [ ] **Step 3: headless 构建验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/ServiceContainer.swift
git commit -m "feat(circle): ServiceContainer 登记 CircleService"
```

---

## Task 7: 建圈 UI —— CreateCircleView 【前端】

建圈表单。一个圈名输入框 + 「建好这个圈」按钮，确认即调 `CircleServicing.createCircle`。暗房纸感视觉用计划 04 的 `VoxlueDesign` 控件（若计划 04 已合入则 import；未合入则先用系统控件占位，视觉打磨留计划 04 联调）。

**Files:**
- Create: `voxule/voxule/Features/Circle/CreateCircleView.swift`

- [ ] **Step 1: 实现 CreateCircleView**

创建 `voxule/voxule/Features/Circle/CreateCircleView.swift`：

```swift
import SwiftUI
import VoxlueData
import VoxlueServices

/// 建一个新声音圈。圈名非空即可提交。
struct CreateCircleView: View {
    @Environment(ServiceContainer.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    /// 建圈成功回调，把新圈交回上层（如建完即推进详情页）。
    var onCreated: (Circle) -> Void = { _ in }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("给这个圈起个名字", text: $name)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("声音圈")
                } footer: {
                    Text("家人或挚友的小圈子。圈内能听到彼此埋下的胶囊。")
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("新建声音圈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建好这个圈") { submit() }
                        .disabled(trimmedName.isEmpty || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting { ProgressView() }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        errorText = nil
        Task {
            do {
                let circle = try await services.circleService.createCircle(name: trimmedName)
                isSubmitting = false
                onCreated(circle)
                dismiss()
            } catch CircleServiceError.emptyCircleName {
                errorText = "圈名不能为空。"
                isSubmitting = false
            } catch CircleServiceError.cloudKitUnavailable {
                errorText = "iCloud 暂时连不上，请稍后再建。"
                isSubmitting = false
            } catch {
                errorText = "建圈失败：\(error.localizedDescription)"
                isSubmitting = false
            }
        }
    }
}

#Preview {
    CreateCircleView()
        .environment(ServiceContainer.preview())
}
```

- [ ] **Step 2: headless 构建验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Features/Circle/CreateCircleView.swift
git commit -m "feat(circle): 新增建圈表单 CreateCircleView"
```

---

## Task 8: 声音圈列表 —— CircleListView 【前端】

声音圈列表页：展示当前用户全部圈，顶部「+」进建圈表单，点行进圈详情。

**Files:**
- Create: `voxule/voxule/Features/Circle/CircleListView.swift`

- [ ] **Step 1: 实现 CircleListView**

创建 `voxule/voxule/Features/Circle/CircleListView.swift`：

```swift
import SwiftUI
import VoxlueData
import VoxlueServices

/// 声音圈列表 —— 自建的与受邀加入的圈都在这里。
struct CircleListView: View {
    @Environment(ServiceContainer.self) private var services

    @State private var circles: [Circle] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("正在取声音圈…")
                } else if let loadError {
                    ContentUnavailableView(
                        "声音圈没取到",
                        systemImage: "exclamationmark.icloud",
                        description: Text(loadError)
                    )
                } else if circles.isEmpty {
                    ContentUnavailableView {
                        Label("还没有声音圈", systemImage: "person.2.wave.2")
                    } description: {
                        Text("建一个圈，把家人或挚友请进来。")
                    } actions: {
                        Button("建一个声音圈") { showCreateSheet = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(circles) { circle in
                        NavigationLink(value: circle.id) {
                            CircleRow(circle: circle)
                        }
                    }
                }
            }
            .navigationTitle("声音圈")
            .navigationDestination(for: UUID.self) { circleID in
                if let circle = circles.first(where: { $0.id == circleID }) {
                    CircleDetailView(circle: circle)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateCircleView(onCreated: { _ in Task { await reload() } })
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private func reload() async {
        isLoading = true
        loadError = nil
        do {
            circles = try await services.circleService.circles()
        } catch {
            loadError = "iCloud 暂时连不上。"
        }
        isLoading = false
    }
}

/// 列表里的一行圈。
private struct CircleRow: View {
    let circle: Circle

    private var memberCount: Int { circle.members?.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(circle.name.isEmpty ? "（未命名的圈）" : circle.name)
                .font(.headline)
            Text("\(memberCount) 位成员")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview("有圈") {
    CircleListView()
        .environment(ServiceContainer.preview())
}

#Preview("空") {
    CircleListView()
        .environment(ServiceContainer(circleService: FakeCircleServicing()))
}
```

> `#Preview("空")` 用到 `ServiceContainer(circleService:)`。Task 6 把该构造器设为 `private`；若需在预览直接构造，把它改成 `internal`（去掉 `private`），或在 `ServiceContainer` 上加一个 `static func previewEmpty()`。本计划采用后者更干净 —— 在 Task 6 的 `ServiceContainer` 里补一个 `static func previewEmpty() -> ServiceContainer { ServiceContainer(circleService: FakeCircleServicing()) }`，并把本预览改为 `ServiceContainer.previewEmpty()`。

- [ ] **Step 2: 给 ServiceContainer 补 previewEmpty**

打开 `voxule/voxule/ServiceContainer.swift`，在 `preview()` 旁加：

```swift
    /// 预览用 —— 没有任何圈的空状态。
    public static func previewEmpty() -> ServiceContainer {
        ServiceContainer(circleService: FakeCircleServicing())
    }
```

并把 `CircleListView.swift` 的 `#Preview("空")` 改为 `.environment(ServiceContainer.previewEmpty())`。

- [ ] **Step 3: headless 构建验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Features/Circle/CircleListView.swift voxule/voxule/ServiceContainer.swift
git commit -m "feat(circle): 新增声音圈列表 CircleListView"
```

---

## Task 9: 圈详情 —— 成员列表 + 圈内胶囊 + 发邀请 【前端】

圈详情页三块：① 圈成员列表；② 圈内胶囊浏览（`@Query` 按 `circleID` 过滤）；③ 「邀请新成员」按钮 → 调 `makeInvitation` → 弹 share sheet。share sheet 单独成 Task 10。

**Files:**
- Create: `voxule/voxule/Features/Circle/CircleDetailView.swift`

- [ ] **Step 1: 实现 CircleDetailView**

创建 `voxule/voxule/Features/Circle/CircleDetailView.swift`：

```swift
import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

/// 一个声音圈的详情 —— 成员、圈内胶囊、发邀请。
struct CircleDetailView: View {
    @Environment(ServiceContainer.self) private var services

    let circle: Circle

    @State private var invitation: ShareInvitation?
    @State private var isMakingInvitation = false
    @State private var errorText: String?

    private var members: [CircleMember] {
        (circle.members ?? []).sorted { $0.joinedAt < $1.joinedAt }
    }

    var body: some View {
        List {
            // 圈内胶囊。
            Section("圈里的声音") {
                CircleCapsulesList(circleID: circle.id)
            }

            // 成员。
            Section("成员（\(members.count)）") {
                ForEach(members) { member in
                    HStack {
                        Text(member.name.isEmpty ? "（无名）" : member.name)
                        Spacer()
                        Text(member.role == .owner ? "圈主" : "成员")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 发邀请。
            Section {
                Button {
                    makeInvitation()
                } label: {
                    Label("邀请新成员", systemImage: "person.crop.circle.badge.plus")
                }
                .disabled(isMakingInvitation)

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("生成一个链接，用 iMessage 或任意方式发给对方；对方点开即可加入。")
            }
        }
        .navigationTitle(circle.name.isEmpty ? "声音圈" : circle.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isMakingInvitation { ProgressView("正在生成邀请…") }
        }
        .sheet(item: $invitation) { invitation in
            ShareInvitationSheet(url: invitation.url)
        }
    }

    private func makeInvitation() {
        isMakingInvitation = true
        errorText = nil
        Task {
            do {
                invitation = try await services.circleService.makeInvitation(for: circle)
            } catch CircleServiceError.cloudKitUnavailable {
                errorText = "iCloud 暂时连不上，邀请没生成。"
            } catch {
                errorText = "生成邀请失败：\(error.localizedDescription)"
            }
            isMakingInvitation = false
        }
    }
}

/// 圈内胶囊浏览 —— 直接用 @Query 按 circleID 过滤本地库。
private struct CircleCapsulesList: View {
    @Query private var capsules: [VoxlueData.Capsule]

    init(circleID: UUID) {
        _capsules = Query(
            filter: #Predicate<VoxlueData.Capsule> { $0.circleID == circleID },
            sort: \.createdAt, order: .reverse
        )
    }

    var body: some View {
        if capsules.isEmpty {
            Text("圈里还没有声音。装裱一枚胶囊时选这个圈，它就会出现在这里。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ForEach(capsules) { capsule in
                VStack(alignment: .leading, spacing: 2) {
                    Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                    Text("\(capsule.authorName.isEmpty ? "某人" : capsule.authorName) · \(capsule.state.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// ShareInvitation 用作 .sheet(item:) 的标识需 Identifiable —— 协议在 VoxlueServices，
// 这里在 App 侧补一个 conformance（URL 唯一可作 id）。
extension ShareInvitation: @retroactive Identifiable {
    public var id: URL { url }
}

#Preview {
    NavigationStack {
        CircleDetailView(circle: {
            let c = Circle(name: "家", ownerID: "me")
            c.members = [
                CircleMember(name: "我", userRecordID: "me", role: .owner),
                CircleMember(name: "奶奶", userRecordID: "nana", role: .member),
            ]
            return c
        }())
    }
    .environment(ServiceContainer.preview())
    .modelContainer(for: VoxlueData.Capsule.self, inMemory: true)
}
```

- [ ] **Step 2: headless 构建验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Features/Circle/CircleDetailView.swift
git commit -m "feat(circle): 新增圈详情页（成员/圈内胶囊/发邀请）"
```

---

## Task 10: 邀请 share sheet —— ShareInvitationSheet 【前端】

把 `CKShare URL` 经 `UIActivityViewController`（share sheet）发出 —— 用户可选 iMessage、复制链接、AirDrop 等。SwiftUI 无原生包装，用 `UIViewControllerRepresentable` 桥接。

**Files:**
- Create: `voxule/voxule/Features/Circle/ShareInvitationSheet.swift`

- [ ] **Step 1: 实现 ShareInvitationSheet**

创建 `voxule/voxule/Features/Circle/ShareInvitationSheet.swift`：

```swift
import SwiftUI
import UIKit

/// 把一个 CKShare 邀请链接交给系统 share sheet（iMessage / 复制 / AirDrop…）。
struct ShareInvitationSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [InvitationActivityItem(url: url)],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 给 share sheet 一段友好的随附文案（发 iMessage 时的引导语）。
private final class InvitationActivityItem: NSObject, UIActivityItemSource {
    let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "请你加入我的声音圈"
    }
}

#Preview {
    ShareInvitationSheet(url: URL(string: "https://www.icloud.com/share/fake-preview")!)
}
```

- [ ] **Step 2: headless 构建验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Features/Circle/ShareInvitationSheet.swift
git commit -m "feat(circle): 新增邀请 share sheet（UIActivityViewController 桥接）"
```

---

## Task 11: 深链 —— 接住进站的 CKShare 链接 【前端 + 协作者】

受邀者点击 `CKShare` 链接，系统把 App 唤起并回调 `userDidAcceptCloudKitShareWith` / SwiftUI 的 `.onCloudKitShareAccepted`。壳层负责接住事件并路由（**前端**），实际接受动作转交 `CircleServicing.acceptShare`（**协作者**交付的服务调用）。

**Files:**
- Create: `voxule/voxule/DeepLinkRouter.swift`
- Modify: `voxule/voxule/voxuleApp.swift`

- [ ] **Step 1: 实现 DeepLinkRouter**

创建 `voxule/voxule/DeepLinkRouter.swift`：

```swift
import SwiftUI
import VoxlueServices

/// 壳层深链路由 —— 目前只处理一种深链：进站的 CKShare 邀请。
/// 接受动作转交 CircleServicing；本类只管「接住事件 → 调服务 → 暴露结果给 UI」。
@MainActor
@Observable
final class DeepLinkRouter {

    /// 一次共享接受的结果，驱动落地页。
    enum AcceptanceState: Equatable {
        case idle
        case accepting
        case accepted
        case failed(String)
    }

    private(set) var acceptance: AcceptanceState = .idle

    private let circleService: any CircleServicing

    init(circleService: any CircleServicing) {
        self.circleService = circleService
    }

    /// 收到一个进站的 CKShare 链接 —— 接受它。
    func handleIncomingShare(url: URL) {
        acceptance = .accepting
        Task {
            do {
                try await circleService.acceptShare(from: url)
                acceptance = .accepted
            } catch CircleServiceError.invalidInvitationURL {
                acceptance = .failed("这不是一个有效的声音圈邀请链接。")
            } catch CircleServiceError.cloudKitUnavailable {
                acceptance = .failed("iCloud 暂时连不上，没能加入圈。")
            } catch {
                acceptance = .failed("加入失败：\(error.localizedDescription)")
            }
        }
    }

    /// 落地页关闭后复位。
    func reset() {
        acceptance = .idle
    }
}
```

- [ ] **Step 2: 壳层接住 CKShare 事件并注入路由**

把 `voxule/voxule/voxuleApp.swift` 全文替换为：

```swift
//
//  voxuleApp.swift
//  voxule
//

import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

@main
struct voxuleApp: App {
    private let modelContainer: ModelContainer
    @State private var services: ServiceContainer
    @State private var router: DeepLinkRouter

    init() {
        // 优先用生产配置 —— 镜像到 CloudKit 私有库。
        // 若 CloudKit 不可用（未登录 iCloud、缺能力配置等），降级为纯本地存储。
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
        self.modelContainer = container
        let serviceContainer = ServiceContainer(modelContext: container.mainContext)
        _services = State(initialValue: serviceContainer)
        _router = State(initialValue: DeepLinkRouter(circleService: serviceContainer.circleService))
    }

    var body: some Scene {
        WindowGroup {
            DebugRootView()
                .environment(services)
                .environment(router)
                // 进站的 CloudKit 共享邀请 —— 受邀者点链接唤起 App 时触发。
                .onCloudKitShareAccepted { url in
                    router.handleIncomingShare(url: url)
                }
                // 兜底：以普通 universal link 形式进站的 icloud.com/share 链接。
                .onOpenURL { url in
                    if FakeCircleServicing.looksLikeShareURL(url) {
                        router.handleIncomingShare(url: url)
                    }
                }
                .sheet(isPresented: shareAcceptanceSheetBinding) {
                    AcceptInvitationView()
                        .environment(router)
                }
        }
        .modelContainer(modelContainer)
    }

    /// 接受流程进行中或已出结果时，弹落地页。
    private var shareAcceptanceSheetBinding: Binding<Bool> {
        Binding(
            get: { router.acceptance != .idle },
            set: { if !$0 { router.reset() } }
        )
    }
}

/// SwiftUI 把进站 CKShare 链接交给 App 的修饰符封装。
/// iOS 26 用 scene 的 `userDidAcceptCloudKitShareWith` 委托；这里用
/// `onContinueUserActivity` 接 CloudKit 共享元数据 activity，统一回吐 share URL。
private struct CloudKitShareAcceptedModifier: ViewModifier {
    let handler: (URL) -> Void

    func body(content: Content) -> some View {
        content.onContinueUserActivity(
            "com.apple.coredata.cloudkit.share"
        ) { activity in
            if let url = activity.webpageURL {
                handler(url)
            }
        }
    }
}

private extension View {
    func onCloudKitShareAccepted(_ handler: @escaping (URL) -> Void) -> some View {
        modifier(CloudKitShareAcceptedModifier(handler: handler))
    }
}
```

> **实现备注（写进 PR 描述）：** `com.apple.coredata.cloudkit.share` 是 SwiftData CloudKit 镜像接受共享时回吐的 `NSUserActivity` 类型。若运行期实测该 activity 不回吐 URL，**这正是 §13 隔离层的价值** —— 改为在 `UIApplicationDelegate` 的 `application(_:userDidAcceptCloudKitShareWith:)` 里把 `CKShare.Metadata` 直接交给 `CircleService`（给 `CircleServicing` 加一个 `acceptShare(metadata:)` 重载需走契约变更流程）。v1 先用 URL 路径，真机验证见 Task 12。

- [ ] **Step 3: headless 构建验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/DeepLinkRouter.swift voxule/voxule/voxuleApp.swift
git commit -m "feat(circle): 壳层接住进站 CKShare 链接并路由"
```

---

## Task 12: 接受邀请落地页 —— AcceptInvitationView 【前端】

受邀者接受流程的可视落地页：进行中转圈、成功提示、失败给原因。由 `DeepLinkRouter.acceptance` 驱动。

**Files:**
- Create: `voxule/voxule/Features/Circle/AcceptInvitationView.swift`

- [ ] **Step 1: 实现 AcceptInvitationView**

创建 `voxule/voxule/Features/Circle/AcceptInvitationView.swift`：

```swift
import SwiftUI

/// 接受声音圈邀请的落地页 —— 由 DeepLinkRouter.acceptance 驱动。
struct AcceptInvitationView: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            switch router.acceptance {
            case .idle:
                Color.clear

            case .accepting:
                ProgressView()
                Text("正在把你请进这个声音圈…")
                    .font(.headline)

            case .accepted:
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("你已加入这个声音圈")
                    .font(.title3.weight(.semibold))
                Text("圈里的声音会慢慢同步到你这边。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("好的") { dismiss() }
                    .buttonStyle(.borderedProminent)

            case .failed(let reason):
                Image(systemName: "xmark.octagon")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                Text("没能加入")
                    .font(.title3.weight(.semibold))
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .presentationDetents([.medium])
    }
}

#Preview("接受中") {
    AcceptInvitationView()
        .environment(previewRouter(.accepting))
}

#Preview("已加入") {
    AcceptInvitationView()
        .environment(previewRouter(.accepted))
}

#Preview("失败") {
    AcceptInvitationView()
        .environment(previewRouter(.failed("这不是一个有效的声音圈邀请链接。")))
}

// 预览辅助：构造一个停在指定状态的 router。
@MainActor
private func previewRouter(_ state: DeepLinkRouter.AcceptanceState) -> DeepLinkRouter {
    let router = DeepLinkRouter(circleService: FakeCircleServicing())
    switch state {
    case .accepting:
        router.handleIncomingShare(url: URL(string: "https://www.icloud.com/share/preview")!)
    case .failed:
        router.handleIncomingShare(url: URL(string: "https://example.com/bad")!)
    default:
        break
    }
    return router
}
```

> 预览里直接构造预期状态比较绕（`acceptance` 是 `private(set)`）。`previewRouter` 用真实调用把 router 推到对应状态：合法 URL → `.accepting` 随后 `.accepted`；非法 URL → `.failed`。需 `import VoxlueServices`，在文件顶部补 `import VoxlueServices`。

- [ ] **Step 2: 补 import 并构建验证**

在 `AcceptInvitationView.swift` 顶部 `import SwiftUI` 下补一行 `import VoxlueServices`。

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Features/Circle/AcceptInvitationView.swift
git commit -m "feat(circle): 新增接受邀请落地页 AcceptInvitationView"
```

---

## Task 13: 装裱时选「声音圈」收件人 —— CirclePickerView 【前端】

接计划 02 的装裱 UI：当用户在埋下流程把收件人选为「声音圈」时，需进一步选**哪个**圈，把选中的 `Circle.id` 写进 `Capsule.circleID`。本 Task 交付一个可复用的圈选择视图，并标注与计划 02 的接入点。

**Files:**
- Create: `voxule/voxule/Features/Circle/CirclePickerView.swift`

- [ ] **Step 1: 实现 CirclePickerView**

创建 `voxule/voxule/Features/Circle/CirclePickerView.swift`：

```swift
import SwiftUI
import VoxlueData
import VoxlueServices

/// 装裱胶囊时选「埋给哪个声音圈」。
/// 计划 02 的装裱 UI 在 recipient == .circle 时嵌入本视图，
/// 把选中圈的 id 回写到正在装裱的 Capsule.circleID。
struct CirclePickerView: View {
    @Environment(ServiceContainer.self) private var services

    /// 当前选中的圈 id —— 与计划 02 装裱表单的 Capsule.circleID 双向绑定。
    @Binding var selectedCircleID: UUID?

    @State private var circles: [Circle] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if isLoading {
                HStack { ProgressView(); Text("正在取声音圈…") }
            } else if circles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("你还没有声音圈。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("先建一个声音圈") { showCreateSheet = true }
                }
            } else {
                ForEach(circles) { circle in
                    Button {
                        selectedCircleID = circle.id
                    } label: {
                        HStack {
                            Text(circle.name.isEmpty ? "（未命名的圈）" : circle.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCircleID == circle.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCircleView(onCreated: { circle in
                selectedCircleID = circle.id
                Task { await reload() }
            })
        }
        .task { await reload() }
    }

    private func reload() async {
        isLoading = true
        circles = (try? await services.circleService.circles()) ?? []
        // 若当前选中的圈已不存在，清空选择。
        if let id = selectedCircleID, !circles.contains(where: { $0.id == id }) {
            selectedCircleID = nil
        }
        isLoading = false
    }
}

#Preview {
    @Previewable @State var selected: UUID?
    return Form {
        Section("埋给哪个圈") {
            CirclePickerView(selectedCircleID: $selected)
        }
    }
    .environment(ServiceContainer.preview())
}
```

- [ ] **Step 2: 标注与计划 02 的接入点（不写代码，留记录）**

在本 Task 的 PR 描述里写清接入指引，供计划 02 的装裱表单接入：

> 计划 02 的装裱表单（埋下流程）已有收件人 `Picker`（`Recipient.me / .circle / .publicMap`）。当 `recipient == .circle` 时，在表单里追加一个 `Section`，内嵌 `CirclePickerView(selectedCircleID: $draft.circleID)`，其中 `$draft.circleID` 是装裱草稿模型的 `circleID` 字段。最终提交装裱时，把 `draft.circleID` 赋给新建 `Capsule` 的 `circleID`（计划 01 的 `Capsule` 已有该字段）。**约束（架构 §8）：收件人埋下时定死，胶囊建好后 `recipient` 与 `circleID` 不可改。** 装裱表单须在 `recipient == .circle` 而 `circleID == nil` 时禁用「埋下」按钮。

> 依赖说明：本 Task 产物（`CirclePickerView`）依赖计划 02 的装裱 UI 才能完整发挥；若计划 02 的装裱表单尚未合入，`CirclePickerView` 仍可独立编译与预览，接入留作两计划联调。

- [ ] **Step 3: headless 构建验证**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/Features/Circle/CirclePickerView.swift
git commit -m "feat(circle): 新增装裱时的声音圈选择器 CirclePickerView"
```

---

## Task 14: UI 行为测试 —— DeepLinkRouter 对 Fake 的反应 【前端】

UI 逻辑里最值得测的是 `DeepLinkRouter` 对 `CircleServicing` 的编排 —— 合法链接走通、非法链接报错。视图层（`UIActivityViewController` / SwiftUI 渲染）不做 headless 测试，靠 `#Preview` 与 Task 15 的真机走查。`DeepLinkRouter` 在 App target，用 App 的 UI 测试 target 承载其单元测试，或把 router 逻辑测试放进既有测试 target。

**Files:**
- Create: `voxule/voxuleTests/DeepLinkRouterTests.swift`

- [ ] **Step 1: 写测试**

创建 `voxule/voxuleTests/DeepLinkRouterTests.swift`：

```swift
import Testing
import Foundation
import VoxlueServices
@testable import voxule

// DeepLinkRouter 编排 CircleServicing —— 用 FakeCircleServicing 注入，全程不触网。

@MainActor
@Test func routerStartsIdle() {
    let router = DeepLinkRouter(circleService: FakeCircleServicing())
    #expect(router.acceptance == .idle)
}

@MainActor
@Test func routerAcceptsValidShareURL() async {
    let fake = FakeCircleServicing()
    let router = DeepLinkRouter(circleService: fake)
    router.handleIncomingShare(url: URL(string: "https://www.icloud.com/share/0ABC")!)

    // handleIncomingShare 内是 Task，轮询等待终态。
    try? await waitUntilSettled(router)
    #expect(router.acceptance == .accepted)
    #expect(try! await fake.circles().count == 1)
}

@MainActor
@Test func routerRejectsInvalidShareURL() async {
    let router = DeepLinkRouter(circleService: FakeCircleServicing())
    router.handleIncomingShare(url: URL(string: "https://example.com/not-a-share")!)
    try? await waitUntilSettled(router)
    if case .failed = router.acceptance {
        #expect(Bool(true))
    } else {
        Issue.record("应停在 .failed，实际为 \(router.acceptance)")
    }
}

@MainActor
@Test func routerResetReturnsToIdle() async {
    let router = DeepLinkRouter(circleService: FakeCircleServicing())
    router.handleIncomingShare(url: URL(string: "https://www.icloud.com/share/0ABC")!)
    try? await waitUntilSettled(router)
    router.reset()
    #expect(router.acceptance == .idle)
}

/// 轮询直到 router 离开 .accepting（最多约 1 秒）。
@MainActor
private func waitUntilSettled(_ router: DeepLinkRouter) async throws {
    for _ in 0..<100 {
        if router.acceptance != .accepting && router.acceptance != .idle { return }
        try await Task.sleep(for: .milliseconds(10))
    }
}
```

> 注意：`DeepLinkRouter` 与 `voxuleApp` 同在 App target。若计划 01/02 建的测试 target 名为 `voxuleTests`，本文件放入其中并 `@testable import voxule`（target 名小写）。`AcceptanceState` 已是 `Equatable`，`.idle` / `.accepted` 可直接 `#expect` 比较。

- [ ] **Step 2: 运行 App target 测试**

Run: `xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO`
Expected: 末段 `Test Suite 'voxuleTests' passed`，含本计划新增 4 个测试通过。

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxuleTests/DeepLinkRouterTests.swift
git commit -m "test(circle): 新增 DeepLinkRouter 对 FakeCircleServicing 的行为测试"
```

---

## Task 15: 端到端走查与真机/真账号验证清单 【前端 + 协作者】

把声音圈接进 App 主导航并跑通整条链路。**带 Fake 的部分可在模拟器走查；真 CKShare 同步/接受需真 iCloud 账号 + 真机**，本 Task 诚实列出哪些步骤属于后者。

**Files:**
- Modify: `voxule/voxule/DebugRootView.swift`（加一个进声音圈的入口；计划后续被正式导航替换）

- [ ] **Step 1: 在 DebugRootView 加声音圈入口**

打开 `voxule/voxule/DebugRootView.swift`，在 `.toolbar` 里追加一个跳转 `CircleListView` 的入口（`NavigationLink` 或 `sheet`）。最小改法 —— 在现有 `Button("加一枚样本")` 旁加：

```swift
                NavigationLink {
                    CircleListView()
                } label: {
                    Image(systemName: "person.2.wave.2")
                }
```

确保 `DebugRootView` 已能取到 `ServiceContainer`（`voxuleApp` 已 `.environment(services)`）。

- [ ] **Step 2: 模拟器走查（Fake 链路，无需 iCloud 账号）**

在 iPhone 17 模拟器运行 App（Xcode ⌘R），逐项确认：
1. 进「声音圈」→ 空状态显示「建一个声音圈」。
2. 建圈「家」→ 列表出现「家」，显示「1 位成员」。
3. 进「家」详情 → 成员列表有「我（圈主）」；「圈里的声音」为空提示。
4. 点「邀请新成员」→ 弹出 share sheet（Fake 给出 `https://www.icloud.com/share/fake-…` 链接）。

> 这一步用真实 `CircleService` 时，模拟器未登录 iCloud 会让 `createCircle` 抛 `cloudKitUnavailable`。走查 UI 链路时可临时在 `ServiceContainer.init` 注入 `FakeCircleServicing`，或在已登录 iCloud 的模拟器上跑。

- [ ] **Step 3: headless 全量构建 + 测试**

Run（仓库根 `/Users/cornna/project/voxule`）：
```bash
cd /Users/cornna/project/voxule/VoxlueKit && swift test
```
Expected: `swift test` 全绿，含本计划 `VoxlueServicesTests` 的 11 个测试。

Run：
```bash
xcodebuild -project /Users/cornna/project/voxule/voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```
Expected: `** TEST SUCCEEDED **`，含 `DeepLinkRouterTests` 4 个测试。

- [ ] **Step 4: 真机 / 真账号验证清单（无法 headless，须手动）**

以下步骤**需要 Apple Developer 账号、真机两台（或两个 iCloud 账号）、CloudKit Dashboard 已部署 Schema**，不进 CI，由开发者手动核对并把结果记进计划尾的「执行后修订记录」：

1. 设备 A 登录 iCloud，以带 iCloud 能力的 Team 签名安装 App，建圈「家」→ 确认 `CircleService.createCircle` 不抛 `cloudKitUnavailable`、`Circle` 出现在 CloudKit Dashboard 私有库。
2. 设备 A 点「邀请新成员」→ share sheet 经 iMessage 把 `CKShare URL` 发给设备 B。
3. 设备 B（不同 iCloud 账号）点链接 → App 唤起 → `AcceptInvitationView` 走「接受中 → 已加入」。
4. 设备 A 在「家」装裱一枚胶囊（recipient = 声音圈，选「家」）→ 等待同步 → 设备 B 的「家」详情「圈里的声音」出现该胶囊，音频可回放（验证 `CKAsset` 同步）。
5. 若第 3 步 `onContinueUserActivity("com.apple.coredata.cloudkit.share")` 未回吐 URL，按 Task 11 实现备注切到 `AppDelegate` 的 `userDidAcceptCloudKitShareWith` 路径 —— 这属 §13 隔离预案，只动 `CircleService` 与壳层，不动前端 UI 与协议。

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/DebugRootView.swift
git commit -m "feat(circle): DebugRootView 加声音圈入口，端到端走查通过"
```

---

## 完成标准

- `cd /Users/cornna/project/voxule/VoxlueKit && swift test` 全绿 —— 含本计划 `VoxlueServicesTests` 新增 11 个测试（`ShareInvitation`、`FakeCircleServicing` 行为、`CircleService` 域逻辑、URL 识别）。
- `xcodebuild ... -scheme voxule ... test CODE_SIGNING_ALLOWED=NO` 全绿 —— 含 `DeepLinkRouterTests` 4 个测试。
- `xcodebuild ... -scheme voxule ... build CODE_SIGNING_ALLOWED=NO` 输出 `** BUILD SUCCEEDED **`。
- `CircleServicing` 协议 + `ShareInvitation` 与路线图 §3.3 逐字一致；`CircleService` 真实现 + `FakeCircleServicing` 假实现均已交付，调用方只依赖协议（§13 隔离层成立）。
- CloudKit 共享库配置就位：`CKSharingSupported` 已声明，iCloud 容器 / Background Modes 复核无误。
- 前端交付：建圈、圈列表、圈详情（成员 + 圈内胶囊 + 发邀请）、邀请 share sheet、接受邀请落地页、装裱时的声音圈选择器，全部可构建、有 `#Preview`。
- 壳层接住进站 `CKShare` 链接并路由至 `CircleServicing.acceptShare`。
- 模拟器走查（Fake 链路）通过；真机 / 真账号验证清单（Task 15 Step 4）已列明，待开发者环境核对。
- 全部改动已分 Task 提交 git，提交信息为中文 conventional commits。

下一份计划：**计划 06 · 云端 agent 闭环**。
