import SwiftUI

/// 负片 —— 一枚埋下后、尚未显影的胶囊的样子。
/// 反相：深底亮字，标题被「冲淡」。胶囊显影后会换成 PhotoCard。
public struct NegativeCard<Image: View>: View {
    private let title: String
    private let meta: String
    private let image: Image

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
        VStack(alignment: .leading, spacing: VoxlueSpacing.sm) {
            image
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .opacity(0.55)               // 未显影 —— 影像偏淡。

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
