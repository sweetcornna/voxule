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
