# voxlue 计划 02 · 录音→装裱→回放主循环 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 `VoxlueServices` 包目标与 `AudioEngine` 服务（录音 / 播放 / 声纹采样，含真实现与假实现），并在 App 里落地「录音 → 装裱选锁选收件人 → 确认埋下 → 样片墙 → 胶囊详情回放」这条 v1 核心主循环，端到端跑通；样片墙替换计划 01 的临时 `DebugRootView`。

**Architecture:** 在唯一本地包 `VoxlueKit` 里新增第二个 library 目标 `VoxlueServices`（架构文档 §4 三包划分之一），它依赖 `VoxlueData`。`AudioEngine` 走平台能力层 wrapper 范式 —— 协议（`AudioRecording` / `AudioPlaying`）+ 真实现（`AudioEngine`，AVFoundation）+ 假实现（`FakeAudioRecording` / `FakeAudioPlaying`，返回固定 8 秒假波形）。声纹下采样是一个纯函数，单独抽出可独测。功能视图与 App 壳层放 App target，用 MV 模式（SwiftUI + `@Observable`，无 ViewModel）。服务以具体类型注入环境，UI 测试与 `#Preview` 一律用 `Fake*`，真实 `AudioEngine` 触麦克风、不进自动化测试。

**Tech Stack:** Swift 6.2 · SwiftUI · SwiftData · Swift Testing · AVFoundation · Xcode 26.5 · iOS 26

**前置条件:** 计划 01 已完成并合入 `main`（`VoxlueData` 包 + Xcode 工程 + `DebugRootView`）；已安装完整 Xcode 26.5（构建 SwiftData / iOS App、运行 Swift Testing 与 SwiftData 宏插件均需要）；模拟器用 iPhone 17（本机无 iPhone 16 模拟器）。

**对应设计文档:** `docs/superpowers/specs/2026-05-21-voxlue-architecture-design.md` 的 §4、§5、§9、§11、§12（AudioEngine 部分）；路线图 `docs/superpowers/plans/2026-05-22-voxlue-v1-roadmap.md` 的 §1、§3.0、§3.1、§6。

**契约约束:** `RecordingResult` / `AudioRecording` / `AudioPlaying` 签名取自路线图 §3.1，**逐字照抄、不得改名或改签名**。改签名须先改路线图 §3.1 并知会前端轨。

**分工说明:** 本计划双轨。标 `【协作者】` 的任务（Task 1–4，`VoxlueServices` 包 + `AudioEngine` + `CapsuleStore` 扩展）必须先于标 `【前端】` 的对应 UI 任务合入「协议 + 假实现」（contract-first，路线图 §2.3）。`【协作者→前端】` 为交接点。前端轨任务（Task 5–10）依赖 Task 1–3 已合入的协议与 `Fake*` 假实现即可开工，不必等 Task 4 真实现。

---

## 文件结构

```
/Users/cornna/project/voxule/
├── VoxlueKit/
│   ├── Package.swift                                  修改：新增 VoxlueServices 目标
│   ├── Sources/
│   │   ├── VoxlueData/
│   │   │   └── CapsuleStore.swift                     修改：新增 buriedCapsules/capsules(in:) 查询
│   │   └── VoxlueServices/                            新建目标
│   │       ├── RecordingResult.swift                  RecordingResult 结构体
│   │       ├── AudioRecording.swift                   AudioRecording 协议
│   │       ├── AudioPlaying.swift                     AudioPlaying 协议
│   │       ├── Waveform.swift                         声纹下采样纯函数
│   │       ├── FakeAudioRecording.swift               假录音器（固定 8s 假波形）
│   │       ├── FakeAudioPlaying.swift                 假播放器
│   │       ├── AudioSession.swift                     AVAudioSession 配置 wrapper
│   │       └── AudioEngine.swift                      真实现（AVFoundation）
│   └── Tests/
│       ├── VoxlueDataTests/
│       │   └── CapsuleStoreTests.swift                修改：新增查询测试
│       └── VoxlueServicesTests/                       新建测试目标
│           ├── WaveformTests.swift
│           ├── FakeAudioTests.swift
│           └── BuryCapsuleTests.swift
└── voxule/voxule/
    ├── voxule.xcodeproj/project.pbxproj               修改：链入 VoxlueServices 库产品
    └── voxule/
        ├── voxuleApp.swift                            修改：装配服务、根视图换 RootTabView
        ├── AppEnvironment.swift                       新建：依赖容器
        ├── RootTabView.swift                          新建：TabView 骨架
        ├── ShelfView.swift                            新建：样片墙
        ├── CapsuleRow.swift                           新建：样片墙行
        ├── RecordView.swift                           新建：录音视图
        ├── FramingView.swift                          新建：装裱视图（选锁/收件人/标题）
        ├── CapsuleDetailView.swift                    新建：胶囊详情 + 回放
        ├── WaveformView.swift                         新建：声纹绘制控件
        └── DebugRootView.swift                        删除（被 ShelfView 取代）
```

---

## Task 1: VoxlueServices 包目标与音频契约 【协作者】

新增 `VoxlueServices` library 目标并落地路线图 §3.1 的契约类型 `RecordingResult` / `AudioRecording` / `AudioPlaying`。这是两轨的耦合面，先合入契约前端才能开工。

**Files:**
- Modify: `VoxlueKit/Package.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/RecordingResult.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/AudioRecording.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/AudioPlaying.swift`
- Create: `VoxlueKit/Tests/VoxlueServicesTests/FakeAudioTests.swift`（本 Task 仅占位冒烟，Task 3 补全）

- [ ] **Step 1: 在 Package.swift 新增 VoxlueServices 目标**

把 `VoxlueKit/Package.swift` 全文替换为：

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

- [ ] **Step 2: 写契约类型 RecordingResult**

创建 `VoxlueKit/Sources/VoxlueServices/RecordingResult.swift`：

```swift
import Foundation

/// 一次录音的产物。
/// 契约定义见路线图 §3.1 —— 签名冻结，不得改动。
public struct RecordingResult: Sendable, Equatable {
    public let audioData: Data
    public let duration: TimeInterval
    public let waveform: [Float]   // 归一化 0...1，60–120 个采样点

    public init(audioData: Data, duration: TimeInterval, waveform: [Float]) {
        self.audioData = audioData
        self.duration = duration
        self.waveform = waveform
    }
}
```

- [ ] **Step 3: 写录音器协议 AudioRecording**

创建 `VoxlueKit/Sources/VoxlueServices/AudioRecording.swift`：

```swift
import Foundation

/// 录音器。
/// 契约定义见路线图 §3.1 —— 签名冻结，不得改动。
@MainActor public protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    var elapsed: TimeInterval { get }            // 录制中实时秒数，驱动 UI
    func requestPermission() async -> Bool
    func start() throws
    func stop() async throws -> RecordingResult
    func cancel()
}
```

- [ ] **Step 4: 写播放器协议 AudioPlaying**

