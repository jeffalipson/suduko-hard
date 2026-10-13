import XCTest

final class DynamicTypeUITests: XCTestCase {
    private func undoIconHeight(contentSize: String?) -> CGFloat {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest", "-open", "classic-easy", "-new"]
        if let contentSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
        app.launch()
        let icon = app.buttons["undo"].images.firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 15))
        let height = icon.frame.height
        app.terminate()
        return height
    }

    /// The tool icons follow the player's text size, as they did in 1.0.
    func testToolIconsFollowTextSize() {
        let regular = undoIconHeight(contentSize: nil)
        let large = undoIconHeight(contentSize: "UICTContentSizeCategoryAccessibilityL")
        XCTAssertGreaterThan(large, regular * 1.3)
    }
}
