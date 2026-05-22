import Testing
import SwiftUI
@testable import VoxlueDesign

@Test func spacingFollowsFourPointGrid() {
    for value in VoxlueSpacing.allSteps {
        #expect(value.truncatingRemainder(dividingBy: 4) == 0, "\(value) 不在 4pt 网格")
    }
}

@Test func spacingStepsAscend() {
    let steps = VoxlueSpacing.allSteps
    #expect(steps == steps.sorted())
}

@Test func cornerRadiiAreSmall() {
    // 暗房纸感：圆角克制，不超过 16。
    #expect(VoxlueRadius.card <= 16)
    #expect(VoxlueRadius.photo <= 16)
}

@MainActor
@Test func paperShadowIsWarm() {
    // 暖色阴影：阴影色偏暖（红 > 蓝）。
    let res = VoxlueShadow.paper.color.resolve(in: .init())
    #expect(res.red >= res.blue)
}
