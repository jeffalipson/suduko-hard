/// How the game screen arranges the board and controls in the space it gets.
public enum GameLayout: Equatable, Sendable {
    /// Board above the controls (portrait, narrow windows, every iPhone).
    case stacked
    /// Board on the left at `board` points square, controls in a column on the right.
    case sideBySide(board: Double)

    /// Width of the controls column beside the board.
    public static let columnWidth: Double = 340
    /// Smallest board worth putting beside the controls.
    static let minimumBoard: Double = 240
    /// Height the stacked controls (switch, two rows of keys, tools) take below the board.
    static let stackedControlsHeight: Double = 300

    /// `width` × `height` is the space below the navigation bar. Picks whichever arrangement
    /// gives the bigger board; the side column scrolls when the window is short.
    public static func choose(width: Double, height: Double) -> GameLayout {
        guard width >= height else { return .stacked }
        let stacked = min(width - 16, height - stackedControlsHeight)
        // 16 pt padding top and bottom; 16 pt left, between and right.
        let side = min(height - 32, width - columnWidth - 48)
        return side > stacked && side >= minimumBoard ? .sideBySide(board: side) : .stacked
    }
}

/// How the home screen arranges its sections.
public enum HomeLayout: Equatable, Sendable {
    case singleColumn, twoColumns

    public static func choose(width: Double, height: Double) -> HomeLayout {
        width > height && width >= 900 ? .twoColumns : .singleColumn
    }
}
