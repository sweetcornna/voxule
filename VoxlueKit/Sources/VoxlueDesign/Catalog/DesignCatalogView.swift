import SwiftUI

/// 设计系统图鉴 —— 把 VoxlueDesign 全部内容铺成一页，肉眼可验。
/// 暗房模式（colorScheme = .dark）会同步翻面；可单独打开
/// `DesignCatalogDarkPreviewSection` 在 light 环境里也看一眼 dark 端表现。
public struct DesignCatalogView: View {

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VoxlueSpacing.xxl) {
                header
                colorSection
                darkroomSection      // 暗房模式对照段 —— 在 light 模式下也能看到 dark 端。
                typographySection
                paperSection
                glassSection
                motionSection
            }
            .padding(VoxlueSpacing.xl)
        }
        .background(VoxlueColor.paper.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
            Text("voxlue")
                .font(VoxlueTypography.display)
                .foregroundStyle(VoxlueColor.ink)
            Text("设计系统图鉴 · v\(VoxlueDesign.version) · P3 Photographic Plate")
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.graphite)
        }
    }

    @ViewBuilder private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(VoxlueTypography.heading)
            .foregroundStyle(VoxlueColor.ink)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("纸 · 墨 · 朱 八色")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                      spacing: VoxlueSpacing.md) {
                ForEach(Array(VoxlueColor.palette.enumerated()), id: \.offset) { idx, color in
                    VStack(spacing: VoxlueSpacing.xs) {
                        RoundedRectangle(cornerRadius: VoxlueRadius.photo)
                            .fill(color)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: VoxlueRadius.photo)
                                    .strokeBorder(VoxlueColor.paperShadow, lineWidth: 0.5)
                            )
                        Text(VoxlueColor.paletteNames[idx])
                            .font(VoxlueTypography.meta)
                            .foregroundStyle(VoxlueColor.graphite)
                    }
                }
            }
        }
    }

    /// 暗房模式对照段 —— 把六只自适应 token 的 light/dark 两端铺成左右两栏，
    /// 让设计师不切系统就能比较「翻面前 / 翻面后」。.colorScheme(.dark) 让右栏
    /// 内部用 dark trait 渲染，所以 paperShadow 等 token 显示的就是 dark 端实色。
    private var darkroomSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("暗房模式 · 翻面对照")
            HStack(alignment: .top, spacing: VoxlueSpacing.lg) {
                paletteColumn(title: "light", palette: VoxlueColor.palette)
                paletteColumn(title: "dark",  palette: VoxlueColor.darkPalette)
                    .environment(\.colorScheme, .dark)
            }
            DesignCatalogDarkPreviewSection()
        }
    }

    /// 单栏调色板 —— 8 行 swatch + 中文名 + 注解。环境 colorScheme 决定描边色。
    private func paletteColumn(title: String, palette: [Color]) -> some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            Text(title)
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.graphite)
                .tracking(2)
            ForEach(Array(palette.enumerated()), id: \.offset) { idx, color in
                HStack(spacing: VoxlueSpacing.sm) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 28, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(VoxlueColor.paperShadow, lineWidth: 0.5)
                        )
                    Text(VoxlueColor.paletteNames[idx])
                        .font(VoxlueTypography.meta)
                        .foregroundStyle(VoxlueColor.graphite)
                }
            }
        }
        .padding(VoxlueSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                .fill(VoxlueColor.paperHighlight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                .strokeBorder(VoxlueColor.paperShadow, lineWidth: 0.75)
        )
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("字阶与字体栈")
            Group {
                Text("voxlue · develop").font(VoxlueTypography.display)
                Text("一段待显影的声音").font(VoxlueTypography.serifTitle)
                Text("内容层永远是纸，不是屏幕的反光。").font(VoxlueTypography.serifBody)
                Text("31.21, 121.43 · 0:48").font(VoxlueTypography.meta)
            }
            .foregroundStyle(VoxlueColor.ink)
            MarginNote("Caveat 手写批注 —— 朱红色")
        }
    }

    private var paperSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("暗房纸感控件")
            PhotoCard(title: "咖啡馆的雨", meta: "31.21, 121.43 · 0:48 · 阴") {
                waveform
            }
            NegativeCard(title: "潜伏中的一段声", meta: "已埋下 · 等一个地点") {
                Rectangle().fill(VoxlueColor.graphiteLight)
            }
            PaperCard {
                Text("PaperCard —— 纸感容器基元")
                    .font(VoxlueTypography.serifBody)
                    .foregroundStyle(VoxlueColor.ink)
            }
            HStack(spacing: VoxlueSpacing.md) {
                SealStamp(.buried)
                SealStamp(.developing)
                SealStamp(.developed)
                SealStamp(.opened)
            }
        }
    }

    private var glassSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("液态玻璃导航层")
            // 玻璃需衬深底才看得出折射 —— 用负片黑做背板。
            ZStack {
                RoundedRectangle(cornerRadius: VoxlueRadius.card)
                    .fill(VoxlueColor.negativeBlack)
                    .frame(height: 160)
                VStack(spacing: VoxlueSpacing.lg) {
                    GlassControlBar {
                        Image(systemName: "square.grid.2x2").foregroundStyle(VoxlueColor.paperLight)
                        Image(systemName: "map").foregroundStyle(VoxlueColor.paperLight)
                        Image(systemName: "person.2").foregroundStyle(VoxlueColor.paperLight)
                    }
                    DevelopingIslandLabel(capsuleTitle: "咖啡馆的雨", layout: .expanded)
                }
            }
        }
    }

    private var motionSection: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
            sectionTitle("『霜化开』显影动效")
            DevelopRevealDemo()
        }
    }

    private var waveform: some View {
        // 波形条永远盖在 PhotoCard 的 negativeBlack 图像区上，用固定 light。
        HStack(spacing: 3) {
            ForEach(0..<28, id: \.self) { i in
                Capsule()
                    .fill(VoxlueColor.paperLight.opacity(0.85))
                    .frame(width: 3, height: CGFloat(12 + (i * 7) % 70))
            }
        }
    }
}

