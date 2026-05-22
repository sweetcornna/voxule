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
}
