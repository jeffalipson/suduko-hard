import XCTest

final class MathdokuUITests: XCTestCase {
    func testHomeShowsMathdokuLadderAndOpensAGame() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.buttons["Mathdoku"].waitForExistence(timeout: 10))
        app.buttons["Mathdoku"].tap()
        XCTAssertTrue(app.staticTexts["5×5"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["9×9"].exists)
        app.buttons["tier-easy"].tap()
        let board = app.otherElements["board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["digit-5"].exists)
        XCTAssertFalse(app.buttons["digit-6"].exists)          // 5×5: digits 1–5 only
        // Enter a digit in the first cell that takes one.
        for i in 0..<25 {
            board.coordinate(withNormalizedOffset: CGVector(dx: (Double(i % 5) + 0.5) / 5, dy: (Double(i / 5) + 0.5) / 5)).tap()
            app.buttons["digit-1"].tap()
            if app.buttons["undo"].isEnabled { break }
        }
        XCTAssertTrue(app.buttons["undo"].isEnabled)
        app.buttons["backButton"].tap()
        XCTAssertTrue(app.buttons["continueCard"].waitForExistence(timeout: 5))
    }

    func testHintLessonShowMe() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "mathdoku-easy", "-new"]
        app.launch()
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 15))
        app.buttons["hint"].tap()
        let message = app.staticTexts["hintMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        let first = message.label
        while app.buttons["hintMore"].exists { app.buttons["hintMore"].tap() }
        XCTAssertNotEqual(message.label, first)
        app.buttons["hintLesson"].tap()
        XCTAssertTrue(app.buttons["showMe"].waitForExistence(timeout: 5))
        app.buttons["showMe"].tap()
        XCTAssertTrue(app.buttons["undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["undo"].isEnabled)
    }

    func testColourACell() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "mathdoku-medium", "-new"]
        app.launch()
        let board = app.otherElements["board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        app.buttons["colorMode"].tap()
        app.buttons["color-2"].tap()
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5 / 6, dy: 0.5 / 6)).tap()
        let painted = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Colour 2'"))
        XCTAssertEqual(painted.count, 1)
    }

    func testFinishingShowsCompletion() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "mathdoku-easy", "-new", "-nearlysolved"]
        app.launch()
        XCTAssertTrue(app.buttons["gameMenu"].waitForExistence(timeout: 15))
        app.buttons["gameMenu"].tap()
        app.buttons["Reveal Cell"].tap()
        XCTAssertTrue(app.buttons["completionDone"].waitForExistence(timeout: 10))
        app.buttons["completionDone"].tap()
        XCTAssertTrue(app.buttons["tier-easy"].waitForExistence(timeout: 10))
    }
}

final class MathdokuFactorUITests: XCTestCase {
    /// Holding a × cage shows its prime factors; the next tap puts them away without selecting anything.
    func testLongPressShowsPrimeFactors() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "mathdoku-fiendish", "-new"]
        app.launch()
        let board = app.otherElements["board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        // Find a cell in a × cage by its spoken description, and hold it.
        let matches = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '×,'"))
        let cell = matches.element(boundBy: min(5, max(0, matches.count - 1)))
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.press(forDuration: 0.9)
        let bubble = app.staticTexts["factorBubble"]
        XCTAssertTrue(bubble.waitForExistence(timeout: 3))
        XCTAssertTrue(bubble.label.contains("="))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "factor-bubble"
        shot.lifetime = .keepAlways
        add(shot)
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(bubble.waitForExistence(timeout: 1))
    }
}
