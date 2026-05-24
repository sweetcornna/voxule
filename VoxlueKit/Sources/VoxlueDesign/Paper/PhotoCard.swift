import SwiftUI

/// 相片 —— 一段声音被装裱后的样子。
/// 相纸边白（顶部图像区 + 底部片基白条），片基上印标题与元数据小字。
public struct PhotoCard<Image: View>: View {
    private let title: String
    private let meta: String
    private let seal: SealStamp.Kind?
    private let sealDelay: Double
    private let image: Image

    /// - Parameters:
    ///   - title: 相片标题（思源宋）。
    ///   - meta: 片基小字 —— 坐标 / 时长 / 天气（Space Mono）。
    ///   - seal: 可选的朱章状态。设了就盖在图像区右上角。
    ///   - sealDelay: 朱章入场动效延迟。同屏多枚卡片传 staggered 值形成级联。
    ///   - image: 图像区内容，通常是声纹波形视图。
    public init(
        title: String,
        meta: String,
        seal: SealStamp.Kind? = nil,
        sealDelay: Double = 0,
        @ViewBuilder image: () -> Image
    ) {
        self.title = title
        self.meta = meta
        self.seal = seal
        self.sealDelay = sealDelay
        self.image = image()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 图像区 —— 深底，相纸里被显影的那块。
            // 上下加一排胶片孔洞，让相纸看上去是「胶卷剪下来的一段」。
            image
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(VoxlueColor.negativeBlack)
                .overlay(FilmPerforations(edge: .top))
                .overlay(FilmPerforations(edge: .bottom))
                .overlay(alignment: .topTrailing) {
                    if let seal {
                        SealStamp(seal, delay: sealDelay)
                            .padding(.top, FilmPerforations.safeContentInset)
                            .padding(.trailing, VoxlueSpacing.sm)
                    }
                }

            // 片基白条 —— 印标题与元数据。
            VStack(alignment: .leading, spacing: VoxlueSpacing.xs) {
                Text(title)
                    .font(VoxlueTypography.serifTitle)
                    .foregroundStyle(VoxlueColor.ink)
                    .lineLimit(1)
                Text(meta)
                    .font(VoxlueTypography.meta)
                    .foregroundStyle(VoxlueColor.darkroomGray)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(VoxlueSpacing.md)
            .background(VoxlueColor.paperHighlight)
        }
        .clipShape(RoundedRectangle(cornerRadius: VoxlueRadius.photo, style: .continuous))
        .voxlueShadow(.photo)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        PhotoCard(
            title: "咖啡馆的雨",
            meta: "31.21, 121.43 · 0:48 · 阴"
        ) {
            // 占位声纹：等宽竖条。波形条永远盖在负片黑图像区上，用固定 light。
            HStack(spacing: 3) {
                ForEach(0..<28, id: \.self) { i in
                    Capsule()
                        .fill(VoxlueColor.paperLight.opacity(0.85))
                        .frame(width: 3, height: CGFloat(12 + (i * 7) % 70))
                }
            }
        }
        .padding(VoxlueSpacing.xl)
    }
}
