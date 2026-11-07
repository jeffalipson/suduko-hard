import SwiftUI
import SudokuCore

enum Theme {
    /// A colour with separate light- and dark-mode values.
    private static func adaptive(_ light: (Double, Double, Double), _ dark: (Double, Double, Double), alpha: Double = 1) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: alpha)
        })
    }

    static let accent = adaptive((0.15, 0.38, 0.85), (0.45, 0.65, 1.0))
    static let selected = adaptive((0.73, 0.84, 1.0), (0.16, 0.30, 0.55))
    static let related = adaptive((0.89, 0.93, 0.99), (0.11, 0.15, 0.24))
    static let sameDigit = adaptive((0.80, 0.88, 1.0), (0.18, 0.26, 0.42))
    static let wrong = adaptive((0.85, 0.15, 0.2), (1.0, 0.42, 0.45))
    static let wrongFill = adaptive((1.0, 0.88, 0.88), (0.38, 0.12, 0.14))
    static let given = Color.primary
    static let entry = adaptive((0.15, 0.38, 0.85), (0.50, 0.70, 1.0))
    static let note = Color.secondary
    static let cage = Color.primary.opacity(0.55)

    /// Cell colours for colouring (index 1…9); soft enough to read digits over.
    static let cellColors: [Color] = [
        adaptive((1.00, 0.55, 0.55), (0.75, 0.25, 0.28), alpha: 0.55),   // red
        adaptive((1.00, 0.70, 0.40), (0.78, 0.45, 0.15), alpha: 0.55),   // orange
        adaptive((1.00, 0.88, 0.35), (0.72, 0.62, 0.12), alpha: 0.55),   // yellow
        adaptive((0.55, 0.85, 0.50), (0.25, 0.58, 0.28), alpha: 0.55),   // green
        adaptive((0.45, 0.85, 0.85), (0.15, 0.55, 0.58), alpha: 0.55),   // teal
        adaptive((0.55, 0.72, 1.00), (0.22, 0.40, 0.80), alpha: 0.55),   // blue
        adaptive((0.70, 0.60, 1.00), (0.42, 0.32, 0.80), alpha: 0.55),   // violet
        adaptive((0.95, 0.60, 0.95), (0.65, 0.28, 0.65), alpha: 0.55),   // pink
        adaptive((0.70, 0.70, 0.72), (0.45, 0.45, 0.50), alpha: 0.65),   // grey
    ]
}

extension TechniqueID: @retroactive Identifiable {
    public var id: String { rawValue }
}
