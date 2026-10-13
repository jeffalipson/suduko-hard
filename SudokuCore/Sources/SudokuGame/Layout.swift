/// How the game screen arranges the board and controls in the space it gets.
public enum GameLayout: Equatable, Sendable {
    /// Board above the controls (portrait, narrow windows, every iPhone).
    case stacked
    /// Board on the left at `board` points square, controls in a column on the right.
    case sideBySide(board: Double)

    /// Width of the controls column beside the board.
    public static let columnWidth: Double = 340
    /// Smallest board worth putting beside the controls (about an iPhone board).
    static let minimumBoard: Double = 360
    /// Height the controls column needs.
    static let minimumHeight: Double = 600

    /// `width` × `height` is the space below the navigation bar.
    public static func choose(width: Double, height: Double) -> GameLayout {
        guard width >= height, height >= minimumHeight else { return .stacked }
        // 16 pt padding top and bottom; 16 pt left, between and right.
        let board = min(height - 32, width - columnWidth - 48)
        return board >= minimumBoard ? .sideBySide(board: board) : .stacked
    }
}

/// How the home screen arranges its sections.
public enum HomeLayout: Equatable, Sendable {
    case singleColumn, twoColumns

    public static func choose(width: Double, height: Double) -> HomeLayout {
        width > height && width >= 900 ? .twoColumns : .singleColumn
    }
}