创建 `VoxlueKit/Sources/VoxlueServices/AudioPlaying.swift`：

```swift
import Foundation

/// 播放器。
/// 契约定义见路线图 §3.1 —— 签名冻结，不得改动。
@MainActor public protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    var progress: Double { get }                 // 0...1
    func load(_ data: Data) throws
    func play()
    func pause()
    func seek(toProgress progress: Double)
}
```

- [ ] **Step 5: 写占位冒烟测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/FakeAudioTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func recordingResultIsEquatable() {
    let a = RecordingResult(audioData: Data([1, 2]), duration: 8, waveform: [0.5])
    let b = RecordingResult(audioData: Data([1, 2]), duration: 8, waveform: [0.5])
    #expect(a == b)
}
```

- [ ] **Step 6: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 输出包含 `Test run with 20 tests passed`（计划 01 的 19 个 + 本 Task 1 个）

- [ ] **Step 7: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Package.swift VoxlueKit/Sources/VoxlueServices VoxlueKit/Tests/VoxlueServicesTests
git commit -m "feat(audio): 新增 VoxlueServices 包目标与 AudioEngine 契约"
```

---

## Task 2: 声纹下采样纯函数 【协作者】

声纹绘制需要把任意长度的音频幅度序列压成 60–120 个归一化采样点。这是真假实现共用的纯函数，单独抽出便于独测，不碰音频框架。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/Waveform.swift`
- Create: `VoxlueKit/Tests/VoxlueServicesTests/WaveformTests.swift`

- [ ] **Step 1: 写失败的测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/WaveformTests.swift`：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func downsampleProducesRequestedBucketCount() {
    let samples = (0..<10_000).map { Float($0) }
    let wave = Waveform.downsample(samples, buckets: 80)
    #expect(wave.count == 80)
}

@Test func downsampleNormalizesToZeroOneRange() {
    let samples = (0..<1_000).map { _ in Float.random(in: -1...1) }
    let wave = Waveform.downsample(samples, buckets: 64)
    #expect(wave.allSatisfy { $0 >= 0 && $0 <= 1 })
    // 至少有一个桶达到峰值 1（最大幅度被归一化为 1）。
    #expect(wave.contains { $0 > 0.99 })
}

@Test func downsampleHandlesFewerSamplesThanBuckets() {
    let wave = Waveform.downsample([0.2, 0.8, 0.4], buckets: 80)
    #expect(wave.count == 80)
    #expect(wave.allSatisfy { $0 >= 0 && $0 <= 1 })
}

@Test func downsampleOfSilenceIsAllZero() {
    let wave = Waveform.downsample([Float](repeating: 0, count: 500), buckets: 60)
    #expect(wave.count == 60)
    #expect(wave.allSatisfy { $0 == 0 })
}

