import XCTest

final class CoreLoopUITests: XCTestCase {
    func testPlayEnterUndoPause() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
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
    func testHintEscalatesThenExplainsAndApplies() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-easy", "-new"]
        app.launch()
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 15))
        app.buttons["hint"].tap()
        let message = app.staticTexts["hintMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        let first = message.label
        XCTAssertFalse(first.contains(" in "))            // level 1: technique only
        while app.buttons["hintMore"].exists { app.buttons["hintMore"].tap() }
        XCTAssertNotEqual(message.label, first)            // more specific now
        app.buttons["hintLesson"].tap()
        XCTAssertTrue(app.buttons["showMe"].waitForExistence(timeout: 5))
        app.buttons["showMe"].tap()
        XCTAssertTrue(app.staticTexts["explainText"].waitForExistence(timeout: 15))
        while !app.buttons["applyStep"].exists && app.buttons["explainNext"].isEnabled { app.buttons["explainNext"].tap() }
        app.buttons["applyStep"].tap()
        XCTAssertTrue(app.buttons["undo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["undo"].isEnabled)
    }
}

final class StatsUITests: XCTestCase {
    func testStatsOpens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.buttons["statsButton"].waitForExistence(timeout: 10))
        app.buttons["statsButton"].tap()
        XCTAssertTrue(app.navigationBars["Stats"].waitForExistence(timeout: 5))
    }
}

final class AccessibilityUITests: XCTestCase {
    func testBoardCellsAreReadable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-easy", "-new"]
        app.launch()
        let cell = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Row 5, column 5.'")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 15))
        cell.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Row 5, column 5.'")).firstMatch.isSelected)
    }
}

final class NewGameConfirmationUITests: XCTestCase {
    func testNewGameOverAGameInProgressAsksFirst() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-easy"]
        app.launch()
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 15))
        app.navigationBars.buttons.element(boundBy: 0).tap()   // back to home
        let row = app.buttons["tier-easy"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.2)
        app.buttons["New Game"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Start a new game?"].waitForExistence(timeout: 5))
    }
}

final class AutoCandidateUITests: XCTestCase {
    func testCheckboxShowsAndHidesCandidates() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-hard", "-new"]
        app.launch()
        let toggle = app.buttons["autoCandidates"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        let withCandidates = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Candidates'"))
        XCTAssertEqual(withCandidates.count, 0)
        toggle.tap()
        XCTAssertGreaterThan(withCandidates.count, 0)
        toggle.tap()
        XCTAssertEqual(withCandidates.count, 0)
    }
}

final class ShareUITests: XCTestCase {
    func testCompletionOffersShare() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-easy", "-new", "-nearlysolved"]
        app.launch()
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 15))
        app.buttons["hint"].tap()
        while app.buttons["hintMore"].exists { app.buttons["hintMore"].tap() }
        // The last cell's answer: enter each digit until the completion screen appears.
        for d in 1...9 where !app.buttons["completionDone"].exists {
            app.buttons["digit-\(d)"].tap()
            if !app.buttons["completionDone"].exists { app.buttons["erase"].tap() }
        }
        XCTAssertTrue(app.buttons["shareSolve"].waitForExistence(timeout: 15))
    }
}
