import SwiftUI
import UIKit
import VoxlueDesign

/// 暗房纸基底 —— 纸色 + 极淡噪点叠加，给 .paper 物质性。
/// 直接当 ZStack 第一项用：`ZStack { PaperBackground().ignoresSafeArea(); content }`
/// 不再以 `.paperGrain()` view 扩展形式存在，避免被错挂到内容层上。
///
/// 暗房模式（colorScheme = .dark）：
/// - 底色翻成 `VoxlueColor.paper` 的 dark 端（negativeBlack）；
/// - 噪点从「纸上的墨点」翻成「负片乳剂的亮粒」——
///   光与暗在两个方向上仍然是同一种「颗粒物质感」。
struct PaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // 纸色在最底；噪点 overlay 落在纸色之上，仍由 ZStack 顺序保证不压内容。
        VoxlueColor.paper
            .overlay(GrainOverlay(isDark: colorScheme == .dark).allowsHitTesting(false))
    }
}

/// 噪点 overlay —— GeometryReader 取尺寸 → 走全局 cache 拿到一次性 rasterize
/// 好的 UIImage，再 `Image(uiImage:)` 复用。避免 SwiftUI Canvas 每次 layout 都
/// 重跑 2400 次 fill。
private struct GrainOverlay: View {
    let isDark: Bool

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: PaperGrainCache.shared.image(for: proxy.size, isDark: isDark))
                .resizable()       // 屏幕尺寸不一样的边界场景兜底
                .interpolation(.none)
        }
    }
}

/// 纸纹理图片缓存。Key 量化到整数像素 + colorScheme，避免 1pt size 抖动重生成；
/// dark/light 两套独立缓存，互不污染。
@MainActor
private final class PaperGrainCache {
    static let shared = PaperGrainCache()

    private struct Key: Hashable {
        let size: CGSize
        let isDark: Bool
    }

    private var cache: [Key: UIImage] = [:]
    private let dotCount = 2400

    func image(for size: CGSize, isDark: Bool) -> UIImage {
        let key = Key(
            size: CGSize(width: floor(size.width), height: floor(size.height)),
            isDark: isDark
        )
        if let cached = cache[key] { return cached }

        let renderer = UIGraphicsImageRenderer(size: key.size)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            // light：墨点压在纸上；dark：乳剂亮粒散在负片上 —— 一个方向的颗粒物质感。
            let dot = isDark
                ? UIColor(VoxlueColor.paperHighlightLight)
                : UIColor(VoxlueColor.inkLight)
            // 用确定性伪随机，同尺寸下纹理稳定。
            var seed: UInt64 = UInt64(key.size.width * 1019 + key.size.height * 37)
            for _ in 0..<dotCount {
                seed = seed &* 1_103_515_245 &+ 12_345
                let x = CGFloat(seed % 100_000) / 100_000.0 * key.size.width
                seed = seed &* 1_103_515_245 &+ 12_345
                let y = CGFloat(seed % 100_000) / 100_000.0 * key.size.height
                seed = seed &* 1_103_515_245 &+ 12_345
                let alpha = 0.025 + CGFloat(seed % 100) / 100.0 * 0.035
                cg.setFillColor(dot.withAlphaComponent(alpha).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: 0.6, height: 0.6))
            }
        }
        cache[key] = img
        return img
    }
}
