import XCTest

final class KeyboardUITests: XCTestCase {
    private func launchGame() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-easy", "-new"]
        app.launch()
        XCTAssertTrue(app.otherElements["board"].firstMatch.waitForExistence(timeout: 15))
        return app
    }

    /// Arrows walk the first row until a digit sticks (givens refuse digits), then Delete, ⌘Z and Space.
    func testPlayWithKeyboardOnly() {
        let app = launchGame()
        app.typeKey(.rightArrow, modifierFlags: [])          // selects r1c1
        for _ in 0..<9 {
            app.typeKey("1", modifierFlags: [])
            if app.buttons["undo"].isEnabled { break }
            app.typeKey(.rightArrow, modifierFlags: [])
        }
        XCTAssertTrue(app.buttons["undo"].isEnabled)
        app.typeKey(.delete, modifierFlags: [])              // erase
        app.typeKey("z", modifierFlags: .command)            // undo the erase
        app.typeKey("z", modifierFlags: [.command, .shift])  // redo it
        app.typeKey(.space, modifierFlags: [])
        XCTAssertEqual(app.segmentedControls["inputMode"].buttons["Candidate"].isSelected, true)
    }

    func testKeysIgnoredWhilePaused() {
        let app = launchGame()
        app.typeKey(.rightArrow, modifierFlags: [])
        app.buttons["pauseButton"].tap()
        XCTAssertTrue(app.buttons["resumeButton"].waitForExistence(timeout: 5))
        for d in 1...9 { app.typeKey("\(d)", modifierFlags: []) }
        app.buttons["resumeButton"].tap()
        XCTAssertFalse(app.buttons["undo"].isEnabled)
    }

    func testKeysWorkAfterSheetCloses() {
        let app = launchGame()
        app.buttons["hint"].tap()
        XCTAssertTrue(app.staticTexts["hintMessage"].waitForExistence(timeout: 10))
        while app.buttons["hintMore"].exists { app.buttons["hintMore"].tap() }
        app.buttons["hintLesson"].tap()
        XCTAssertTrue(app.buttons["showMe"].waitForExistence(timeout: 5))
        app.swipeDown(velocity: .fast)                        // dismiss the lesson sheet
        XCTAssertTrue(app.otherElements["board"].firstMatch.waitForExistence(timeout: 5))
        app.typeKey(.space, modifierFlags: [])
        XCTAssertEqual(app.segmentedControls["inputMode"].buttons["Candidate"].isSelected, true)
    }
}
