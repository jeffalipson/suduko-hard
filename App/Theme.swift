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
}

extension TechniqueID: @retroactive Identifiable {
    public var id: String { rawValue }
}
