import XCTest

/// Saves screenshots of the main screens in each orientation. Runs only when SCREENSHOT_DIR is set:
/// `TEST_RUNNER_SCREENSHOT_DIR=/path xcodebuild … test -only-testing:HardSudokuUITests/ScreenshotTour`
final class ScreenshotTour: XCTestCase {
    func testTour() throws {
        let dir = try XCTUnwrap(ProcessInfo.processInfo.environment["SCREENSHOT_DIR"].map(URL.init(fileURLWithPath:)),
                                "set SCREENSHOT_DIR to run")
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let orientations: [(String, UIDeviceOrientation)] = pad ? [("portrait", .portrait), ("landscape", .landscapeLeft)] : [("portrait", .portrait)]
        let scenes: [(String, [String])] = [
            ("home", ["-uitest"]),
            ("game", ["-uitest", "-open", "killer-expert", "-new", "-auto"]),
        ]
        let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        for (orientationName, orientation) in orientations {
            for (scene, args) in scenes {
                XCUIDevice.shared.orientation = orientation
                let app = XCUIApplication()
                app.launchArguments = args
                app.launch()
                sleep(4)
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
