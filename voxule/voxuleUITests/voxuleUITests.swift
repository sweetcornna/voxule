//
//  voxuleUITests.swift
//  voxuleUITests
//
//  Created by 喻永昌 on 2026/5/22.
//

import XCTest

final class voxuleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    /// 端到端验证 v1 主循环：首页冲一张 → 装裱埋下 → 样片墙列出 → 进详情回放。
    /// 用 -uiTestFakeAudio 注入假音频服务，避开真麦克风。
    @MainActor
    func testRecordBuryPlayMainLoop() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFakeAudio"]
        app.launch()

        // 切到样片墙取基线行数（先量再录，免得录完才发现起点不对）。
        app.tabBars.buttons["样片墙"].tap()
        usleep(500_000)
        let countBefore = app.cells.count

        // 回首页点巨大 mic。
        app.tabBars.buttons["首页"].tap()
        usleep(500_000)
        app.buttons["冲一张"].tap()
        let recordButton = app.buttons["开始冲洗"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5), "未进入冲洗台")
        recordButton.tap()
        let stopButton = app.buttons["停止"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5), "录音未开始")
        stopButton.tap()

        // 装裱 → 埋下。埋下 dismiss 后回到首页（不是样片墙），需手动切去样片墙看新行。
        let buryButton = app.buttons["埋下"]
        XCTAssertTrue(buryButton.waitForExistence(timeout: 5), "未进入装裱视图")
        buryButton.tap()
        usleep(800_000)
        app.tabBars.buttons["样片墙"].tap()

        XCTAssertTrue(
            waitForCellCount(app, equals: countBefore + 1, timeout: 5),
            "埋下后样片墙未新增一行"
        )

        // 进详情 → 播放。
        app.cells.firstMatch.tap()
        let playButton = app.buttons["播放"]
        XCTAssertTrue(playButton.waitForExistence(timeout: 5), "未进入胶囊详情")
        playButton.tap()
        XCTAssertTrue(
            app.buttons["暂停"].waitForExistence(timeout: 5),
            "点播放后未切到可暂停状态"
        )
    }

    /// 轮询等待列表行数达到目标值，吸收 @Query 的异步刷新延迟。
    @MainActor
    private func waitForCellCount(
        _ app: XCUIApplication,
        equals target: Int,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.cells.count == target { return true }
            usleep(200_000)
        }
        return app.cells.count == target
    }
}
