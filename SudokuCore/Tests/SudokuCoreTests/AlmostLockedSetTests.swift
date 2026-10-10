import Testing
import SudokuCore

@Suite struct AlmostLockedSetTests {
    @Test func alsXZ() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([1, 2])   // ALS A (one cell)
        b.candidates[rc(4, 0)] = CandidateSet([1, 3])   // ALS B (row 4, two cells)
        b.candidates[rc(4, 1)] = CandidateSet([2, 3])
        let step = try #require(ALSXZ().find(in: b))
        #expect(step.technique == .alsXZ)
        let expected = [rc(0, 1), rc(1, 1), rc(2, 1), rc(3, 0), rc(5, 0)].map { CellDigit(cell: $0, digit: 2) }
        #expect(Set(step.eliminations) == Set(expected))
    }

    @Test func nothingOnEmptyBoard() {
        #expect(ALSXZ().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: ALSXZ(), seeds: 1...20).isEmpty)
    }
}
