import SwiftUI

/// 负片 —— 一枚埋下后、尚未显影的胶囊的样子。
/// 反相：深底亮字，标题被「冲淡」。胶囊显影后会换成 PhotoCard。
public struct NegativeCard<Image: View>: View {
    private let title: String
    private let meta: String
    private let seal: SealStamp.Kind?
    private let image: Image

    /// - Parameters:
    ///   - seal: 可选的朱章。给的话盖在反相影像区右上角；仍区分锁类型。
    public init(
        title: String,
        meta: String,
        seal: SealStamp.Kind? = nil,
        @ViewBuilder image: () -> Image
    ) {
        self.title = title
        self.meta = meta
        self.seal = seal
        self.image = image()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            // 影像区 —— 与 PhotoCard 150pt 对齐，混排时行高一致。
            image
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .opacity(0.55)               // 未显影 —— 影像偏淡。
                .overlay(alignment: .topTrailing) {
                    if let seal {
                        SealStamp(seal)
                            .padding(.top, VoxlueSpacing.sm)
                            .padding(.trailing, VoxlueSpacing.sm)
                    }
                }

            Text(title)
                .font(VoxlueTypography.serifTitle)
                .foregroundStyle(VoxlueColor.paper)
                .lineLimit(1)
            Text(meta)
                .font(VoxlueTypography.meta)
                .foregroundStyle(VoxlueColor.darkroomGray)
                .lineLimit(1)
        }
        .padding(VoxlueSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VoxlueRadius.photo, style: .continuous)
                .fill(VoxlueColor.negativeBlack)
        )
        .voxlueShadow(.photo)
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        NegativeCard(title: "潜伏中的一段声", meta: "已埋下 · 等一个地点") {
            Rectangle().fill(VoxlueColor.graphite)
        }
        .padding(VoxlueSpacing.xl)
    }
}
