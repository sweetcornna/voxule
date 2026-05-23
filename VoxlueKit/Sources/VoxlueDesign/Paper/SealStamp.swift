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
    @State private var stamped = false

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
            // 入场如真的盖章：先抬起 + 偏正、淡，落地缩到 -8° 与 0.88 不透明。
            .scaleEffect(stamped ? 1 : 1.35)
            .rotationEffect(.degrees(stamped ? -8 : 6))
            .opacity(stamped ? 0.88 : 0)
            .voxlueShadow(.stamp)
            .onAppear {
                // spring 收束 —— 0.4s 落定，比霜化（1.1s）快，给到「盖一下」的果断。
                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    stamped = true
                }
            }
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