@Test func downsampleOfEmptyInputIsEmpty() {
    #expect(Waveform.downsample([], buckets: 80).isEmpty)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `Waveform`

- [ ] **Step 3: 实现 Waveform**

创建 `VoxlueKit/Sources/VoxlueServices/Waveform.swift`：

```swift
import Foundation

/// 声纹采样工具。把任意长度的幅度序列压成定额的归一化采样点，供绘制用。
public enum Waveform {

    /// 把幅度序列下采样为 `buckets` 个归一化（0...1）采样点。
    /// 每个桶取该区间内幅度绝对值的均方根（RMS），再整体按峰值归一化。
    /// - Parameters:
    ///   - samples: 原始幅度序列（可正可负）。
    ///   - buckets: 目标采样点数，建议 60–120。
    /// - Returns: `buckets` 个 0...1 的采样点；输入为空时返回空数组。
    public static func downsample(_ samples: [Float], buckets: Int) -> [Float] {
        guard !samples.isEmpty, buckets > 0 else { return [] }

        var rms = [Float](repeating: 0, count: buckets)
        let count = samples.count
        for index in 0..<buckets {
            let lower = index * count / buckets
            let upper = max(lower + 1, (index + 1) * count / buckets)
            var sumOfSquares: Float = 0
            for i in lower..<min(upper, count) {
                sumOfSquares += samples[i] * samples[i]
            }
            let n = Float(min(upper, count) - lower)
            rms[index] = n > 0 ? (sumOfSquares / n).squareRoot() : 0
        }

        let peak = rms.max() ?? 0
        guard peak > 0 else { return rms }   // 全静音时直接返回全 0
        return rms.map { $0 / peak }
    }
}
```

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: `Test run with 25 tests passed`（累计：20 + 5 声纹）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/Waveform.swift VoxlueKit/Tests/VoxlueServicesTests/WaveformTests.swift
git commit -m "feat(audio): 新增声纹下采样纯函数 Waveform.downsample"
```

---

## Task 3: 假录音器与假播放器 【协作者→前端】

`Fake*` 假实现返回固定 8 秒假波形，供 `#Preview` 与 UI 测试驱动视图。**这是交接点 —— 本 Task 合入后前端轨即可开工 Task 5–10，不必等 Task 4 真实现。**

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/FakeAudioRecording.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/FakeAudioPlaying.swift`
- Modify: `VoxlueKit/Tests/VoxlueServicesTests/FakeAudioTests.swift`

- [ ] **Step 1: 把测试补全为失败的测试**

把 `VoxlueKit/Tests/VoxlueServicesTests/FakeAudioTests.swift` 全文替换为：

```swift
import Testing
import Foundation
@testable import VoxlueServices

@Test func recordingResultIsEquatable() {
    let a = RecordingResult(audioData: Data([1, 2]), duration: 8, waveform: [0.5])
    let b = RecordingResult(audioData: Data([1, 2]), duration: 8, waveform: [0.5])
    #expect(a == b)
}

@MainActor
@Test func fakeRecorderStartStopYieldsEightSecondResult() async throws {
    let recorder = FakeAudioRecording()
    #expect(recorder.isRecording == false)
    #expect(await recorder.requestPermission() == true)
    try recorder.start()
    #expect(recorder.isRecording == true)
    let result = try await recorder.stop()
    #expect(recorder.isRecording == false)
    #expect(result.duration == 8)
    #expect(result.waveform.count == 80)
    #expect(result.waveform.allSatisfy { $0 >= 0 && $0 <= 1 })
    #expect(result.audioData.isEmpty == false)
}

@MainActor
@Test func fakeRecorderCancelClearsState() throws {
    let recorder = FakeAudioRecording()
    try recorder.start()
    recorder.cancel()
    #expect(recorder.isRecording == false)
    #expect(recorder.elapsed == 0)
}

@MainActor
@Test func fakePlayerLoadPlayPauseAndSeek() throws {
    let player = FakeAudioPlaying()
    try player.load(Data([0, 1, 2]))
    #expect(player.isPlaying == false)
    player.play()
    #expect(player.isPlaying == true)
    player.pause()
    #expect(player.isPlaying == false)
    player.seek(toProgress: 0.5)
    #expect(player.progress == 0.5)
}

@MainActor
@Test func fakePlayerClampsSeekToUnitRange() throws {
    let player = FakeAudioPlaying()
    try player.load(Data())
    player.seek(toProgress: 1.7)
    #expect(player.progress == 1.0)
    player.seek(toProgress: -0.4)
    #expect(player.progress == 0.0)
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 编译失败，提示找不到 `FakeAudioRecording` / `FakeAudioPlaying`

- [ ] **Step 3: 实现 FakeAudioRecording**

创建 `VoxlueKit/Sources/VoxlueServices/FakeAudioRecording.swift`：

```swift
import Foundation
import Observation

/// 假录音器 —— 不碰麦克风，返回固定 8 秒假波形。供 #Preview 与 UI 测试用。
@MainActor
@Observable
public final class FakeAudioRecording: AudioRecording {
    public private(set) var isRecording = false
    public private(set) var elapsed: TimeInterval = 0

    /// 固定假波形：80 个采样点的平滑正弦包络，归一化 0...1。
    public static let fakeWaveform: [Float] = (0..<80).map { i in
        let phase = Double(i) / 80.0 * .pi * 3
        return Float((sin(phase) * 0.5 + 0.5) * (0.4 + 0.6 * Double(i) / 80.0))
    }

    public init() {}

    public func requestPermission() async -> Bool { true }

    public func start() throws {
        isRecording = true
        elapsed = 0
    }

    public func stop() async throws -> RecordingResult {
        isRecording = false
        elapsed = 0
        return RecordingResult(
            audioData: Data("fake-audio".utf8),
            duration: 8,
            waveform: Self.fakeWaveform
        )
    }

    public func cancel() {
        isRecording = false
        elapsed = 0
    }
}
```

- [ ] **Step 4: 实现 FakeAudioPlaying**

创建 `VoxlueKit/Sources/VoxlueServices/FakeAudioPlaying.swift`：

```swift
import Foundation
import Observation

/// 假播放器 —— 不解码音频，进度由 seek 直接驱动。供 #Preview 与 UI 测试用。
@MainActor
@Observable
public final class FakeAudioPlaying: AudioPlaying {
    public private(set) var isPlaying = false
    public private(set) var progress: Double = 0

    public init() {}

    public func load(_ data: Data) throws {
        progress = 0
        isPlaying = false
    }

    public func play() { isPlaying = true }

    public func pause() { isPlaying = false }

    public func seek(toProgress progress: Double) {
        self.progress = min(1, max(0, progress))
    }
}
```

- [ ] **Step 5: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: `Test run with 29 tests passed`（累计：25 + 4 假实现新增）

- [ ] **Step 6: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/FakeAudioRecording.swift VoxlueKit/Sources/VoxlueServices/FakeAudioPlaying.swift VoxlueKit/Tests/VoxlueServicesTests/FakeAudioTests.swift
git commit -m "feat(audio): 新增 FakeAudioRecording/FakeAudioPlaying 假实现"
```

> **交接信号：** 本 Task 合入 `main` 后通知前端轨。前端轨可开 Task 5–10；协作者轨继续 Task 4。

---

## Task 4: AudioSession 与 AudioEngine 真实现 【协作者】

`AudioEngine` 真实现走 AVFoundation：录音用 `AVAudioRecorder`（开启分贝计量），播放用 `AVAudioPlayer`；声纹由录音时周期采集的峰值电平经 `Waveform.downsample` 压成采样点。`AudioSession` 包一层 `AVAudioSession` 配置。真实现触麦克风，不进自动化测试，靠 App 手动验证。

**Files:**
- Create: `VoxlueKit/Sources/VoxlueServices/AudioSession.swift`
- Create: `VoxlueKit/Sources/VoxlueServices/AudioEngine.swift`

- [ ] **Step 1: 实现 AudioSession**

创建 `VoxlueKit/Sources/VoxlueServices/AudioSession.swift`：

```swift
import Foundation
import AVFoundation

/// AVAudioSession 配置 wrapper。把会话类别切换集中在一处，便于排障。
enum AudioSession {

    /// 切到录音类别（允许录音 + 默认走扬声器）。
    static func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    /// 切到回放类别。
    static func activateForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    /// 释放会话，把音频焦点还给系统。
    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
```

- [ ] **Step 2: 实现 AudioEngine 真实现**

创建 `VoxlueKit/Sources/VoxlueServices/AudioEngine.swift`：

```swift
import Foundation
import AVFoundation
import Observation

/// 录音 / 播放 / 声纹采样的真实现，基于 AVFoundation。
/// 触麦克风，不进自动化测试 —— UI 测试与预览用 `FakeAudioRecording` / `FakeAudioPlaying`。
@MainActor
@Observable
public final class AudioEngine: NSObject, AudioRecording, AudioPlaying {

    // MARK: 录音状态
    public private(set) var isRecording = false
    public private(set) var elapsed: TimeInterval = 0

    // MARK: 回放状态
    public private(set) var isPlaying = false
    public private(set) var progress: Double = 0

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordURL: URL?
    private var levelTimer: Timer?
    private var progressTimer: Timer?
    /// 录音过程中周期采集的峰值电平（线性 0...1），停录时下采样为声纹。
    private var levelSamples: [Float] = []

    public override init() { super.init() }

    // MARK: - AudioRecording

    public func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func start() throws {
        try AudioSession.activateForRecording()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.record()

        self.recorder = recorder
        self.recordURL = url
        self.levelSamples = []
        self.elapsed = 0
        self.isRecording = true

        // 每 0.05s 采一次峰值电平，并刷新计时。
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleLevel() }
        }
        self.levelTimer = timer
    }

    private func sampleLevel() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime
        // averagePower 单位 dB（-160...0），转线性 0...1。
        let db = recorder.averagePower(forChannel: 0)
        let linear = db < -60 ? 0 : powf(10, db / 20)
        levelSamples.append(linear)
    }

    public func stop() async throws -> RecordingResult {
        levelTimer?.invalidate()
        levelTimer = nil
        guard let recorder, let url = recordURL else {
            throw AudioEngineError.notRecording
        }
        let duration = recorder.currentTime
        recorder.stop()
        isRecording = false
        AudioSession.deactivate()

        let data = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        self.recorder = nil
        self.recordURL = nil

        let waveform = Waveform.downsample(levelSamples, buckets: 80)
        elapsed = 0
        return RecordingResult(audioData: data, duration: duration, waveform: waveform)
    }

    public func cancel() {
        levelTimer?.invalidate()
        levelTimer = nil
        recorder?.stop()
        if let url = recordURL { try? FileManager.default.removeItem(at: url) }
        recorder = nil
        recordURL = nil
        levelSamples = []
        isRecording = false
        elapsed = 0
        AudioSession.deactivate()
    }

    // MARK: - AudioPlaying

    public func load(_ data: Data) throws {
        try AudioSession.activateForPlayback()
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        progress = 0
        isPlaying = false
    }

    public func play() {
        guard let player else { return }
        player.play()
        isPlaying = true
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshProgress() }
        }
        progressTimer = timer
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        progressTimer?.invalidate()
        progressTimer = nil
    }

    public func seek(toProgress progress: Double) {
        guard let player else { return }
        let clamped = min(1, max(0, progress))
        player.currentTime = player.duration * clamped
        self.progress = clamped
    }

    private func refreshProgress() {
        guard let player, player.duration > 0 else { return }
        progress = min(1, player.currentTime / player.duration)
    }
}

