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
    private let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamped = false

    /// - Parameters:
    ///   - delay: 入场动效延迟。多枚朱章同时入场时（如样片墙刷到一屏）传 staggered
    ///     值（建议 0~0.24 之间）形成级联，不要全部同时盖下来。
    public init(_ kind: Kind, delay: Double = 0) {
        self.kind = kind
        self.delay = delay
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
            .onAppear(perform: stampIn)
    }

    private func stampIn() {
        // Preview 与 UI 测试快照不应捕到中间帧 —— 直接落定。
        // 用户开了「减弱动效」也跳过 spring。
        if Self.skipsAnimation || reduceMotion {
            stamped = true
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65).delay(delay)) {
            stamped = true
        }
    }

    /// SwiftUI Preview 与 UI 测试环境标志 —— 让朱章入场跳过 spring 直接落定。
    private static let skipsAnimation: Bool = {
        let env = ProcessInfo.processInfo.environment
        return env["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || env["XCTestSessionIdentifier"] != nil
    }()
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
