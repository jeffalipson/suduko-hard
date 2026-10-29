/// Where pencil marks sit inside a cell, as fractions of the cell's side.
public struct NoteGrid: Equatable, Sendable {
    /// Space above the first row, below the last row, and at each side.
    public let top, bottom, side: Double
    /// Font size of each mark.
    public let fontSize: Double

    /// Killer cells all use the compact grid that clears a cage total, so marks match across the board.
    public init(killer: Bool) {
        if killer {
            (top, bottom, side, fontSize) = (0.30, 0.126, 0.14, 0.17)
        } else {
            (top, bottom, side, fontSize) = (0.06, 0.06, 0.06, 0.22)
        }
    }

    /// Centre of digit `d`'s slot (1–9, laid out 1 2 3 / 4 5 6 / 7 8 9).
    public func center(of d: Int) -> (x: Double, y: Double) {
        let col = Double((d - 1) % 3), row = Double((d - 1) / 3)
        let w = (1 - 2 * side) / 3, h = (1 - top - bottom) / 3
        return (side + w * (col + 0.5), top + h * (row + 0.5))
    }
}