extension AudioEngine: AVAudioPlayerDelegate {
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1
            self.progressTimer?.invalidate()
            self.progressTimer = nil
        }
    }
}

/// AudioEngine 错误。
public enum AudioEngineError: Error, Sendable {
    case notRecording
}
```

- [ ] **Step 3: 验证包可编译可测试**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: `Test run with 29 tests passed`（真实现无新增测试，触麦克风不进自动化；只验证全包仍编译通过）

- [ ] **Step 4: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueServices/AudioSession.swift VoxlueKit/Sources/VoxlueServices/AudioEngine.swift
git commit -m "feat(audio): 新增 AudioEngine 真实现与 AudioSession wrapper"
```

---

## Task 5: 扩展 CapsuleStore 查询方法 【协作者】

样片墙按状态分组、装裱埋下后写入需要按 `state` 过滤。给 `CapsuleStore` 补两个查询方法。

**Files:**
- Modify: `VoxlueKit/Sources/VoxlueData/CapsuleStore.swift`
- Modify: `VoxlueKit/Tests/VoxlueDataTests/CapsuleStoreTests.swift`

- [ ] **Step 1: 在 CapsuleStoreTests 追加失败的测试**

在 `VoxlueKit/Tests/VoxlueDataTests/CapsuleStoreTests.swift` 末尾追加：

```swift
@MainActor
@Test func buriedCapsulesReturnsOnlyBuriedSortedDescending() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    let buriedOld = Capsule(title: "潜伏·旧", state: .buried,
                            createdAt: Date(timeIntervalSince1970: 1000))
    let buriedNew = Capsule(title: "潜伏·新", state: .buried,
                            createdAt: Date(timeIntervalSince1970: 2000))
    let developed = Capsule(title: "已显影", state: .developed,
                            createdAt: Date(timeIntervalSince1970: 3000))
    try store.add(buriedOld)
    try store.add(buriedNew)
    try store.add(developed)

    let buried = try store.buriedCapsules()
    #expect(buried.map(\.title) == ["潜伏·新", "潜伏·旧"])
}

@MainActor
@Test func capsulesInStateFiltersByGivenState() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)
    try store.add(Capsule(title: "a", state: .opened))
    try store.add(Capsule(title: "b", state: .buried))
    #expect(try store.capsules(in: .opened).map(\.title) == ["a"])
    #expect(try store.capsules(in: .buried).map(\.title) == ["b"])
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: 编译失败，提示 `CapsuleStore` 无 `buriedCapsules` / `capsules(in:)`

- [ ] **Step 3: 在 CapsuleStore 实现查询方法**

在 `VoxlueKit/Sources/VoxlueData/CapsuleStore.swift` 的 `allCapsules()` 方法之后、类结尾 `}` 之前插入：

```swift

    /// 按指定显影状态查询，按创建时间倒序。
    public func capsules(in state: CapsuleState) throws -> [Capsule] {
        let target = state.rawValue
        var descriptor = FetchDescriptor<Capsule>(
            predicate: #Predicate { $0.state.rawValue == target },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = nil
        return try context.fetch(descriptor)
    }

    /// 全部「已埋下·潜伏」状态的胶囊，按创建时间倒序。
    public func buriedCapsules() throws -> [Capsule] {
        try capsules(in: .buried)
    }
```

> 说明：`#Predicate` 对带原始值的枚举属性直接比较有时无法转译，故比较 `state.rawValue`（`String`）；先把目标值取成局部常量再进谓词，避免捕获枚举本身。

- [ ] **Step 4: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: `Test run with 31 tests passed`（累计：29 + 2 查询）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Sources/VoxlueData/CapsuleStore.swift VoxlueKit/Tests/VoxlueDataTests/CapsuleStoreTests.swift
git commit -m "feat(data): CapsuleStore 新增按状态查询 capsules(in:)/buriedCapsules"
```

---

## Task 6: 把 VoxlueServices 链入 App 工程 【前端】

App target 已链入 `VoxlueData` 库产品，`VoxlueServices` 用同样方式链入。`objectVersion 77` 的 pbxproj 需新增一个 `XCSwiftPackageProductDependency` 与一条 `PBXBuildFile`（Frameworks 阶段），本地包引用已存在无需新增。

**Files:**
- Modify: `voxule/voxule.xcodeproj/project.pbxproj`

- [ ] **Step 1: 新增 XCSwiftPackageProductDependency**

打开 `voxule/voxule.xcodeproj/project.pbxproj`，找到 `XCSwiftPackageProductDependency` 区段（计划 01 已有 `VoxlueData` 一条）。在该区段内、`/* End XCSwiftPackageProductDependency section */` 之前追加：

```
		D1A0000000000000000000B2 /* VoxlueServices */ = {
			isa = XCSwiftPackageProductDependency;
			productName = VoxlueServices;
		};
```

- [ ] **Step 2: 新增 PBXBuildFile 并加进 Frameworks 阶段**

在 `PBXBuildFile section` 内、`VoxlueData in Frameworks` 那一行之后追加：

```
		D1A0000000000000000000B3 /* VoxlueServices in Frameworks */ = {isa = PBXBuildFile; productRef = D1A0000000000000000000B2 /* VoxlueServices */; };
```

在 `PBXFrameworksBuildPhase` 的 `files` 列表里、`VoxlueData in Frameworks` 那一行之后追加：

```
				D1A0000000000000000000B3 /* VoxlueServices in Frameworks */,
```

在 App target（`productName = voxule`）的 `packageProductDependencies` 列表里、`VoxlueData` 那一行之后追加：

```
				D1A0000000000000000000B2 /* VoxlueServices */,
```

- [ ] **Step 3: 添加麦克风用途说明**

App 录音须声明麦克风用途，否则首次录音直接崩溃。在 Xcode：TARGETS ▸ voxule ▸ Info ▸ Custom iOS Target Properties ▸ `+` ▸ 添加 `Privacy - Microphone Usage Description`（键 `NSMicrophoneUsageDescription`），值填：`voxlue 需要麦克风，为你冲洗一段声音。`

> 等价做法：在 pbxproj 的两个 `XCBuildConfiguration`（Debug / Release）的 `buildSettings` 各加一行 `INFOPLIST_KEY_NSMicrophoneUsageDescription = "voxlue 需要麦克风，为你冲洗一段声音。";`。

- [ ] **Step 4: 验证 App 仍可构建**

Run（从仓库根目录）：

```bash
xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
```

Expected: 末行输出 `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule.xcodeproj/project.pbxproj
git commit -m "chore(app): App 工程链入 VoxlueServices 库产品并声明麦克风用途"
```

---

## Task 7: 依赖容器与 App 壳层 TabView 骨架 【前端】

App 壳层负责依赖装配。`AppEnvironment` 持有 `AudioRecording` / `AudioPlaying` 服务，经 SwiftUI 环境注入。`RootTabView` 是三标签骨架（样片墙 / 地图占位 / 我），替换 `DebugRootView` 成为根视图。

**Files:**
- Create: `voxule/voxule/AppEnvironment.swift`
- Create: `voxule/voxule/RootTabView.swift`
- Modify: `voxule/voxule/voxuleApp.swift`
- Delete: `voxule/voxule/DebugRootView.swift`

- [ ] **Step 1: 写依赖容器 AppEnvironment**

创建 `voxule/voxule/AppEnvironment.swift`：

```swift
import SwiftUI
import VoxlueServices

/// App 壳层依赖容器。集中持有领域服务，经环境注入功能视图。
/// MV 模式：服务即真相源，无 ViewModel。
@MainActor
@Observable
final class AppEnvironment {
    /// 录音器。生产用 AudioEngine 真实现；预览/测试注入 Fake。
    let recorder: any AudioRecording
    /// 播放器。
    let player: any AudioPlaying

    init(recorder: any AudioRecording, player: any AudioPlaying) {
        self.recorder = recorder
        self.player = player
    }

    /// 生产装配：真实 AudioEngine。录音与回放共用同一个 AudioEngine 实例。
    static func live() -> AppEnvironment {
        let engine = AudioEngine()
        return AppEnvironment(recorder: engine, player: engine)
    }

    /// 预览/测试装配：假实现，不碰麦克风。
    static func preview() -> AppEnvironment {
        AppEnvironment(recorder: FakeAudioRecording(), player: FakeAudioPlaying())
    }
}

extension EnvironmentValues {
    /// 经环境传递的 App 依赖容器。
    @Entry var appEnvironment: AppEnvironment = .preview()
}
```

- [ ] **Step 2: 写 TabView 骨架 RootTabView**

创建 `voxule/voxule/RootTabView.swift`：

```swift
import SwiftUI

/// App 根骨架 —— 三标签：样片墙 / 地图 / 我。
/// 地图与我在本计划仅占位，分别由计划 03、05 充实。
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("样片墙", systemImage: "rectangle.stack") {
                ShelfView()
            }
            Tab("地图", systemImage: "map") {
                PlaceholderTab(title: "地图", note: "胶囊浮现在哪 —— 计划 03 充实。")
            }
            Tab("我", systemImage: "person.crop.circle") {
                PlaceholderTab(title: "我", note: "声音圈与设置 —— 计划 05 充实。")
            }
        }
    }
}

