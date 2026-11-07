import SudokuCore

extension GameSession {
    /// How many colours the palette offers.
    public static let colorCount = 9

    /// The colour painted on `cell`: 0 for none, otherwise 1…colorCount.
    public func color(of cell: Int) -> Int {
        guard let c = cellColors, c.indices.contains(cell) else { return 0 }
        return c[cell]
    }

    public var hasColors: Bool { cellColors?.contains { $0 != 0 } ?? false }

    /// Paints `cell`; painting it with the colour it already has, or with 0, clears it. Undoable.
    public mutating func setColor(_ color: Int, at cell: Int) {
        guard (0...Self.colorCount).contains(color), puzzle.solution.indices.contains(cell) else { return }
        let next = self.color(of: cell) == color ? 0 : color
        guard next != self.color(of: cell) else { return }
        record()
        var c = cellColors.flatMap { $0.isEmpty ? nil : $0 } ?? Array(repeating: 0, count: puzzle.solution.count)
        c[cell] = next
        cellColors = c
    }

    /// Removes every colour. Undoable.
    public mutating func clearColors() {
        guard hasColors else { return }
        record()
        cellColors = Array(repeating: 0, count: puzzle.solution.count)
    }
}
