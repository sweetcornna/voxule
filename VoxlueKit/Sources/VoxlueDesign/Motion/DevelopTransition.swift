import SwiftUI

/// 「霜化开」显影转场 —— voxlue 的招牌动效。
/// 胶囊 buried → developing 时播放：影像从一层「霜」里慢慢化开。
/// 实现：模糊 + 去饱和 + 微缩放，三者随显影同步退去。
public struct DevelopTransition: Transition {

    public init() {}

    public func body(content: Content, phase: TransitionPhase) -> some View {
        let developing = phase.isIdentity   // 完成态 = 已显影。
        return content
            .blur(radius: developing ? 0 : 18)                 // 霜 —— 模糊散去。
            .saturation(developing ? 1 : 0)                     // 黑白 → 显出影调。
            .scaleEffect(developing ? 1 : 1.04)                 // 极轻的「浮现」缩放。
            .opacity(developing ? 1 : 0)
    }
}

public extension Transition where Self == DevelopTransition {
    /// `.transition(.develop)` —— 霜化开显影转场。
    static var develop: DevelopTransition { DevelopTransition() }
}

/// 显影动画的标准时长与曲线 —— 全 App 统一用这一条，保证「显影」节奏一致。
public enum DevelopAnimation {
    /// 显影主动画：缓入缓出，1.1 秒 —— 慢得能被「看见在变」。
    public static let curve: Animation = .easeInOut(duration: 1.1)
}

/// 把一个布尔「是否已显影」绑到霜化开转场上的便捷修饰器。
public struct FrostReveal: ViewModifier {
    private let developed: Bool

    public init(developed: Bool) {
        self.developed = developed
    }

    public func body(content: Content) -> some View {
        content
            .blur(radius: developed ? 0 : 18)
            .saturation(developed ? 1 : 0)
            .scaleEffect(developed ? 1 : 1.04)
            .animation(DevelopAnimation.curve, value: developed)
    }
}

public extension View {
    /// 把视图随 `developed` 翻转播放「霜化开」 —— 用于原地显影（非插入/移除）。
    func frostReveal(developed: Bool) -> some View {
        modifier(FrostReveal(developed: developed))
    }
}

#Preview("霜化开") {
    struct Demo: View {
        @State private var developed = false
        var body: some View {
            ZStack {
                VoxlueColor.negativeBlack.ignoresSafeArea()
                VStack(spacing: VoxlueSpacing.xl) {
                    PhotoCard(title: "咖啡馆的雨", meta: "0:48 · 阴") {
                        Rectangle().fill(VoxlueColor.graphite)
                    }
                    .frostReveal(developed: developed)
                    .frame(width: 260)

                    Button("显影") {
                        withAnimation(DevelopAnimation.curve) { developed.toggle() }
                    }
                    .font(VoxlueTypography.meta)
                    .foregroundStyle(VoxlueColor.paper)
                }
            }
        }
    }
    return Demo()
}
