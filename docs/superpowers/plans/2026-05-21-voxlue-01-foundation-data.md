# voxlue 计划 01 · 项目骨架与数据层 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 Voxlue 的 Xcode 项目骨架、VoxlueKit 本地包与 VoxlueData 模块，落地 SwiftData 数据模型、容器工厂与 CapsuleStore，全部带单元测试，并在 App 里端到端验证。

**Architecture:** iOS 26 / SwiftUI 应用 + 一个本地 SPM 包 `VoxlueKit`（含 `VoxlueData` 库目标）。数据层用 SwiftData，`@Model` 模型遵守 CloudKit 镜像约束（属性全部可选或带默认值、无 `.unique`、关系可选）。`VoxlueModelContainer` 工厂提供生产配置（CloudKit 私有库镜像）与测试配置（内存）。`CapsuleStore` 封装所有写操作。

**Tech Stack:** Swift 6 · SwiftUI · SwiftData · CloudKit · Swift Testing · Xcode 26

**前置条件:** 已安装 Xcode 26+；已登录一个 Apple Developer 账号（CloudKit 需要）；macOS 26（用于 `swift test`）。

**对应设计文档:** `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md` 的 §3、§5、§12（CapsuleStore 部分）。

---

## 文件结构

```
/Users/cornna/project/voxlue/
├── Voxlue/                          Xcode 应用项目
│   ├── Voxlue.xcodeproj
│   └── Voxlue/
│       ├── VoxlueApp.swift          App 入口（接入 modelContainer）
│       └── DebugRootView.swift      临时调试视图（计划 02 替换）
├── VoxlueKit/                       本地 SPM 包
│   ├── Package.swift
│   ├── Sources/VoxlueData/
│   │   ├── Enums.swift              Recipient · CapsuleState · CircleRole
│   │   ├── Lock.swift               Lock 枚举（Codable 带关联值）
│   │   ├── Capsule.swift            @Model
│   │   ├── Circle.swift             @Model Circle · CircleMember
│   │   ├── VoxlueModelContainer.swift  容器工厂
│   │   └── CapsuleStore.swift       写操作封装
│   └── Tests/VoxlueDataTests/
│       ├── EnumsTests.swift
│       ├── LockTests.swift
│       ├── CapsuleTests.swift
│       ├── CircleTests.swift
│       ├── ModelContainerTests.swift
│       └── CapsuleStoreTests.swift
├── docs/
└── .gitignore
```

---

## Task 1: Xcode 项目骨架与 git 初始化

**Files:**
- Create: `Voxlue/Voxlue.xcodeproj`（Xcode 生成）
- Create: `Voxlue/Voxlue/VoxlueApp.swift`（Xcode 生成）
- Create: `/Users/cornna/project/voxlue/.gitignore`

- [ ] **Step 1: 用 Xcode 创建项目**

打开 Xcode → File ▸ New ▸ Project ▸ iOS ▸ App，按下表填写后 Next：

| 字段 | 值 |
|---|---|
| Product Name | `Voxlue` |
| Organization Identifier | `com.voxlue` |
| Bundle Identifier（自动） | `com.voxlue.app` |
| Interface | SwiftUI |
| Language | Swift |
| Testing System | Swift Testing |
| Storage | None |

保存位置选 `/Users/cornna/project/voxlue`。完成后项目位于 `/Users/cornna/project/voxlue/Voxlue/Voxlue.xcodeproj`。

- [ ] **Step 2: 设置部署目标为 iOS 26.0**

在 Xcode 选中 Voxlue 工程 ▸ TARGETS ▸ Voxlue ▸ General ▸ Minimum Deployments ▸ iOS 设为 `26.0`。

- [ ] **Step 3: 创建 .gitignore 并初始化 git**

创建 `/Users/cornna/project/voxlue/.gitignore`，内容：

```gitignore
# macOS
.DS_Store

# Xcode
xcuserdata/
*.xcuserstate
DerivedData/
build/

# Swift Package Manager
.build/
.swiftpm/

# 头脑风暴可视化伴侣（不入库）
.superpowers/
```

然后初始化仓库并首次提交：

