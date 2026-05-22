import SwiftUI

/// 朱章 —— 盖在相片上的状态印。朱红、方、带一点旋转，像真盖上去的。
public struct SealStamp: View {

    /// 章的语义。
    public enum Kind: Sendable {
        case buried       // 已埋下
        case developing   // 显影中
        case developed    // 已显影
        case opened       // 已开启

        var text: String {
            switch self {
            case .buried:     "已埋下"
            case .developing: "显影中"
            case .developed:  "待你听"
            case .opened:     "已开启"
            }
        }
    }

    private let kind: Kind

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public var body: some View {
        Text(kind.text)
            .font(VoxlueTypography.meta)
            .tracking(2)
            .foregroundStyle(VoxlueColor.vermillion)
            .padding(.horizontal, VoxlueSpacing.sm)
            .padding(.vertical, VoxlueSpacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: VoxlueRadius.stamp, style: .continuous)
                    .strokeBorder(VoxlueColor.vermillion, lineWidth: 1.5)
            )
            .rotationEffect(.degrees(-8))     // 手盖的章不会正。
            .opacity(0.88)                    // 印泥透出底纹。
            .voxlueShadow(.stamp)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        HStack(spacing: VoxlueSpacing.lg) {
            SealStamp(.buried)
            SealStamp(.developing)
            SealStamp(.developed)
            SealStamp(.opened)
        }
    }
}
