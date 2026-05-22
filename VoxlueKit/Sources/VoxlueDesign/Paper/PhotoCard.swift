import SwiftUI

/// 相片 —— 一段声音被装裱后的样子。
/// 相纸边白（顶部图像区 + 底部片基白条），片基上印标题与元数据小字。
public struct PhotoCard<Image: View>: View {
    private let title: String
    private let meta: String
    private let image: Image

    /// - Parameters:
    ///   - title: 相片标题（思源宋）。
    ///   - meta: 片基小字 —— 坐标 / 时长 / 天气（Space Mono）。
    ///   - image: 图像区内容，通常是声纹波形视图。
    public init(
        title: String,
        meta: String,
        @ViewBuilder image: () -> Image
    ) {
        self.title = title
        self.meta = meta
        self.image = image()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 图像区 —— 深底，相纸里被显影的那块。
            image
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(VoxlueColor.negativeBlack)

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
            // 占位声纹：等宽竖条。
            HStack(spacing: 3) {
                ForEach(0..<28, id: \.self) { i in
                    Capsule()
                        .fill(VoxlueColor.paper.opacity(0.85))
                        .frame(width: 3, height: CGFloat(12 + (i * 7) % 70))
                }
            }
        }
        .padding(VoxlueSpacing.xl)
    }
}
