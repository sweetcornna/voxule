import SwiftUI

/// 灵动岛 / 通知里的「显影中」玻璃标签。
/// 一枚胶囊进入 developing 时显示，呼应「这里有一张你洗过一次的相」。
/// 实际 Live Activity 接线在计划 03；此处只产出可复用的视觉。
public struct DevelopingIslandLabel: View {

    /// 紧凑（灵动岛 compact）或展开（expanded / 通知）两种形态。
    public enum Layout: Sendable { case compact, expanded }

    private let capsuleTitle: String
    private let layout: Layout

    public init(capsuleTitle: String, layout: Layout = .compact) {
        self.capsuleTitle = capsuleTitle
        self.layout = layout
    }

    public var body: some View {
        HStack(spacing: VoxlueSpacing.sm) {
            // 朱红显影点 —— 安全灯。
            Circle()
                .fill(VoxlueColor.vermillion)
                .frame(width: 8, height: 8)

            if layout == .expanded {
                VStack(alignment: .leading, spacing: 1) {
                    Text("显影中")
                        .font(VoxlueTypography.meta)
                        .foregroundStyle(VoxlueColor.darkroomGray)
                    Text(capsuleTitle)
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.paper)
                        .lineLimit(1)
                }
            } else {
                Text("显影中")
                    .font(VoxlueTypography.meta)
                    .foregroundStyle(VoxlueColor.paper)
            }
        }
        .padding(.horizontal, VoxlueSpacing.md)
        .padding(.vertical, VoxlueSpacing.sm)
        .voxlueGlass(tint: GlassTint.vermillionWash)
    }
}

#Preview {
    ZStack {
        VoxlueColor.negativeBlack.ignoresSafeArea()
        VStack(spacing: VoxlueSpacing.xl) {
            DevelopingIslandLabel(capsuleTitle: "咖啡馆的雨", layout: .compact)
            DevelopingIslandLabel(capsuleTitle: "咖啡馆的雨", layout: .expanded)
        }
    }
}
