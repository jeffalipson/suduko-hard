import Testing
import SudokuGame

@Suite struct NoteGridTests {
    /// Killer: every cell uses the layout that keeps notes clear of a cage total, so they match across the board.
    @Test func killerCellsAllUseTheCompactGrid() {
        let g = NoteGrid(killer: true)
        #expect(g.top == 0.30)
        #expect(g.bottom == 0.126)
        #expect(g.side == 0.14)
        #expect(g.fontSize == 0.17)
    }

    @Test func classicKeepsTheFullSizeGrid() {
        let g = NoteGrid(killer: false)
        #expect(g.top == 0.06)
        #expect(g.bottom == 0.06)
        #expect(g.side == 0.06)
        #expect(g.fontSize == 0.22)
    }

    /// Centre of digit d's slot, as a fraction of the cell: 3 columns × 3 rows inside the insets.
    @Test func digitPositions() {
        let g = NoteGrid(killer: true)
        let one = g.center(of: 1), nine = g.center(of: 9)
        #expect(abs(one.x - (0.14 + (1 - 0.28) / 6)) < 1e-9)
        #expect(abs(one.y - (0.30 + (1 - 0.30 - 0.126) / 6)) < 1e-9)
        #expect(abs(nine.x - (1 - 0.14 - (1 - 0.28) / 6)) < 1e-9)
        #expect(abs(nine.y - (1 - 0.126 - (1 - 0.30 - 0.126) / 6)) < 1e-9)
    }
}
