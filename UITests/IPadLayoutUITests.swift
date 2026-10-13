import XCTest

final class IPadLayoutUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    private func launchGame() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-easy", "-new"]
        app.launch()
        XCTAssertTrue(app.otherElements["board"].firstMatch.waitForExistence(timeout: 15))
        return app
    }

    func testLandscapePutsKeypadBesideBoard() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = launchGame()
        XCUIDevice.shared.orientation = .landscapeLeft
        let board = app.otherElements["board"].firstMatch
        let five = app.buttons["digit-5"]
        XCTAssertTrue(five.waitForExistence(timeout: 5))
        sleep(1)   // let the rotation settle
        XCTAssertGreaterThan(five.frame.minX, board.frame.maxX)
        XCTAssertLessThan(app.buttons["digit-1"].frame.maxY, app.buttons["digit-4"].frame.minY)   // 3×3 grid
    }

    func testPortraitKeepsKeypadBelowBoard() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = launchGame()
        let board = app.otherElements["board"].firstMatch
        XCTAssertGreaterThan(app.buttons["digit-5"].frame.minY, board.frame.maxY)
        XCTAssertLessThanOrEqual(app.buttons["digit-5"].frame.maxX - app.buttons["digit-1"].frame.minX, 560)
    }

    func testRotationKeepsHintAndSelection() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = launchGame()
        app.buttons["hint"].tap()
        XCTAssertTrue(app.staticTexts["hintMessage"].waitForExistence(timeout: 10))
        let before = app.staticTexts["hintMessage"].label
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        XCTAssertTrue(app.staticTexts["hintMessage"].exists)
        XCTAssertEqual(app.staticTexts["hintMessage"].label, before)
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        XCTAssertTrue(app.staticTexts["hintMessage"].exists)
    }

    func testLandscapeHomeShowsAllTiers() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]   // fresh state: no game in progress, so no Continue card
        app.launch()
        XCTAssertTrue(app.buttons["tier-easy"].waitForExistence(timeout: 10))
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(app.buttons["tier-nightmare"].isHittable)
        XCTAssertLessThanOrEqual(app.buttons["tier-nightmare"].frame.maxY, window.maxY)
        XCTAssertGreaterThan(app.buttons["tier-easy"].frame.minX, window.midX - 40)   // ladder is in the right column
    }

    func testPortraitHomeIsCappedAndCentred() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        XCTAssertTrue(app.buttons["tier-easy"].waitForExistence(timeout: 10))
        let row = app.buttons["tier-easy"].frame
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(row.width, 700)
        XCTAssertEqual(row.midX, window.midX, accuracy: 2)
    }
}
