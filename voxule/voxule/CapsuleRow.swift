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
