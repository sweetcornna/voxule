import Testing
import SwiftUI
@testable import VoxlueDesign

@MainActor
@Test func hexParsesPureWhite() {
    let c = Color(hex: 0xFFFFFF)
    let res = c.resolve(in: .init())
    #expect(abs(res.red - 1) < 0.01)
    #expect(abs(res.green - 1) < 0.01)
    #expect(abs(res.blue - 1) < 0.01)
}

@MainActor
@Test func hexParsesPureBlack() {
    let c = Color(hex: 0x000000)
    let res = c.resolve(in: .init())
    #expect(abs(res.red) < 0.01)
    #expect(abs(res.green) < 0.01)
    #expect(abs(res.blue) < 0.01)
}

@MainActor
@Test func hexParsesVermillionChannels() {
    // 朱红 0xC4452D → R 196 / G 69 / B 45。
    let res = Color(hex: 0xC4452D).resolve(in: .init())
    #expect(abs(res.red - 196.0 / 255.0) < 0.01)
    #expect(abs(res.green - 69.0 / 255.0) < 0.01)
    #expect(abs(res.blue - 45.0 / 255.0) < 0.01)
}
