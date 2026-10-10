import SwiftUI

enum Theme {
    static let accent = Color(red: 0.15, green: 0.38, blue: 0.85)
    static let selected = Color(red: 0.73, green: 0.84, blue: 1.0)
    static let related = Color(red: 0.89, green: 0.93, blue: 0.99)
    static let sameDigit = Color(red: 0.80, green: 0.88, blue: 1.0)
    static let wrong = Color(red: 0.85, green: 0.15, blue: 0.2)
    static let wrongFill = Color(red: 1.0, green: 0.88, blue: 0.88)
    static let given = Color.primary
    static let entry = Color(red: 0.15, green: 0.38, blue: 0.85)
    static let note = Color.secondary
    static let cage = Color.primary.opacity(0.55)
}
