import XCTest

/// Saves screenshots of the main screens in each orientation. Runs only when SCREENSHOT_DIR is set:
/// `TEST_RUNNER_SCREENSHOT_DIR=/path xcodebuild … test -only-testing:HardSudokuUITests/ScreenshotTour`
final class ScreenshotTour: XCTestCase {
    func testTour() throws {
        let dir = try XCTUnwrap(ProcessInfo.processInfo.environment["SCREENSHOT_DIR"].map(URL.init(fileURLWithPath:)),
                                "set SCREENSHOT_DIR to run")
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let orientations: [(String, UIDeviceOrientation)] = pad ? [("portrait", .portrait), ("landscape", .landscapeLeft)] : [("portrait", .portrait)]
        // (name, launch arguments, tap Back after launch to land on home with a game in progress)
        let scenes: [(String, [String], Bool)] = [
            ("home", ["-uitest"], false),
            ("home-continue", ["-uitest", "-open", "classic-diabolical", "-new"], true),
            ("game", ["-uitest", "-open", "killer-expert", "-new", "-auto"], false),
        ]
        let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        for (orientationName, orientation) in orientations {
            for (scene, args, back) in scenes {
                XCUIDevice.shared.orientation = orientation
                let app = XCUIApplication()
                app.launchArguments = args
                app.launch()
                sleep(4)
                if back, app.buttons["backButton"].waitForExistence(timeout: 10) {
                    app.buttons["backButton"].tap()
                    sleep(2)
                }
                let file = dir.appendingPathComponent("\(device)-\(scene)-\(orientationName).png")
                try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
                app.terminate()
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }

    override func setUpWithError() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] == nil, "screenshot tour runs only with SCREENSHOT_DIR")
    }
}
