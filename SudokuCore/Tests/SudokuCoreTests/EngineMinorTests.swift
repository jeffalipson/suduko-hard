import Testing
import SudokuCore

@Suite struct EngineMinorTests {
    @Test func parseAcceptsOnlyASCIIDigits() {
        #expect(Board.parse("٣" + String(repeating: "0", count: 80)) == nil)
        #expect(Board.parse("③" + String(repeating: "0", count: 80)) == nil)
        #expect(Board.parse("3" + String(repeating: ".", count: 80)) != nil)
    }

    @Test func finnedXWingWithThreeFins() throws {
        // Rows 1 and 4 on columns 2/6; row 4 has fins at columns 7 and 8 (box 5), plus row 1 clean.
        let b = board(digit: 2, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(4, 7), rc(4, 8), rc(3, 6), rc(5, 7)])
        let step = try #require(FinnedFish(size: 2).find(in: b))
        #expect(step.eliminations.contains(CellDigit(cell: rc(3, 6), digit: 2)))
    }

    @Test func coloringSkipsOddCycles() {
        // A 5-cycle of strong links on digit 1 (only possible on an inconsistent board).
        let b = board(digit: 1, onlyIn: [rc(0, 0), rc(0, 4), rc(3, 4), rc(5, 3), rc(5, 0)])
        _ = SimpleColoring().find(in: b)   // must not crash or loop
    }

    @Test func emptyCageWithASumHasNoSolution() {
        #expect(BruteForceSolver.countSolutions(Array(repeating: 0, count: 81), cages: [Cage(cells: [], sum: 5)]) == 0)
    }

    @Test func forcingChainWithOneSurvivingBranchPlacesThatBranch() throws {
        // Cell 0 with candidates {5, 9} where 9 contradicts at once (9 is the only spot for 9 in column 1… simulated):
        var v = values(wikiSolution)
        v[0] = 0; v[1] = 0; v[9] = 0; v[10] = 0
        var b = Board(values: v)
        b.candidates[0] = CandidateSet([5, 6])   // 6 would duplicate row 1's 6? no — 6 sits in column 1 at row 2
        let step = try #require(ForcingChain.cell.find(in: b))
        #expect(step.placements == [CellDigit(cell: 0, digit: 5)])
    }
}
