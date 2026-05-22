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
