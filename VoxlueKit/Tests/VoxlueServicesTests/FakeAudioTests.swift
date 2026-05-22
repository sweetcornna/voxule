import Testing
import Foundation
@testable import VoxlueServices

@Test func recordingResultIsEquatable() {
    let a = RecordingResult(audioData: Data([1, 2]), duration: 8, waveform: [0.5])
    let b = RecordingResult(audioData: Data([1, 2]), duration: 8, waveform: [0.5])
    #expect(a == b)
}
