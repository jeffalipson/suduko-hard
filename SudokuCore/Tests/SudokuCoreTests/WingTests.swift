import Testing
import SudokuCore

@Suite struct WingTests {
    @Test func xyWing() throws {
        var b = emptyBoard()
        b.candidates[rc(4, 4)] = CandidateSet([1, 2])   // pivot
        b.candidates[rc(4, 0)] = CandidateSet([1, 3])   // pincer (row)
        b.candidates[rc(0, 4)] = CandidateSet([2, 3])   // pincer (column)
        let step = try #require(XYWing().find(in: b))
        #expect(step.technique == .xyWing)
        #expect(step.patternCells == [rc(4, 4), rc(0, 4), rc(4, 0)])
        #expect(step.eliminations == [CellDigit(cell: rc(0, 0), digit: 3)])
    }

    @Test func xyzWing() throws {
        var b = emptyBoard()
        b.candidates[rc(4, 4)] = CandidateSet([1, 2, 3])
        b.candidates[rc(4, 0)] = CandidateSet([1, 3])
        b.candidates[rc(3, 4)] = CandidateSet([2, 3])
        let step = try #require(XYZWing().find(in: b))
        #expect(step.technique == .xyzWing)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(4, 3), digit: 3), CellDigit(cell: rc(4, 5), digit: 3)])
    }

    @Test func wWing() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([4, 8])
        b.candidates[rc(5, 3)] = CandidateSet([4, 8])
        // Column 1: 4 only at (2,1), which sees (0,0), and (5,1), which sees (5,3).
        for row in 0..<9 where row != 2 && row != 5 { b.eliminate(4, at: rc(row, 1)) }
        let step = try #require(WWing().find(in: b))
        #expect(step.technique == .wWing)
        #expect(step.digits == [4, 8])
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 3), digit: 8), CellDigit(cell: rc(5, 0), digit: 8)])
        #expect(step.regions == [.column(1)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(XYWing().find(in: emptyBoard()) == nil)
        #expect(XYZWing().find(in: emptyBoard()) == nil)
        #expect(WWing().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: XYWing(), seeds: 1...30).isEmpty)
        #expect(soundnessViolations(of: XYZWing(), seeds: 1...30).isEmpty)
        #expect(soundnessViolations(of: WWing(), seeds: 1...30).isEmpty)
    }
}
