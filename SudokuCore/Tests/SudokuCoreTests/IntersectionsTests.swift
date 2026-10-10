import Testing
import SudokuCore

@Suite struct IntersectionsTests {
    @Test func pointingPairInBoxClearsRow() throws {
        var board = emptyBoard()
        // In box 0, digit 5 survives only in row 0.
        for c in Geometry.boxes[0] where Geometry.row(c) != 0 { board.eliminate(5, at: c) }
        let step = try #require(Pointing().find(in: board))
        #expect(step.technique == .pointing)
        #expect(step.patternCells == [0, 1, 2])
        #expect(Set(step.eliminations) == Set((3..<9).map { CellDigit(cell: $0, digit: 5) }))
        #expect(step.regions == [.box(0), .row(0)])
        #expect(step.digits == [5])
    }

    @Test func boxLineReductionClearsBox() throws {
        var board = emptyBoard()
        // In row 0, digit 4 survives only in box 0.
        for col in 3..<9 { board.eliminate(4, at: Geometry.cell(0, col)) }
        let step = try #require(BoxLineReduction().find(in: board))
        #expect(step.technique == .boxLineReduction)
        #expect(step.patternCells == [0, 1, 2])
        #expect(Set(step.eliminations) == Set([9, 10, 11, 18, 19, 20].map { CellDigit(cell: $0, digit: 4) }))
        #expect(step.regions == [.row(0), .box(0)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(Pointing().find(in: emptyBoard()) == nil)
        #expect(BoxLineReduction().find(in: emptyBoard()) == nil)
    }
}
