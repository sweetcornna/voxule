import SwiftUI
import VoxlueData
import VoxlueDesign

/// 样片墙的一张相片 —— PhotoCard 包住声纹缩略，右上角盖朱章标状态。
struct CapsuleRow: View {
    let capsule: VoxlueData.Capsule

    var body: some View {
        PhotoCard(title: displayTitle, meta: metaLine, seal: sealKind) {
            // 图像区 —— 声纹波形，黑底白线。
            WaveformView(
                samples: capsule.waveform.isEmpty
                    ? [Float](repeating: 0.08, count: 64)
                    : capsule.waveform,
                tint: VoxlueColor.paperHighlight
            )
            .padding(.horizontal, VoxlueSpacing.lg)
        }
    }

    private var displayTitle: String {
        capsule.title.isEmpty ? "（无题）" : capsule.title
    }

    /// 片基小字 —— 锁类型 · 时长。
    private var metaLine: String {
        var parts: [String] = [lockLabel]
        if capsule.duration > 0 {
            parts.append(durationString)
        }
        if let place = capsule.placeName, !place.isEmpty {
            parts.append(place)
        }
        return parts.joined(separator: " · ")
    }

    private var durationString: String {
        let total = Int(capsule.duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var lockLabel: String {
        switch capsule.lock.kind {
        case .place: "地点锁"
        case .date: "时间锁"
        case .mood: "情绪锁"
        }
    }

    private var sealKind: SealStamp.Kind {
        switch capsule.state {
        case .buried: .buried
        case .developing: .developing
        case .developed: .developed
        case .opened: .opened
        }
    }
}
