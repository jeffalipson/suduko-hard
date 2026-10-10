import XCTest

final class CoreLoopUITests: XCTestCase {
    func testPlayEnterUndoPause() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["tier-easy"].waitForExistence(timeout: 10))
        app.buttons["tier-easy"].tap()
        let board = app.otherElements["board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        // Tap every cell in the first row until one accepts a digit (givens don't).
        for col in 0..<9 {
            board.coordinate(withNormalizedOffset: CGVector(dx: (Double(col) + 0.5) / 9, dy: 0.5 / 9)).tap()
            app.buttons["digit-1"].tap()
            if app.buttons["undo"].isEnabled { break }
        }
        XCTAssertTrue(app.buttons["undo"].isEnabled)
        app.buttons["undo"].tap()
        XCTAssertTrue(app.buttons["redo"].isEnabled)
        app.segmentedControls["inputMode"].buttons["Candidate"].tap()
        app.buttons["pauseButton"].tap()
        XCTAssertTrue(app.buttons["resumeButton"].waitForExistence(timeout: 5))
        app.buttons["resumeButton"].tap()
    }
}

final class HintUITests: XCTestCase {
    func testHintNudgeSpotlightLessonShowMe() {
        let app = XCUIApplication()
        app.launchArguments = ["-open", "classic-easy", "-new"]
        app.launch()
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 15))
        app.buttons["hint"].tap()
        XCTAssertTrue(app.buttons["hintLesson"].waitForExistence(timeout: 10))
        if app.buttons["hintSpotlight"].exists { app.buttons["hintSpotlight"].tap() }
        app.buttons["hintLesson"].tap()
        XCTAssertTrue(app.buttons["showMe"].waitForExistence(timeout: 5))
        app.buttons["showMe"].tap()
        XCTAssertTrue(app.buttons["undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["undo"].isEnabled)
    }
}