```bash
cd /Users/cornna/project/voxlue
git init
git add .gitignore Voxlue docs
git commit -m "chore: 初始化 Voxlue iOS 项目骨架"
```

- [ ] **Step 4: 验证项目可构建**

Run: `cd /Users/cornna/project/voxlue/Voxlue && xcodebuild -scheme Voxlue -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: 末行输出 `** BUILD SUCCEEDED **`

---

## Task 2: VoxlueKit 本地包与 VoxlueData 模块

**Files:**
- Create: `VoxlueKit/Package.swift`
- Create: `VoxlueKit/Sources/VoxlueData/Placeholder.swift`
- Create: `VoxlueKit/Tests/VoxlueDataTests/SmokeTests.swift`

- [ ] **Step 1: 创建包目录与 Package.swift**

创建 `VoxlueKit/Package.swift`：

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VoxlueKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "VoxlueData", targets: ["VoxlueData"]),
    ],
    targets: [
        .target(name: "VoxlueData"),
        .testTarget(name: "VoxlueDataTests", dependencies: ["VoxlueData"]),
    ]
)
```

- [ ] **Step 2: 创建占位源文件与冒烟测试**

创建 `VoxlueKit/Sources/VoxlueData/Placeholder.swift`：

```swift
// VoxlueData 模块。模型与数据服务在后续任务中加入。
enum VoxlueDataModule {}
```

创建 `VoxlueKit/Tests/VoxlueDataTests/SmokeTests.swift`：

```swift
import Testing
@testable import VoxlueData

@Test func moduleLoads() {
    #expect(true)
}
```

- [ ] **Step 3: 验证包可测试**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: 输出包含 `Test run with 1 test passed`

- [ ] **Step 4: 把 VoxlueKit 加为本地包依赖**

在 Xcode：File ▸ Add Package Dependencies ▸ 左下角 Add Local ▸ 选 `/Users/cornna/project/voxlue/VoxlueKit` ▸ Add Package。然后 TARGETS ▸ Voxlue ▸ General ▸ Frameworks, Libraries, and Embedded Content ▸ `+` ▸ 添加 `VoxlueData`。

- [ ] **Step 5: 验证 App 仍可构建并提交**

Run: `cd /Users/cornna/project/voxlue/Voxlue && xcodebuild -scheme Voxlue -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

```bash
cd /Users/cornna/project/voxlue
git add VoxlueKit Voxlue
git commit -m "chore: 新增 VoxlueKit 本地包与 VoxlueData 模块"
```

---

## Task 3: 基础枚举 — Recipient · CapsuleState · CircleRole

**Files:**
- Create: `VoxlueKit/Sources/VoxlueData/Enums.swift`
- Test: `VoxlueKit/Tests/VoxlueDataTests/EnumsTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDataTests/EnumsTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueData

@Test func recipientHasThreeCases() {
    #expect(Recipient.allCases.count == 3)
}

@Test func capsuleStateHasFourCases() {
    #expect(CapsuleState.allCases.count == 4)
}

@Test func circleRoleHasTwoCases() {
    #expect(CircleRole.allCases.count == 2)
}