/// 标签占位页。
private struct PlaceholderTab: View {
    let title: String
    let note: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hourglass", description: Text(note))
                .navigationTitle(title)
        }
    }
}

#Preview {
    RootTabView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
```

> `VoxlueDataModelsPreview` 在 Step 4 定义，集中预览用的 SwiftData 模型清单。

- [ ] **Step 3: 改 App 入口装配服务、根视图换 RootTabView**

把 `voxule/voxule/voxuleApp.swift` 全文替换为：

```swift
//
//  voxuleApp.swift
//  voxule
//

import SwiftUI
import SwiftData
import VoxlueData

@main
struct voxuleApp: App {
    private let modelContainer: ModelContainer
    private let appEnvironment = AppEnvironment.live()

    init() {
        // 优先用生产配置 —— 镜像到 CloudKit 私有库。
        // 若 CloudKit 不可用（未登录 iCloud、缺少能力配置等），降级为纯本地存储。
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
            RootTabView()
                .environment(\.appEnvironment, appEnvironment)
        }
        .modelContainer(modelContainer)
    }
}
```

- [ ] **Step 4: 删除 DebugRootView、补预览模型清单**

删除临时调试视图：

```bash
cd /Users/cornna/project/voxule
git rm voxule/voxule/DebugRootView.swift
```

创建 `voxule/voxule/AppEnvironment.swift` 不放模型清单，单独建小文件便于各预览复用 —— 在 `AppEnvironment.swift` 末尾追加：

```swift
import VoxlueData

/// 预览专用：所有 SwiftData 模型清单。供各视图 #Preview 建内存容器。
enum VoxlueDataModelsPreview {
    static let all: [any PersistentModel.Type] = [
        VoxlueData.Capsule.self,
        VoxlueData.Circle.self,
        VoxlueData.CircleMember.self,
    ]
}
```

> 注意：`PersistentModel` 来自 SwiftData，需在文件顶部 `import SwiftData`。`AppEnvironment.swift` 顶部把导入补成 `import SwiftUI` / `import SwiftData` / `import VoxlueData` / `import VoxlueServices`，删去末尾重复的 `import VoxlueData`。

- [ ] **Step 5: 构建并提交**

Run（从仓库根目录）：

```bash
xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule
git commit -m "feat(app): 新增依赖容器 AppEnvironment 与 RootTabView 骨架"
```

---

## Task 8: 声纹绘制控件 WaveformView 与样片墙 ShelfView 【前端】

`WaveformView` 把 `[Float]` 声纹画成竖条，可选标注播放进度。`ShelfView` 是样片墙 —— 按 `createdAt` 倒序列出全部胶囊，每行显示状态 / 锁 / 标题。它替换 `DebugRootView` 成为「样片墙」标签内容。

**Files:**
- Create: `voxule/voxule/WaveformView.swift`
- Create: `voxule/voxule/CapsuleRow.swift`
- Create: `voxule/voxule/ShelfView.swift`

- [ ] **Step 1: 写声纹绘制控件 WaveformView**

创建 `voxule/voxule/WaveformView.swift`：

```swift
import SwiftUI

/// 声纹控件 —— 把归一化采样点（0...1）画成一排竖条。
/// `progress` 之前的竖条用主色，之后用淡色，用于回放进度可视化。
struct WaveformView: View {
    let samples: [Float]
    /// 播放进度 0...1。传 nil 则不区分已播/未播（录音时用）。
    var progress: Double? = nil
    var tint: Color = .primary

