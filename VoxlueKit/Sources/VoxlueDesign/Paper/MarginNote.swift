import SwiftUI

/// 批注 —— 写在相片边上的朱红手写小字。
/// 用 Caveat 手写体，朱红色，像冲洗师在样片边角随手记的一句。
public struct MarginNote: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .top, spacing: VoxlueSpacing.xs) {
            // 一道朱红短画，像批注的引出线。
            Rectangle()
                .fill(VoxlueColor.vermillion)
                .frame(width: 14, height: 1.5)
                .padding(.top, 12)
            Text(text)
                .font(VoxlueTypography.annotation)
                .foregroundStyle(VoxlueColor.vermillion)
        }
    }
}

#Preview {
    ZStack {
        VoxlueColor.paper.ignoresSafeArea()
        MarginNote("这一段，是奶奶哼的调子")
            .padding(VoxlueSpacing.xl)
    }
}
