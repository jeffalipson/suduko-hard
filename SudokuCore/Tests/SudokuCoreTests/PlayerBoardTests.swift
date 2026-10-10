import Testing
import SudokuCore

@Suite struct PlayerBoardTests {
    @Test func fullHouseUsesTheMissingDigitNotStaleCandidates() {
        var v = values(wikiSolution)
        v[0] = 0
        var b = Board(values: v)
        b.candidates[0] = CandidateSet([9])          // stale/wrong mark
        #expect(FullHouse().find(in: b)?.placements == [CellDigit(cell: 0, digit: 5)])
    }

    @Test func hiddenTechniquesIgnorePlacedDigits() {
        var b = emptyBoard()
        b.place(4, at: rc(0, 0))
        b.candidates[rc(0, 5)].insert(4)             // stale 4 elsewhere in row 0
        #expect(HiddenSingle().find(in: b).map { $0.digits != [4] || $0.regions != [.row(0)] } ?? true)
        b.candidates[rc(0, 6)].insert(4)
        #expect(HiddenSubset(size: 2).find(in: b).map { !$0.digits.contains(4) } ?? true)
        #expect(Pointing().find(in: b).map { $0.digits != [4] } ?? true)
        #expect(BoxLineReduction().find(in: b).map { $0.digits != [4] } ?? true)
    }

    @Test func fullGridWithDuplicatesIsNotSolved() {
        var v = values(wikiSolution)
        v[0] = 3   // duplicate 3 in row 0
        #expect(!LogicalSolver.classic.solve(Board(values: v)).solved)
    }
}