@Test func recipientCodableRoundTrip() throws {
    let data = try JSONEncoder().encode(Recipient.circle)
    let decoded = try JSONDecoder().decode(Recipient.self, from: data)
    #expect(decoded == .circle)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `Recipient` / `CapsuleState` / `CircleRole`

- [ ] **Step 3: 实现枚举**

创建 `VoxlueKit/Sources/VoxlueData/Enums.swift`：

```swift
import Foundation

/// 胶囊的收件人。
public enum Recipient: String, Codable, CaseIterable, Sendable {
    case me           // 自己
    case circle       // 声音圈
    case publicMap    // 公开（v1.1 落地）
}

/// 胶囊的显影状态机。
public enum CapsuleState: String, Codable, CaseIterable, Sendable {
    case buried       // 已埋下 · 潜伏
    case developing   // 显影中 · 灵动岛 + 霜化动效
    case developed    // 已显影 · 等你听
    case opened       // 已开启
}

/// 声音圈成员角色。
public enum CircleRole: String, Codable, CaseIterable, Sendable {
    case owner
    case member
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: `Test run with 5 tests passed`（1 冒烟 + 4 枚举）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxlue
git add VoxlueKit/Sources/VoxlueData/Enums.swift VoxlueKit/Tests/VoxlueDataTests/EnumsTests.swift
git commit -m "feat(data): 新增 Recipient/CapsuleState/CircleRole 枚举"
```

---

## Task 4: Lock 枚举（Codable 带关联值）

**Files:**
- Create: `VoxlueKit/Sources/VoxlueData/Lock.swift`
- Test: `VoxlueKit/Tests/VoxlueDataTests/LockTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDataTests/LockTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueData

@Test func placeLockRoundTrip() throws {
    let lock = Lock.place(latitude: 31.21, longitude: 121.43, radius: 80, placeName: "武康 × 巨鹿")
    let data = try JSONEncoder().encode(lock)
    let decoded = try JSONDecoder().decode(Lock.self, from: data)
    #expect(decoded == lock)
}

@Test func dateLockRoundTrip() throws {
    let lock = Lock.date(Date(timeIntervalSince1970: 1_800_000_000))
    let data = try JSONEncoder().encode(lock)
    let decoded = try JSONDecoder().decode(Lock.self, from: data)
    #expect(decoded == lock)
}

@Test func moodLockRoundTrip() throws {
    let lock = Lock.mood(notBefore: nil)
    let data = try JSONEncoder().encode(lock)
    let decoded = try JSONDecoder().decode(Lock.self, from: data)
    #expect(decoded == lock)
}

@Test func moodLockKindIsMood() {
    #expect(Lock.mood(notBefore: nil).kind == .mood)
    #expect(Lock.date(.now).kind == .date)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `Lock`

- [ ] **Step 3: 实现 Lock**

创建 `VoxlueKit/Sources/VoxlueData/Lock.swift`：

```swift
import Foundation

/// 胶囊的锁 —— 解锁条件。三选一。
/// 作为一个属性存在 Capsule 上，不单独建表。
public enum Lock: Codable, Hashable, Sendable {
    /// 地点锁：经纬度 + 半径（米）+ 地名。
    case place(latitude: Double, longitude: Double, radius: Double, placeName: String)
    /// 时间锁：未来某一天。
    case date(Date)
    /// 情绪锁：主动浮现。notBefore 之前不浮现。
    case mood(notBefore: Date?)

    /// 锁的种类，便于不取关联值时判断。
    public enum Kind: String, Sendable {
        case place, date, mood
    }

    public var kind: Kind {
        switch self {
        case .place: .place
        case .date: .date
        case .mood: .mood
        }
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: `Test run with 9 tests passed`（累计：1 + 4 + 4 锁）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxlue
git add VoxlueKit/Sources/VoxlueData/Lock.swift VoxlueKit/Tests/VoxlueDataTests/LockTests.swift
git commit -m "feat(data): 新增 Lock 枚举（地点/时间/情绪三把锁）"
```

---

## Task 5: Capsule 模型（@Model）

**Files:**
- Create: `VoxlueKit/Sources/VoxlueData/Capsule.swift`
- Test: `VoxlueKit/Tests/VoxlueDataTests/CapsuleTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDataTests/CapsuleTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import VoxlueData

@MainActor
@Test func capsuleInsertAndFetch() throws {
    let container = try ModelContainer(
        for: Capsule.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    let capsule = Capsule(title: "咖啡馆的雨", lock: .date(Date(timeIntervalSince1970: 1_800_000_000)))
    context.insert(capsule)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Capsule>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.title == "咖啡馆的雨")
    #expect(fetched.first?.state == .buried)
    #expect(fetched.first?.lock.kind == .date)
}

@MainActor
@Test func capsuleDefaultsAreSafeForCloudKit() throws {
    let capsule = Capsule()
    // CloudKit 镜像要求非可选属性全部有默认值。
    #expect(capsule.title == "")
    #expect(capsule.state == .buried)
    #expect(capsule.recipient == .me)
    #expect(capsule.waveform.isEmpty)
    #expect(capsule.tags.isEmpty)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `Capsule`

- [ ] **Step 3: 实现 Capsule**

创建 `VoxlueKit/Sources/VoxlueData/Capsule.swift`：

```swift
import Foundation
import SwiftData

/// 声音胶囊 —— 产品的核心实体。
/// CloudKit 镜像约束：所有属性可选或带默认值；无 `@Attribute(.unique)`；关系可选。
@Model
public final class Capsule {
    public var id: UUID = UUID()
    public var title: String = ""

    /// 音频以外部文件存储，CloudKit 镜像时自动变 CKAsset。
    @Attribute(.externalStorage) public var audioData: Data?

    public var duration: TimeInterval = 0
    /// 预算好的声纹采样，绘制用，避免每次解码音频。
    public var waveform: [Float] = []

    public var state: CapsuleState = CapsuleState.buried

    /// Lock 以 JSON 编码后存为 Data。SwiftData 无法可靠持久化「带关联值的 Codable
    /// 枚举」—— 直接存 `Lock` 会在二次保存时触发 Core Data「required value」校验失败。
    /// 对外 API 不变，仍是 `capsule.lock`。
    private var lockData: Data = Capsule.encode(.mood(notBefore: nil))

    /// 胶囊的锁。读写经 lockData 编解码。
    public var lock: Lock {
        get { (try? JSONDecoder().decode(Lock.self, from: lockData)) ?? .mood(notBefore: nil) }
        set { lockData = Capsule.encode(newValue) }
    }

    public var recipient: Recipient = Recipient.me
    /// recipient == .circle 时指向 Circle.id。
    public var circleID: UUID?

    public var authorID: String = ""
    public var authorName: String = ""

    public var latitude: Double?
    public var longitude: Double?
    public var placeName: String?
    public var weather: String?
    public var tags: [String] = []
    public var note: String?

    public var createdAt: Date = Date()
    public var openedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String = "",
        audioData: Data? = nil,
        duration: TimeInterval = 0,
        waveform: [Float] = [],
        state: CapsuleState = .buried,
        lock: Lock = .mood(notBefore: nil),
        recipient: Recipient = .me,
        circleID: UUID? = nil,
        authorID: String = "",
        authorName: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.audioData = audioData
        self.duration = duration
        self.waveform = waveform
        self.state = state
        self.lockData = Capsule.encode(lock)
        self.recipient = recipient
        self.circleID = circleID
        self.authorID = authorID
        self.authorName = authorName
        self.createdAt = createdAt
    }

    private static func encode(_ lock: Lock) -> Data {
        (try? JSONEncoder().encode(lock)) ?? Data()
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: `Test run with 11 tests passed`（累计：9 + 2 胶囊）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxlue
git add VoxlueKit/Sources/VoxlueData/Capsule.swift VoxlueKit/Tests/VoxlueDataTests/CapsuleTests.swift
git commit -m "feat(data): 新增 Capsule @Model"
```

---

## Task 6: Circle 与 CircleMember 模型

**Files:**
- Create: `VoxlueKit/Sources/VoxlueData/Circle.swift`
- Test: `VoxlueKit/Tests/VoxlueDataTests/CircleTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDataTests/CircleTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import VoxlueData

@MainActor
@Test func circleWithMembersInsertAndFetch() throws {
    let container = try ModelContainer(
        for: Circle.self, CircleMember.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let circle = Circle(name: "家", ownerID: "user-1")
    let nana = CircleMember(name: "奶奶", userRecordID: "user-2", role: .member)
    circle.members = [nana]
    context.insert(circle)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Circle>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.name == "家")
    #expect(fetched.first?.members?.first?.name == "奶奶")
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `Circle` / `CircleMember`

- [ ] **Step 3: 实现 Circle 与 CircleMember**

创建 `VoxlueKit/Sources/VoxlueData/Circle.swift`：

```swift
import Foundation
import SwiftData

/// 声音圈 —— CKShare 的共享单元。
@Model
public final class Circle {
    public var id: UUID = UUID()
    public var name: String = ""
    public var ownerID: String = ""
    public var createdAt: Date = Date()

    /// CloudKit 镜像要求关系可选。
    @Relationship(deleteRule: .cascade)
    public var members: [CircleMember]? = []

    public init(
        id: UUID = UUID(),
        name: String = "",
        ownerID: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.createdAt = createdAt
    }
}

/// 声音圈成员。
@Model
public final class CircleMember {
    public var id: UUID = UUID()
    public var name: String = ""
    public var userRecordID: String = ""
    public var role: CircleRole = CircleRole.member
    public var joinedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String = "",
        userRecordID: String = "",
        role: CircleRole = .member,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.userRecordID = userRecordID
        self.role = role
        self.joinedAt = joinedAt
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: `Test run with 12 tests passed`（累计：11 + 1 圈）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxlue
git add VoxlueKit/Sources/VoxlueData/Circle.swift VoxlueKit/Tests/VoxlueDataTests/CircleTests.swift
git commit -m "feat(data): 新增 Circle 与 CircleMember @Model"
```

---

## Task 7: VoxlueModelContainer 容器工厂

**Files:**
- Create: `VoxlueKit/Sources/VoxlueData/VoxlueModelContainer.swift`
- Test: `VoxlueKit/Tests/VoxlueDataTests/ModelContainerTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDataTests/ModelContainerTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import VoxlueData

@MainActor
@Test func inMemoryContainerHoldsAllThreeModels() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let context = container.mainContext

    context.insert(Capsule(title: "测试胶囊"))
    context.insert(Circle(name: "家"))
    context.insert(CircleMember(name: "奶奶"))
    try context.save()

    #expect(try context.fetch(FetchDescriptor<Capsule>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<Circle>()).count == 1)
    #expect(try context.fetch(FetchDescriptor<CircleMember>()).count == 1)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `VoxlueModelContainer`

- [ ] **Step 3: 实现 VoxlueModelContainer**

创建 `VoxlueKit/Sources/VoxlueData/VoxlueModelContainer.swift`：

```swift
import Foundation
import SwiftData

/// SwiftData 容器工厂。
/// - 生产配置：镜像到 CloudKit 私有库。
/// - 测试配置：纯内存，不接 CloudKit。
public enum VoxlueModelContainer {

    /// CloudKit 容器标识符，需与 Xcode iCloud 能力里的容器一致。
    public static let cloudKitContainerID = "iCloud.com.voxlue.app"

    public static let schema = Schema([
        Capsule.self,
        Circle.self,
        CircleMember.self,
    ])

    /// 创建一个 ModelContainer。
    /// - Parameter inMemory: true 为内存配置（测试/预览用），false 为生产配置（CloudKit 镜像）。
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: `Test run with 13 tests passed`（累计：12 + 1 容器）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxlue
git add VoxlueKit/Sources/VoxlueData/VoxlueModelContainer.swift VoxlueKit/Tests/VoxlueDataTests/ModelContainerTests.swift
git commit -m "feat(data): 新增 VoxlueModelContainer 容器工厂"
```

---

## Task 8: CapsuleStore 写操作封装

**Files:**
- Create: `VoxlueKit/Sources/VoxlueData/CapsuleStore.swift`
- Test: `VoxlueKit/Tests/VoxlueDataTests/CapsuleStoreTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueDataTests/CapsuleStoreTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
@testable import VoxlueData

// 注意：容器必须留在每个测试函数自己的作用域里。
// ModelContext 不强引用它的 ModelContainer —— 若把容器创建放进一个
// 返回后即出栈的 helper，容器会被释放，后续 context.insert 会崩溃。

@MainActor
@Test func addThenAllCapsulesReturnsIt() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    try store.add(Capsule(title: "咖啡馆的雨"))
    let all = try store.allCapsules()
    #expect(all.count == 1)
    #expect(all.first?.title == "咖啡馆的雨")
}

@MainActor
@Test func allCapsulesSortedByCreatedAtDescending() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let older = Capsule(title: "旧", createdAt: Date(timeIntervalSince1970: 1000))
    let newer = Capsule(title: "新", createdAt: Date(timeIntervalSince1970: 2000))
    try store.add(older)
    try store.add(newer)
    let all = try store.allCapsules()
    #expect(all.map(\.title) == ["新", "旧"])
}

@MainActor
@Test func deleteRemovesCapsule() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = Capsule(title: "划掉这张")
    try store.add(capsule)
    try store.delete(capsule)
    #expect(try store.allCapsules().isEmpty)
}

@MainActor
@Test func updateStatePersists() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let capsule = Capsule(title: "显影测试")
    try store.add(capsule)
    try store.updateState(capsule, to: .developing)
    #expect(try store.allCapsules().first?.state == .developing)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `CapsuleStore`

- [ ] **Step 3: 实现 CapsuleStore**

创建 `VoxlueKit/Sources/VoxlueData/CapsuleStore.swift`：

```swift
import Foundation
import SwiftData

/// 胶囊写操作的唯一入口，封装 ModelContext。
/// UI 读取仍可直接用 @Query；写操作统一走这里。
@MainActor
public final class CapsuleStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// 新增一枚胶囊。
    public func add(_ capsule: Capsule) throws {
        context.insert(capsule)
        try context.save()
    }

    /// 删除一枚胶囊（「划掉这张」）。
    public func delete(_ capsule: Capsule) throws {
        context.delete(capsule)
        try context.save()
    }

    /// 推进胶囊的显影状态。
    public func updateState(_ capsule: Capsule, to state: CapsuleState) throws {
        capsule.state = state
        if state == .opened {
            capsule.openedAt = Date()
        }
        try context.save()
    }

    /// 全部胶囊，按创建时间倒序。
    public func allCapsules() throws -> [Capsule] {
        try context.fetch(
            FetchDescriptor<Capsule>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )
    }
}
```

- [ ] **Step 4: 运行全部测试，确认通过**

Run: `cd /Users/cornna/project/voxlue/VoxlueKit && swift test`
Expected: `Test run with 17 tests passed`（1 冒烟 + 4 枚举 + 4 锁 + 2 胶囊 + 1 圈 + 1 容器 + 4 store）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxlue
git add VoxlueKit/Sources/VoxlueData/CapsuleStore.swift VoxlueKit/Tests/VoxlueDataTests/CapsuleStoreTests.swift
git commit -m "feat(data): 新增 CapsuleStore 写操作封装"
```

---

## Task 9: App 集成与端到端验证

把数据层接进 App，加 CloudKit 能力，用一个临时调试视图跑通「写入 → 读出」。该视图在计划 02 会被真正的样片墙替换。

**Files:**
- Modify: `Voxlue/Voxlue/VoxlueApp.swift`
- Create: `Voxlue/Voxlue/DebugRootView.swift`
- Modify: Xcode 工程能力配置（iCloud / CloudKit、Background Modes）

- [ ] **Step 1: 添加 iCloud / CloudKit 能力**

在 Xcode：TARGETS ▸ Voxlue ▸ Signing & Capabilities ▸ `+ Capability` ▸ 添加 **iCloud** ▸ 勾选 **CloudKit** ▸ 在 Containers 区点 `+` 新增容器 `iCloud.com.voxlue.app`。
再 `+ Capability` 添加 **Background Modes** ▸ 勾选 **Remote notifications**（CloudKit 同步推送需要）。

- [ ] **Step 2: 写临时调试视图**

创建 `Voxlue/Voxlue/DebugRootView.swift`：

```swift
import SwiftUI
import SwiftData
import VoxlueData

/// 临时调试视图，验证数据层端到端可用。计划 02 替换为样片墙。
struct DebugRootView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Capsule.createdAt, order: .reverse) private var capsules: [Capsule]

    var body: some View {
        NavigationStack {
            List(capsules) { capsule in
                VStack(alignment: .leading) {
                    Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                    Text(capsule.state.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("胶囊：\(capsules.count)")
            .toolbar {
                Button("加一枚样本") {
                    let store = CapsuleStore(context: context)
                    try? store.add(Capsule(title: "样本 \(capsules.count + 1)"))
                }
            }
        }
    }
}
```

- [ ] **Step 3: 修改 App 入口接入容器**

把 `Voxlue/Voxlue/VoxlueApp.swift` 全文替换为：

```swift
import SwiftUI
import SwiftData
import VoxlueData

@main
struct VoxlueApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try VoxlueModelContainer.make()
        } catch {
            fatalError("无法创建 ModelContainer：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            DebugRootView()
        }
        .modelContainer(modelContainer)
    }
}
```

- [ ] **Step 4: 构建并在模拟器运行**

Run: `cd /Users/cornna/project/voxlue/Voxlue && xcodebuild -scheme Voxlue -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

然后在 Xcode 用 iPhone 16 模拟器运行（⌘R）。点「加一枚样本」两次，确认列表出现两行、标题变为「胶囊：2」；关闭重开 App 后两行仍在（验证持久化）。

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxlue
git add Voxlue
git commit -m "feat: App 接入 VoxlueData 数据层并端到端验证"
```

---

## 完成标准

- `swift test --package-path VoxlueKit` 全绿（19 个测试通过）。
- App 在模拟器可运行，能写入并持久化胶囊。
- 数据模型遵守 CloudKit 镜像约束，已配置 iCloud/CloudKit 能力。
- 全部改动已提交 git。

下一份计划：**计划 02 · 录音→装裱→回放主循环 + 基础设计系统**。

---

## 执行后修订记录（2026-05-22）

计划 01 执行中发现并修正了若干问题，最终实现以仓库代码为准：

- **环境**：`swift-tools-version` 须为 6.2（`.v26` 平台所需）；构建 SwiftData / iOS App 必须安装完整 Xcode —— Command Line Tools 缺 Swift Testing 运行时与 SwiftData 宏插件。
- **Lock 持久化**：SwiftData 无法可靠持久化带关联值的 Codable 枚举。`Capsule` 改为私有 `lockData: Data`（JSON 编码）+ 计算属性 `lock`，对外 API 不变。
- **测试容器生命周期**：`ModelContext` 不强引用 `ModelContainer`；`CapsuleStoreTests` 改为每个测试在自身作用域内持有容器。
- **代码评审后补充**：`capsuleInsertAndFetch` 增加锁关联值的完整往返断言；新增 `moodLockWithDateRoundTrip`、`updateStateToOpenedSetsOpenedAt` 两个测试；删除脚手架文件 `Placeholder.swift`。
- **最终测试数**：`swift test --package-path VoxlueKit` → **19 个测试全部通过**。

### Task 1 & Task 9 收尾（2026-05-22）

- **Xcode 工程**：已建默认模板工程，名为 `voxule`（小写，仓库目录同名），`objectVersion 77` 的同步文件夹格式 —— 源码文件夹自动纳入构建，无需在 `project.pbxproj` 里逐一登记文件。
- **接入本地包**：未走 Xcode GUI，直接手改 `project.pbxproj` —— 新增 `XCLocalSwiftPackageReference`（`relativePath = ../VoxlueKit`）、`XCSwiftPackageProductDependency`（`VoxlueData`）并链入 App 目标。
- **命名冲突**：`VoxlueData.Capsule`（模型）与 `SwiftUI.Capsule`（内置形状）同名。同时 `import SwiftUI` 与 `VoxlueData` 的视图里必须写全 `VoxlueData.Capsule` 消歧义（`@Query` 宏生成代码不接受 `private` 类型别名）。
- **启动降级**：`voxuleApp` 对 `VoxlueModelContainer.make()` 失败做降级 —— CloudKit 不可用（未登录 iCloud、缺能力配置等）时退回纯本地持久化存储，App 不再 `fatalError`，数据仍落地、只是不跨设备同步。
- **CloudKit 能力**：以 `voxule/voxule/voxule.entitlements`（iCloud 容器 + CloudKit 服务）+ 构建设置 `INFOPLIST_KEY_UIBackgroundModes = remote-notification` 配置。**实际同步仍需** 开发者账号在 CloudKit Dashboard 创建容器 `iCloud.com.voxlue.app`，并以带该能力的 Team 完成签名。
- **部署目标**：工程为 iOS 26.5（Xcode 26.5 默认），与计划所写 26.0 略有出入；与包 `.iOS(.v26)` 兼容，未改动。
- **端到端验证**：`xcodebuild build` 通过；App 在 iPhone 17 模拟器启动正常（`DebugRootView` 显示「胶囊：0」）；`voxuleUITests` 新增 `testAddCapsulePersistsAcrossRelaunch` —— 通过 App UI 点按写入胶囊、重启 App 后确认持久化，**测试通过**。
- **构建命令**：模拟器无签名构建/测试用 `CODE_SIGNING_ALLOWED=NO`；本机无 iPhone 16 模拟器，改用 iPhone 17。
