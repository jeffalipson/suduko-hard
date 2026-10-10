import Testing
import SudokuCore

@Suite struct SubsetsTests {
    @Test func nakedPair() throws {
        var board = emptyBoard()
        board.candidates[0] = CandidateSet([1, 2])
        board.candidates[1] = CandidateSet([1, 2])
        let step = try #require(NakedSubset(size: 2).find(in: board))
        #expect(step.technique == .nakedPair)
        #expect(step.patternCells == [0, 1])
        #expect(step.digits == [1, 2])
        #expect(step.regions == [.row(0)])
        let expected = (2..<9).flatMap { c in [CellDigit(cell: c, digit: 1), CellDigit(cell: c, digit: 2)] }
        #expect(Set(step.eliminations) == Set(expected))
    }

    @Test func nakedTriple() throws {
        var board = emptyBoard()
        board.candidates[0] = CandidateSet([1, 2])
        board.candidates[1] = CandidateSet([2, 3])
        board.candidates[2] = CandidateSet([1, 3])
        #expect(NakedSubset(size: 2).find(in: board) == nil)
        let step = try #require(NakedSubset(size: 3).find(in: board))
        #expect(step.technique == .nakedTriple)
        #expect(step.patternCells == [0, 1, 2])
        #expect(step.eliminations.count == 18)
        #expect(step.regions == [.row(0)])
    }

    @Test func hiddenPair() throws {
        var board = emptyBoard()
        for col in 2..<9 {
            board.eliminate(6, at: col)
            board.eliminate(7, at: col)
        }
        let step = try #require(HiddenSubset(size: 2).find(in: board))
        #expect(step.technique == .hiddenPair)
        #expect(step.patternCells == [0, 1])
        #expect(step.digits == [6, 7])
        let others = [1, 2, 3, 4, 5, 8, 9]
        let expected = [0, 1].flatMap { c in others.map { CellDigit(cell: c, digit: $0) } }
        #expect(Set(step.eliminations) == Set(expected))
    }

    @Test func hiddenTriple() throws {
        var board = emptyBoard()
        for col in 3..<9 {
            for d in [4, 5, 6] { board.eliminate(d, at: col) }
        }
        #expect(HiddenSubset(size: 2).find(in: board) == nil)
        let step = try #require(HiddenSubset(size: 3).find(in: board))
        #expect(step.technique == .hiddenTriple)
        #expect(step.patternCells == [0, 1, 2])
        #expect(step.digits == [4, 5, 6])
        #expect(step.eliminations.count == 18)
    }

    @Test func idsBySize() {
        #expect(NakedSubset(size: 4).id == .nakedQuad)
        #expect(HiddenSubset(size: 4).id == .hiddenQuad)
    }

    @Test func nothingOnEmptyBoard() {
        for size in 2...4 {
            #expect(NakedSubset(size: size).find(in: emptyBoard()) == nil)
            #expect(HiddenSubset(size: size).find(in: emptyBoard()) == nil)
        }
    }
}