/// 暗房模式整屏样片 —— 一组纸卡、纸基底、文字在 dark trait 下原地渲染，
/// 给设计师在 light 环境也能立刻看见整面墙翻面的视觉。
private struct DesignCatalogDarkPreviewSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            Text("暗房模式 · 整屏样片")
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.graphite)
                .tracking(2)

            ZStack {
                // 在 ZStack 内 .environment(\.colorScheme, .dark) 让这一整块按 dark
                // trait 渲染，所有 VoxlueColor 自适应 token 自动取 dark 端取值。
                VoxlueColor.paper.ignoresSafeArea(edges: [])
                VStack(alignment: .leading, spacing: VoxlueSpacing.md) {
                    Text("声音的暗房")
                        .font(VoxlueTypography.heading)
                        .foregroundStyle(VoxlueColor.ink)
                    Text("纸基翻成负片黑，墨翻成暖白；朱红与片基黑不变。")
                        .font(VoxlueTypography.serifBody)
                        .foregroundStyle(VoxlueColor.graphite)
                    PaperCard {
                        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
                            Text("PaperCard 在暗房里")
                                .font(VoxlueTypography.serifTitle)
                                .foregroundStyle(VoxlueColor.ink)
                            Text("片基面是 paperHighlight 的 dark 端 —— 在 negativeBlack 上微抬一档。")
                                .font(VoxlueTypography.caption)
                                .foregroundStyle(VoxlueColor.graphite)
                        }
                    }
                    HStack(spacing: VoxlueSpacing.md) {
                        SealStamp(.developing)
                        MarginNote("朱红不参与翻面")
                    }
                }
                .padding(VoxlueSpacing.lg)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VoxlueRadius.card, style: .continuous)
                    .strokeBorder(VoxlueColor.paperShadow, lineWidth: 0.75)
            )
            .environment(\.colorScheme, .dark)
        }
    }
}

/// 图鉴内的显影动效互动小样。
private struct DevelopRevealDemo: View {
    @State private var developed = false

    var body: some View {
        VStack(spacing: VoxlueSpacing.md) {
            PhotoCard(title: "咖啡馆的雨", meta: "0:48 · 阴") {
                HStack(spacing: 3) {
                    ForEach(0..<28, id: \.self) { i in
                        Capsule()
                            .fill(VoxlueColor.paperLight.opacity(0.85))
                            .frame(width: 3, height: CGFloat(12 + (i * 7) % 70))
                    }
                }
            }
            .frostReveal(developed: developed)

            Button(developed ? "重新埋下" : "显影这一张") {
                withAnimation(DevelopAnimation.curve) { developed.toggle() }
            }
            .font(VoxlueTypography.meta)
            .foregroundStyle(VoxlueColor.vermillion)
        }
    }
}

#Preview("light") {
    DesignCatalogView()
}

#Preview("dark") {
    DesignCatalogView()
        .preferredColorScheme(.dark)
}
