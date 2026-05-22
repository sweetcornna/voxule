import Testing
import SwiftUI
@testable import VoxlueDesign

@Test func paletteHasEightColors() {
    #expect(VoxlueColor.palette.count == 8)
}

@MainActor
@Test func paperBaseIsWarmCream() {
    // 纸基必须偏暖：红通道 > 蓝通道（不是冷蓝屏幕白）。
    let res = VoxlueColor.paper.resolve(in: .init())
    #expect(res.red > res.blue)
}

@MainActor
@Test func vermillionIsWarmAccent() {
    // 朱红必须偏暖：红通道明显高于蓝通道。
    let res = VoxlueColor.vermillion.resolve(in: .init())
    #expect(res.red - res.blue > 0.4)
}

@MainActor
@Test func inkIsDarkerThanGraphite() {
    let ink = VoxlueColor.ink.resolve(in: .init())
    let graphite = VoxlueColor.graphite.resolve(in: .init())
    #expect(ink.red < graphite.red)
}
