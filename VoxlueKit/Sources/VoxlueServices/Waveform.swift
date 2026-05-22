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