    var body: some View {
        GeometryReader { geo in
            let count = max(samples.count, 1)
            let spacing: CGFloat = 2
            let barWidth = max(1, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, value in
                    let played = progress.map { Double(index) / Double(count) <= $0 } ?? true
                    Capsule()
                        .fill(played ? tint : tint.opacity(0.25))
                        .frame(
                            width: barWidth,
                            height: max(2, CGFloat(value) * geo.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview {
    WaveformView(samples: (0..<80).map { Float(abs(sin(Double($0) / 6))) },
                 progress: 0.4, tint: .orange)
        .frame(height: 60)
        .padding()
}
```

> 此文件不 `import VoxlueData`，`Capsule` 即 `SwiftUI.Capsule` 形状，无需消歧义。

- [ ] **Step 2: 写样片墙行 CapsuleRow**

创建 `voxule/voxule/CapsuleRow.swift`：

```swift
import SwiftUI
import VoxlueData

/// 样片墙的一行 —— 一枚胶囊的缩略：标题 + 状态 + 锁。
struct CapsuleRow: View {
    let capsule: VoxlueData.Capsule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: lockIcon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(capsule.title.isEmpty ? "（无题）" : capsule.title)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(stateLabel)
                    Text("·")
                    Text(lockLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var lockIcon: String {
        switch capsule.lock.kind {
        case .place: "mappin.and.ellipse"
        case .date: "calendar"
        case .mood: "heart"
        }
    }

    private var lockLabel: String {
        switch capsule.lock.kind {
        case .place: "地点锁"
        case .date: "时间锁"
        case .mood: "情绪锁"
        }
    }

    private var stateLabel: String {
        switch capsule.state {
        case .buried: "已埋下"
        case .developing: "显影中"
        case .developed: "等你听"
        case .opened: "已开启"
        }
    }
}
```

- [ ] **Step 3: 写样片墙 ShelfView**

创建 `voxule/voxule/ShelfView.swift`：

```swift
import SwiftUI
import SwiftData
import VoxlueData

/// 样片墙 —— 全部胶囊按埋下时间倒序排开，是 App 的主页。
struct ShelfView: View {
    @Query(sort: \VoxlueData.Capsule.createdAt, order: .reverse)
    private var capsules: [VoxlueData.Capsule]

    @State private var isRecording = false

    var body: some View {
        NavigationStack {
            Group {
                if capsules.isEmpty {
                    ContentUnavailableView(
                        "样片墙还空着",
                        systemImage: "rectangle.stack",
                        description: Text("冲一张声音，埋下它。")
                    )
                } else {
                    List {
                        ForEach(capsules) { capsule in
                            NavigationLink(value: capsule.id) {
                                CapsuleRow(capsule: capsule)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("样片墙")
            .navigationDestination(for: UUID.self) { id in
                if let capsule = capsules.first(where: { $0.id == id }) {
                    CapsuleDetailView(capsule: capsule)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("冲一张", systemImage: "mic.circle.fill") {
                        isRecording = true
                    }
                }
            }
            .fullScreenCover(isPresented: $isRecording) {
                RecordView()
            }
        }
    }
}

#Preview {
    ShelfView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
```

- [ ] **Step 4: 构建验证**

Run（从仓库根目录）：

```bash
xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`（此时 `RecordView` / `CapsuleDetailView` 尚未建，构建会因找不到这两个类型失败 —— 这是预期，Task 9、10 补齐后再次构建即通过。**本 Step 暂跳过构建，留到 Task 10 Step 4 统一验证。**）

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/WaveformView.swift voxule/voxule/CapsuleRow.swift voxule/voxule/ShelfView.swift
git commit -m "feat(app): 新增样片墙 ShelfView 与声纹控件 WaveformView"
```

---

## Task 9: 录音视图与装裱视图 【前端】

录音视图按住/点按录音、显示实时声纹与计时。装裱视图承接录音产物，让用户选三把锁之一、选收件人、填标题（端侧代写标题留接口），确认后写入 `CapsuleStore`、`state = buried`。

**Files:**
- Create: `voxule/voxule/RecordView.swift`
- Create: `voxule/voxule/FramingView.swift`

- [ ] **Step 1: 写录音视图 RecordView**

创建 `voxule/voxule/RecordView.swift`：

```swift
import SwiftUI
import VoxlueServices

/// 录音视图 —— 点按开始/停止录音，实时声纹与计时。
/// 停录后把 RecordingResult 交给装裱视图。
struct RecordView: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var permissionDenied = false
    @State private var liveSamples: [Float] = []
    @State private var result: RecordingResult?
    @State private var sampleTimer: Timer?

    private var recorder: any AudioRecording { env.recorder }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(timeString(recorder.elapsed))
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .contentTransition(.numericText())

                WaveformView(samples: liveSamples.isEmpty ? idleSamples : liveSamples,
                             tint: recorder.isRecording ? .red : .secondary)
                    .frame(height: 80)
                    .padding(.horizontal)

                Spacer()

                Button {
                    recorder.isRecording ? stop() : start()
                } label: {
                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(recorder.isRecording ? .red : .accentColor)
                }
                .accessibilityLabel(recorder.isRecording ? "停止" : "开始冲洗")

                Text(recorder.isRecording ? "正在冲洗这一张……" : "点按，冲一张声音")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationTitle("冲洗台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        recorder.cancel()
                        dismiss()
                    }
                }
            }
            .alert("没有麦克风权限", isPresented: $permissionDenied) {
                Button("好") {}
            } message: {
                Text("请到「设置」里允许 voxlue 使用麦克风。")
            }
            .navigationDestination(item: $result) { recording in
                FramingView(recording: recording) { dismiss() }
            }
        }
    }

    /// 未录音时显示的静默声纹占位。
    private var idleSamples: [Float] { [Float](repeating: 0.06, count: 80) }

    private func start() {
        Task {
            guard await recorder.requestPermission() else {
                permissionDenied = true
                return
            }
            do {
                try recorder.start()
                startLiveSampling()
            } catch {
                permissionDenied = true
            }
        }
    }

    /// 录音时每 0.1s 取一次当前 elapsed 推一个动态采样，做实时声纹动效。
    private func startLiveSampling() {
        liveSamples = []
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard recorder.isRecording else { return }
                let value = Float.random(in: 0.2...1.0)
                liveSamples.append(value)
                if liveSamples.count > 80 { liveSamples.removeFirst() }
            }
        }
    }

    private func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        Task {
            do {
                result = try await recorder.stop()
            } catch {
                recorder.cancel()
                dismiss()
            }
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    RecordView()
        .environment(\.appEnvironment, .preview())
        .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
```

> 实时声纹用随机抖动占位 —— 真 `AudioEngine` 录音时也只在 `stop()` 才产出完整声纹，录音中的逐帧电平不属于契约面。此处随机抖动只为动效；最终落库的是 `RecordingResult.waveform`。

- [ ] **Step 2: 写装裱视图 FramingView**

创建 `voxule/voxule/FramingView.swift`：

```swift
import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

/// 装裱视图 —— 给录音选锁、选收件人、定标题，确认后埋下。
struct FramingView: View {
    let recording: RecordingResult
    /// 埋下成功后回调，用于关掉整个录音流程。
    let onBuried: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var lockKind: Lock.Kind = .mood
    @State private var recipient: Recipient = .me
    /// 时间锁选定的日期，默认一周后。
    @State private var dateLockTarget = Date().addingTimeInterval(7 * 24 * 3600)
    @State private var saveFailed = false

    var body: some View {
        Form {
            Section("这一张") {
                LabeledContent("时长", value: durationString)
                WaveformView(samples: recording.waveform, tint: .accentColor)
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("标题") {
                TextField("给这张声音起个名", text: $title)
                Button("让冲洗师代写", systemImage: "wand.and.stars") {
                    title = draftTitle()
                }
                .font(.callout)
            }

            Section("上一把锁") {
                Picker("锁", selection: $lockKind) {
                    Text("地点锁").tag(Lock.Kind.place)
                    Text("时间锁").tag(Lock.Kind.date)
                    Text("情绪锁").tag(Lock.Kind.mood)
                }
                .pickerStyle(.segmented)
                if lockKind == .date {
                    DatePicker("到这天显影", selection: $dateLockTarget,
                               in: Date()..., displayedComponents: [.date])
                }
                Text(lockHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("给谁") {
                Picker("收件人", selection: $recipient) {
                    Text("自己").tag(Recipient.me)
                    Text("声音圈").tag(Recipient.circle)
                }
                Text("收件人埋下时定死，之后不可改。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("装裱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("埋下") { bury() }
            }
        }
        .alert("没能定影", isPresented: $saveFailed) {
            Button("好") {}
        } message: {
            Text("写入失败，请再试一次。")
        }
    }

    private var durationString: String {
        let total = Int(recording.duration)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var lockHint: String {
        switch lockKind {
        case .place: "走到某个地方，它才会显影。地点在地图里细选 —— 计划 03 接入。"
        case .date: "到选定那天，它自己浮现。"
        case .mood: "在你需要的时候，它会被轻轻送来。"
        }
    }

    /// 端侧大模型代写标题的接入点。v1 先用占位实现，计划 06 接 IntelligenceService。
    private func draftTitle() -> String {
        let pool = ["未命名的雨", "某个安静的下午", "留给以后的声音", "一段没说完的话"]
        return pool.randomElement() ?? "未命名"
    }

    /// 由 lockKind 与表单状态组装出最终的 Lock。
    private func makeLock() -> Lock {
        switch lockKind {
        case .place:
            // 地点锁的坐标在计划 03 的地图里细选，这里先落一个占位围栏。
            return .place(latitude: 0, longitude: 0, radius: 100, placeName: "待选地点")
        case .date:
            return .date(dateLockTarget)
        case .mood:
            return .mood(notBefore: nil)
        }
    }

    private func bury() {
        let capsule = VoxlueData.Capsule(
            title: title,
            audioData: recording.audioData,
            duration: recording.duration,
            waveform: recording.waveform,
            state: .buried,
            lock: makeLock(),
            recipient: recipient
        )
        do {
            try CapsuleStore(context: context).add(capsule)
            onBuried()
        } catch {
            saveFailed = true
        }
    }
}

#Preview {
    NavigationStack {
        FramingView(
            recording: RecordingResult(
                audioData: Data("preview".utf8),
                duration: 8,
                waveform: FakeAudioRecording.fakeWaveform
            ),
            onBuried: {}
        )
    }
    .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
```

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/RecordView.swift voxule/voxule/FramingView.swift
git commit -m "feat(app): 新增录音视图与装裱视图，跑通埋下流程"
```

---

## Task 10: 胶囊详情与回放视图 【前端】

详情页展示一枚胶囊的全部信息，含播放控制 —— 播放/暂停、声纹进度、可拖动 seek。首次播放把状态推进到 `opened`。

**Files:**
- Create: `voxule/voxule/CapsuleDetailView.swift`

- [ ] **Step 1: 写胶囊详情视图 CapsuleDetailView**

创建 `voxule/voxule/CapsuleDetailView.swift`：

```swift
import SwiftUI
import SwiftData
import VoxlueData
import VoxlueServices

/// 胶囊详情 + 回放。
struct CapsuleDetailView: View {
    let capsule: VoxlueData.Capsule

    @Environment(\.appEnvironment) private var env
    @Environment(\.modelContext) private var context

    @State private var loaded = false
    @State private var loadFailed = false

    private var player: any AudioPlaying { env.player }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                WaveformView(
                    samples: capsule.waveform.isEmpty
                        ? [Float](repeating: 0.1, count: 80)
                        : capsule.waveform,
                    progress: player.progress,
                    tint: .accentColor
                )
                .frame(height: 96)

                playbackControls

                metadata
            }
            .padding()
        }
        .navigationTitle(capsule.title.isEmpty ? "（无题）" : capsule.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: prepare)
        .onDisappear { player.pause() }
        .alert("没能放出这段声音", isPresented: $loadFailed) {
            Button("好") {}
        } message: {
            Text("音频读取失败。")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: lockIcon)
            Text(lockLabel)
            Text("·")
            Text(stateLabel)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var playbackControls: some View {
        VStack(spacing: 12) {
            Slider(
                value: Binding(
                    get: { player.progress },
                    set: { player.seek(toProgress: $0) }
                ),
                in: 0...1
            )
            HStack {
                Text(progressTimeString)
                Spacer()
                Text(durationString)
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

            Button {
                togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .disabled(!loaded)
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let place = capsule.placeName {
                LabeledContent("录于", value: place)
            }
            if let note = capsule.note, !note.isEmpty {
                LabeledContent("批注", value: note)
            }
            LabeledContent("埋于", value: capsule.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .font(.callout)
    }

    private func prepare() {
        guard !loaded else { return }
        guard let data = capsule.audioData, !data.isEmpty else {
            loadFailed = true
            return
        }
        do {
            try player.load(data)
            loaded = true
        } catch {
            loadFailed = true
        }
    }

    private func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
            markOpenedIfNeeded()
        }
    }

    /// 首次播放把胶囊状态推进到 opened。
    private func markOpenedIfNeeded() {
        guard capsule.state != .opened else { return }
        try? CapsuleStore(context: context).updateState(capsule, to: .opened)
    }

    private var progressTimeString: String {
        timeString(player.progress * capsule.duration)
    }

    private var durationString: String { timeString(capsule.duration) }

    private func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var lockIcon: String {
        switch capsule.lock.kind {
        case .place: "mappin.and.ellipse"
        case .date: "calendar"
        case .mood: "heart"
        }
    }

    private var lockLabel: String {
        switch capsule.lock.kind {
        case .place: "地点锁"
        case .date: "时间锁"
        case .mood: "情绪锁"
        }
    }

    private var stateLabel: String {
        switch capsule.state {
        case .buried: "已埋下"
        case .developing: "显影中"
        case .developed: "等你听"
        case .opened: "已开启"
        }
    }
}

#Preview {
    NavigationStack {
        CapsuleDetailView(
            capsule: VoxlueData.Capsule(
                title: "咖啡馆的雨",
                audioData: Data("preview".utf8),
                duration: 8,
                waveform: FakeAudioRecording.fakeWaveform,
                state: .developed,
                lock: .date(.now)
            )
        )
    }
    .environment(\.appEnvironment, .preview())
    .modelContainer(for: VoxlueDataModelsPreview.all, inMemory: true)
}
```

- [ ] **Step 2: 包测试回归**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: `Test run with 31 tests passed`

- [ ] **Step 3: App 构建验证**

Run（从仓库根目录，此时 Task 8/9/10 的视图已全部就位）：

```bash
xcodebuild -project voxule/voxule.xcodeproj -scheme voxule -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 模拟器手动跑主循环**

在 Xcode 用 iPhone 17 模拟器运行（⌘R），按下表逐项确认：

| 步骤 | 预期 |
|---|---|
| 启动 | 进入「样片墙」标签，空态显示「样片墙还空着」 |
| 点「冲一张」 | 弹出冲洗台；模拟器首次录音弹麦克风授权，允许 |
| 点麦克风按钮录几秒再点停止 | 计时走动、声纹跳动；停止后进入「装裱」 |
| 装裱：填标题、选「时间锁」、选「自己」、点「埋下」 | 关闭录音流程，回到样片墙 |
| 样片墙 | 出现一行，显示标题 / 「已埋下」/ 「时间锁」 |
| 点这一行 | 进详情页，声纹完整显示 |
| 点播放 | 声音放出（模拟器录的多为静音也算通过），进度条与声纹进度推进；返回样片墙该行状态变「已开启」 |
| 杀掉 App 重开 | 胶囊仍在样片墙（验证持久化） |

> 真机/模拟器录音权限弹窗依赖 Task 6 Step 3 的麦克风用途说明，缺它会直接崩溃。

- [ ] **Step 5: 提交**

```bash
cd /Users/cornna/project/voxule
git add voxule/voxule/CapsuleDetailView.swift
git commit -m "feat(app): 新增胶囊详情与回放视图，主循环端到端跑通"
```

---

## Task 11: 埋下写入路径回归测试 【协作者】

录音触麦克风、回放出声都不进自动化测试，但「装裱埋下」的写库路径是纯数据逻辑，必须独测 —— 直接构造 `RecordingResult`、走 `CapsuleStore` 写入、断言落库结果，不碰任何视图。

**Files:**
- Create: `VoxlueKit/Tests/VoxlueServicesTests/BuryCapsuleTests.swift`

- [ ] **Step 1: 写测试**

创建 `VoxlueKit/Tests/VoxlueServicesTests/BuryCapsuleTests.swift`：

```swift
import Testing
import Foundation
import SwiftData
import VoxlueData
@testable import VoxlueServices

// 验证「装裱埋下」的写库路径：RecordingResult → Capsule → CapsuleStore。
// 这条路径在 App 的 FramingView.bury() 里，此处脱离 UI 直接测数据逻辑。

@MainActor
@Test func buryingRecordingResultPersistsBuriedCapsule() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)

    let recording = RecordingResult(
        audioData: Data("audio".utf8),
        duration: 8,
        waveform: FakeAudioRecording.fakeWaveform
    )
    let capsule = Capsule(
        title: "咖啡馆的雨",
        audioData: recording.audioData,
        duration: recording.duration,
        waveform: recording.waveform,
        state: .buried,
        lock: .date(Date(timeIntervalSince1970: 1_800_000_000)),
        recipient: .me
    )
    try store.add(capsule)

    let buried = try store.buriedCapsules()
    #expect(buried.count == 1)
    #expect(buried.first?.title == "咖啡馆的雨")
    #expect(buried.first?.duration == 8)
    #expect(buried.first?.waveform.count == 80)
    #expect(buried.first?.lock.kind == .date)
    #expect(buried.first?.audioData == Data("audio".utf8))
}

@MainActor
@Test func openingBuriedCapsuleAdvancesStateAndSetsOpenedAt() throws {
    let container = try VoxlueModelContainer.make(inMemory: true)
    let store = CapsuleStore(context: container.mainContext)

    let capsule = Capsule(title: "回放测试", state: .buried, lock: .mood(notBefore: nil))
    try store.add(capsule)
    try store.updateState(capsule, to: .opened)

    let opened = try store.capsules(in: .opened)
    #expect(opened.count == 1)
    #expect(opened.first?.openedAt != nil)
    #expect(try store.buriedCapsules().isEmpty)
}
```

- [ ] **Step 2: 运行测试，确认通过**

Run: `cd /Users/cornna/project/voxule/VoxlueKit && swift test`
Expected: `Test run with 33 tests passed`（累计：31 + 2 埋下路径）

- [ ] **Step 3: 提交**

```bash
cd /Users/cornna/project/voxule
git add VoxlueKit/Tests/VoxlueServicesTests/BuryCapsuleTests.swift
git commit -m "test(audio): 新增装裱埋下写库路径回归测试"
```

---

## 完成标准

- `cd /Users/cornna/project/voxule/VoxlueKit && swift test` 全绿（**33 个测试通过** —— 计划 01 的 19 个 + 本计划 14 个）。
- `VoxlueServices` 库目标已建并被 App target 链入；`AudioEngine` 真实现 + `FakeAudioRecording` / `FakeAudioPlaying` 假实现齐备，协议签名与路线图 §3.1 逐字一致。
- App 在 iPhone 17 模拟器可运行，能跑通完整主循环：冲一张声音 → 装裱选锁选收件人定标题 → 埋下 → 样片墙倒序列出 → 进详情回放 → 状态推进到 `opened` → 重启后持久化。
- `DebugRootView` 已删除，`RootTabView`（样片墙 / 地图占位 / 我）成为根视图，服务经 `AppEnvironment` 注入环境。
- 麦克风用途说明已配置；声纹下采样纯函数 `Waveform.downsample` 与埋下写库路径均有独立测试覆盖。
- 全部改动已提交 git，每个 Task 一个提交，沿用中文 conventional commits。

下一份计划：**计划 03 · TriggerEngine 三把锁**（地点/时间/情绪触发引擎 + 灵动岛与地图 UI）。

---

## 给执行者的提醒

- **契约冻结：** `RecordingResult` / `AudioRecording` / `AudioPlaying` 三个签名取自路线图 §3.1，任何改动须先改路线图 §3.1 并知会前端轨。
- **命名冲突：** 凡同时 `import SwiftUI` 与 `VoxlueData` 的文件，模型类型一律写全 `VoxlueData.Capsule`，避免与 `SwiftUI.Capsule` 形状冲突。`WaveformView.swift` 不导入 `VoxlueData`，其中的 `Capsule` 即形状，无需消歧义。
- **真假分工：** 真 `AudioEngine` 触麦克风，不进 `swift test`；自动化测试只覆盖纯函数（`Waveform`）、假实现（`Fake*`）与数据路径（埋下写库）。真实现靠 Task 10 Step 4 的模拟器手动清单验证。
- **构建环境：** 包测试在 `VoxlueKit` 目录跑 `swift test`；App 无签名构建从仓库根目录跑 `xcodebuild ... CODE_SIGNING_ALLOWED=NO`，destination 固定 `iPhone 17`（本机无 iPhone 16 模拟器）。
- **Task 顺序：** Task 8 的视图引用了 Task 9、10 才创建的类型，故 Task 8 的 App 构建验证推迟到 Task 10 Step 3 统一执行；包测试（Task 1/2/3/5/11）则可在各自 Task 内独立通过。
