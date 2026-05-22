import SwiftUI

public extension Color {
    /// 用 0xRRGGBB 整数字面量构造颜色（sRGB）。
    /// 例：`Color(hex: 0xC4452D)`。
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
