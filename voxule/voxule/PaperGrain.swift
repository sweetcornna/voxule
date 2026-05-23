import SwiftUI
import VoxlueDesign

/// 纸纹理叠加 —— 在 `.paper` 背景上撒一层极淡的暖色噪点，给暗房纸感物质性。
/// 用 SwiftUI Canvas + 确定性伪随机；同尺寸下每次重绘点位一致，
/// 不会跳变。`drawingGroup()` 把噪点 rasterize 一次，避免 60fps 重算。
struct PaperGrainBackground: View {
    /// 噪点密度 —— 每屏约 2400 点已足够「有纹理无干扰」。
    private let count = 2400

    var body: some View {
        Canvas { context, size in
            // 用 size 做 seed —— 同屏尺寸下纹理稳定。
            var seed: UInt64 = UInt64(size.width.rounded() * 1019 + size.height.rounded() * 37)
            for _ in 0..<count {
                seed = seed &* 1_103_515_245 &+ 12_345
                let x = Double(seed % 100_000) / 100_000.0 * size.width
                seed = seed &* 1_103_515_245 &+ 12_345
                let y = Double(seed % 100_000) / 100_000.0 * size.height
                seed = seed &* 1_103_515_245 &+ 12_345
                let alpha = 0.025 + Double(seed % 100) / 100.0 * 0.035
                let path = Path(ellipseIn: CGRect(x: x, y: y, width: 0.6, height: 0.6))
                context.fill(path, with: .color(VoxlueColor.ink.opacity(alpha)))
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

extension View {
    /// 给 .paper 背景叠一层纸纹理。
    /// 用法：`Color.paper.ignoresSafeArea().paperGrain()` 或
    /// `.background(VoxlueColor.paper.ignoresSafeArea())` 后链上 `.paperGrain()`。
    func paperGrain() -> some View {
        overlay(PaperGrainBackground().ignoresSafeArea().allowsHitTesting(false))
    }
}
