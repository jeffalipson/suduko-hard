import Testing
import SudokuCore

@Suite struct SueDeCoqTests {
    @Test func sueDeCoq() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([1, 2, 3, 4])
        b.candidates[rc(0, 1)] = CandidateSet([1, 2, 3, 4])
        b.candidates[rc(0, 5)] = CandidateSet([1, 2])   // line cell
        b.candidates[rc(2, 2)] = CandidateSet([3, 4])   // box cell
        let step = try #require(SueDeCoq().find(in: b))
        #expect(step.technique == .sueDeCoq)
        var expected = Set<CellDigit>()
        for c in [rc(0, 3), rc(0, 4), rc(0, 6), rc(0, 7), rc(0, 8)] { for d in [1, 2] { expected.insert(CellDigit(cell: c, digit: d)) } }
        for c in [rc(1, 0), rc(1, 1), rc(1, 2), rc(2, 0), rc(2, 1)] { for d in [3, 4] { expected.insert(CellDigit(cell: c, digit: d)) } }
        for d in 1...4 { expected.insert(CellDigit(cell: rc(0, 2), digit: d)) }
        #expect(Set(step.eliminations) == expected)
    }

    @Test func nothingOnEmptyBoard() {
        #expect(SueDeCoq().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: SueDeCoq(), seeds: 1...20).isEmpty)
    }
}
