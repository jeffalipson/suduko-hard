import XCTest

/// Opening, escalating and closing a hint must not move the board or the keys.
final class HintPlacementUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testKillerHintMovesNothing() { check("killer-hard", "killer") }
    func testMathdokuHintMovesNothing() { check("mathdoku-fiendish", "mathdoku") }

    private func check(_ game: String, _ name: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", game, "-new"]
        app.launch()
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 15))
        let key = app.buttons["digit-1"].frame, hintButton = app.buttons["hint"].frame, board = app.otherElements["board"].frame

        func assertStill(_ when: String) {
            XCTAssertEqual(app.buttons["digit-1"].frame, key, "keypad moved \(when)")
            XCTAssertEqual(app.buttons["hint"].frame, hintButton, "tools moved \(when)")
            XCTAssertEqual(app.otherElements["board"].frame, board, "board moved \(when)")
        }

        app.buttons["hint"].tap()
        XCTAssertTrue(app.staticTexts["hintMessage"].waitForExistence(timeout: 10))
        assertStill("opening the hint")
        app.buttons["hint"].tap(); app.buttons["hint"].tap()   // most specific: longest text, most buttons
        assertStill("escalating the hint")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
        XCTAssertLessThanOrEqual(app.otherElements["hintBar"].frame.maxY, app.windows.firstMatch.frame.maxY, "hint runs off the screen")
        let bar = app.otherElements["hintBar"].frame
        XCTAssertGreaterThanOrEqual(bar.minY, board.maxY, "hint covers the board")
        XCTAssertTrue(bar.maxY <= hintButton.minY || bar.minY >= hintButton.maxY, "hint covers the tools")
        XCTAssertTrue(app.buttons["hint"].isHittable, "hint button covered")

        app.buttons["hintClose"].tap()
        XCTAssertFalse(app.staticTexts["hintMessage"].waitForExistence(timeout: 1))
        assertStill("closing the hint")
    }
}
