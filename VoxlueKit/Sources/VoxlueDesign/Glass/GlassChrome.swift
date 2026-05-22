import SwiftUI

/// 浮动玻璃控制条 —— 漂在样片墙 / 地图之上的操作 chrome。
/// 例：浮动「冲一张」录音键、地图上的图层切换。
public struct GlassControlBar<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        // GlassEffectContainer 让同容器内多片玻璃融合、流动。
        GlassEffectContainer(spacing: VoxlueSpacing.md) {
            HStack(spacing: VoxlueSpacing.md) {
                content
            }
            .padding(.horizontal, VoxlueSpacing.lg)
            .padding(.vertical, VoxlueSpacing.md)
        }
        .voxlueGlass(tint: GlassTint.cream)
    }
}

/// 玻璃浮动主按钮 —— 「冲一张」录音入口。暖朱玻璃、可交互。
public struct GlassFloatingButton: View {
    private let systemImage: String
    private let action: () -> Void

    public init(systemImage: String = "mic.fill", action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(VoxlueColor.vermillion)
                .frame(width: 60, height: 60)
        }
        .voxlueGlass(tint: GlassTint.vermillionWash, interactive: true)
        .clipShape(Circle())
    }
}

/// sheet 的玻璃顶把手区。把 sheet 内容包成「玻璃 chrome + 纸内容」。
public struct GlassSheetChrome<Content: View>: View {
    private let title: String
    private let content: Content

    public init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 玻璃标题条 —— chrome。
            Text(title)
                .font(VoxlueTypography.serifTitle)
                .foregroundStyle(VoxlueColor.ink)
                .frame(maxWidth: .infinity)
                .padding(VoxlueSpacing.lg)
                .voxlueGlass(tint: GlassTint.cream)
            // 纸内容区 —— content。
            content
                .frame(maxWidth: .infinity)
                .background(VoxlueColor.paper)
        }
    }
}

#Preview("浮动玻璃") {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        VStack(spacing: VoxlueSpacing.xl) {
            GlassControlBar {
                Image(systemName: "square.grid.2x2").foregroundStyle(VoxlueColor.ink)
                Image(systemName: "map").foregroundStyle(VoxlueColor.ink)
                Image(systemName: "person.2").foregroundStyle(VoxlueColor.ink)
            }
            GlassFloatingButton {}
        }
    }
}
