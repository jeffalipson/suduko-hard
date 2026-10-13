import XCTest

/// Saves screenshots of the main screens in each orientation. Runs only when SCREENSHOT_DIR is set:
/// `TEST_RUNNER_SCREENSHOT_DIR=/path xcodebuild … test -only-testing:HardSudokuUITests/ScreenshotTour`
/// `TEST_RUNNER_SCREENSHOT_SET=sheets` captures every sheet instead of the main screens.
final class ScreenshotTour: XCTestCase {
    private struct Scene {
        let name: String
        let arguments: [String]
        /// Store scenes use one fixed orientation; others are captured in every orientation.
        var orientation: UIDeviceOrientation? = nil
        /// Runs after launch to reach the screen being captured.
        var prepare: (XCUIApplication) -> Void = { _ in }
    }

    private var backToHome: (XCUIApplication) -> Void { { app in
        if app.buttons["backButton"].waitForExistence(timeout: 10) { app.buttons["backButton"].tap() }
    } }

    /// App Store screenshots, in listing order (run the dark one with the simulator in dark mode).
    private var storeScenes: [Scene] {
        [
            Scene(name: "1-home", arguments: ["-uitest", "-open", "classic-diabolical", "-new"], orientation: .landscapeLeft, prepare: backToHome),
            Scene(name: "2-classic-auto", arguments: ["-uitest", "-open", "classic-fiendish", "-new", "-auto"], orientation: .landscapeLeft),
            Scene(name: "3-killer", arguments: ["-uitest", "-open", "killer-expert", "-new", "-auto"], orientation: .landscapeLeft),
            Scene(name: "4-explain", arguments: ["-uitest", "-explain", "aic"], orientation: .portrait),
            Scene(name: "5-lesson", arguments: ["-uitest", "-lesson", "xWing"], orientation: .portrait),
        ]
    }

    private var storeDarkScenes: [Scene] {
        [Scene(name: "6-home-dark", arguments: ["-uitest", "-open", "classic-diabolical", "-new"], orientation: .landscapeLeft, prepare: backToHome)]
    }

    private var mainScenes: [Scene] {
        [
            Scene(name: "home", arguments: ["-uitest"]),
            Scene(name: "home-continue", arguments: ["-uitest", "-open", "classic-diabolical", "-new"]) { app in
                if app.buttons["backButton"].waitForExistence(timeout: 10) { app.buttons["backButton"].tap() }
            },
            Scene(name: "game", arguments: ["-uitest", "-open", "killer-expert", "-new", "-auto"]),
        ]
    }

    private var sheetScenes: [Scene] {
        [
            Scene(name: "lesson", arguments: ["-uitest", "-lesson", "xWing"]),
            Scene(name: "explain", arguments: ["-uitest", "-explain", "aic"]),
            Scene(name: "stats", arguments: ["-uitest", "-stats"]),
            Scene(name: "settings", arguments: ["-uitest"]) { app in
                if app.buttons["settingsButton"].waitForExistence(timeout: 10) { app.buttons["settingsButton"].tap() }
            },
            Scene(name: "cage-helper", arguments: ["-uitest", "-open", "killer-easy", "-new"]) { app in
                let board = app.otherElements["board"].firstMatch
                guard board.waitForExistence(timeout: 10) else { return }
                board.coordinate(withNormalizedOffset: CGVector(dx: 0.5 / 9, dy: 0.5 / 9)).tap()
                // The Cage tool only appears when the cage helper setting is on (off by default).
                if app.buttons["cageHelper"].exists { app.buttons["cageHelper"].tap() }
            },
            Scene(name: "completion", arguments: ["-uitest", "-open", "classic-easy", "-new", "-nearlysolved"]) { app in
                guard app.otherElements["board"].firstMatch.waitForExistence(timeout: 10) else { return }
                // One empty cell is selected; try each digit until the puzzle completes.
                for d in 1...9 where app.buttons["undo"].exists {
                    app.buttons["digit-\(d)"].tap()
                }
            },
        ]
    }

    override func setUpWithError() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] == nil, "screenshot tour runs only with SCREENSHOT_DIR")
    }

    func testTour() throws {
        let env = ProcessInfo.processInfo.environment
        let dir = try XCTUnwrap(env["SCREENSHOT_DIR"].map(URL.init(fileURLWithPath:)), "set SCREENSHOT_DIR to run")
        let set = env["SCREENSHOT_SET"]
        let scenes = set == "sheets" ? sheetScenes : set == "store" ? storeScenes : set == "store-dark" ? storeDarkScenes : mainScenes
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let orientations: [(String, UIDeviceOrientation)] = pad ? [("portrait", .portrait), ("landscape", .landscapeLeft)] : [("portrait", .portrait)]
        let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        for (orientationName, orientation) in orientations {
            for scene in scenes where scene.orientation == nil || scene.orientation == orientation {
                XCUIDevice.shared.orientation = orientation
                let app = XCUIApplication()
                app.launchArguments = scene.arguments
                app.launch()
                sleep(4)
                scene.prepare(app)
                sleep(2)
                let file = dir.appendingPathComponent(scene.orientation == nil ? "\(device)-\(scene.name)-\(orientationName).png" : "\(scene.name).png")
                try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
                app.terminate()
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
