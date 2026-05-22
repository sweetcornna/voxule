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
