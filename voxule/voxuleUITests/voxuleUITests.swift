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

    /// 端到端验证数据层：通过 App UI 写入一枚胶囊，并确认重启 App 后它仍在（持久化）。
    @MainActor
    func testAddCapsulePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let addButton = app.buttons["加一枚样本"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "找不到「加一枚样本」按钮")

        let countBefore = app.cells.count
        addButton.tap()

        XCTAssertTrue(
            waitForCellCount(app, equals: countBefore + 1, timeout: 5),
            "点按后胶囊未写入列表"
        )

        // 重启 App —— 列表行数应保持不变，证明已持久化。
        app.terminate()
        app.launch()

        XCTAssertTrue(
            waitForCellCount(app, equals: countBefore + 1, timeout: 5),
            "重启后胶囊未持久化"
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
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
