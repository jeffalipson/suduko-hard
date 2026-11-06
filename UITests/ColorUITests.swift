import XCTest

final class ColorUITests: XCTestCase {
    func testPaintAndClearACell() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-easy", "-new"]
        app.launch()
        let board = app.otherElements["board"].firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        app.buttons["colorMode"].tap()
        XCTAssertTrue(app.buttons["color-3"].waitForExistence(timeout: 5))
        app.buttons["color-3"].tap()
        board.coordinate(withNormalizedOffset: CGVector(dx: 4.5 / 9, dy: 4.5 / 9)).tap()   // centre cell
        let painted = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Colour 3'"))
        XCTAssertEqual(painted.count, 1)
        app.buttons["clearColor"].tap()
        XCTAssertEqual(painted.count, 0)
        app.buttons["colorMode"].tap()                      // back to numbers
        XCTAssertTrue(app.buttons["digit-1"].waitForExistence(timeout: 5))
    }
}
