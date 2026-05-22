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
