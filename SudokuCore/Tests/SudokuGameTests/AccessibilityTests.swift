import Testing
import SudokuCore
import SudokuGame

@Suite struct AccessibilityTests {
    @Test func givenEntryAndNotes() {
        var g = GameSession(puzzle: classicPuzzle())
        #expect(g.spokenDescription(of: 0) == "Row 1, column 1. 5, given.")
        g.selected = 2
        g.input(4, settings: GameSettings())
        #expect(g.spokenDescription(of: 2) == "Row 1, column 3. 4.")
        g.selected = 3
        g.inputMode = .candidate
        g.input(6, settings: GameSettings())
        g.input(2, settings: GameSettings())
        #expect(g.spokenDescription(of: 3) == "Row 1, column 4. Empty. Candidates 2, 6.")
        #expect(g.spokenDescription(of: 5) == "Row 1, column 6. Empty.")
    }

    @Test func killerCellsNameTheirCage() {
        let g = GameSession(puzzle: killerPuzzle())
        #expect(g.spokenDescription(of: 1) == "Row 1, column 2. Empty. Cage of 3 cells, total 12.")
    }
}
