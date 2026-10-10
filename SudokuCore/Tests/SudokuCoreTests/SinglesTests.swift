import Testing
import SudokuCore

@Suite struct SinglesTests {
    @Test func fullHouseFillsLastCellOfRow() {
        var v = values(wikiSolution)
        v[0] = 0
        let step = FullHouse().find(in: Board(values: v))
        #expect(step?.technique == .fullHouse)
        #expect(step?.placements == [CellDigit(cell: 0, digit: 5)])
        #expect(step?.regions == [.row(0)])
    }

    @Test func nakedSingle() {
        var v = values(wikiSolution)
        for c in [0, 1, 9, 10] { v[c] = 0 }   // two empties per row/col: no full house
        let board = Board(values: v)
        #expect(FullHouse().find(in: board) == nil)
        let step = NakedSingle().find(in: board)
        #expect(step?.technique == .nakedSingle)
        #expect(step?.placements == [CellDigit(cell: 0, digit: 5)])
        #expect(step?.patternCells == [0])
    }

    @Test func hiddenSingleInRow() {
        var board = emptyBoard()
        for col in 0..<9 where col != 4 { board.eliminate(7, at: Geometry.cell(0, col)) }
        #expect(NakedSingle().find(in: board) == nil)
        let step = HiddenSingle().find(in: board)
        #expect(step?.technique == .hiddenSingle)
        #expect(step?.placements == [CellDigit(cell: 4, digit: 7)])
        #expect(step?.regions == [.row(0)])
        #expect(step?.digits == [7])
    }

    @Test func nothingOnEmptyBoard() {
        let board = emptyBoard()
        #expect(FullHouse().find(in: board) == nil)
        #expect(NakedSingle().find(in: board) == nil)
        #expect(HiddenSingle().find(in: board) == nil)
    }
}
