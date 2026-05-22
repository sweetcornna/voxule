import SwiftUI

/// 设计系统图鉴 —— 把 VoxlueDesign 全部内容铺成一页，肉眼可验。
public struct DesignCatalogView: View {

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VoxlueSpacing.xxl) {
                header
                colorSection
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
                Rectangle().fill(VoxlueColor.graphite)
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
                        Image(systemName: "square.grid.2x2").foregroundStyle(VoxlueColor.paper)
                        Image(systemName: "map").foregroundStyle(VoxlueColor.paper)
                        Image(systemName: "person.2").foregroundStyle(VoxlueColor.paper)
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
        HStack(spacing: 3) {
            ForEach(0..<28, id: \.self) { i in
                Capsule()
                    .fill(VoxlueColor.paper.opacity(0.85))
                    .frame(width: 3, height: CGFloat(12 + (i * 7) % 70))
            }
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
                            .fill(VoxlueColor.paper.opacity(0.85))
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

#Preview {
    DesignCatalogView()
}
