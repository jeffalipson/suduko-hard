import Testing
import SudokuCore

@Suite struct BoardTests {
    @Test func parsesAndRoundTrips() throws {
        let board = try #require(Board(string: wikiPuzzle))
        #expect(board.values[0] == 5)
        #expect(board.values[2] == 0)
        #expect(board.givens[0])
        #expect(!board.givens[2])
        #expect(board.string == wikiPuzzle.replacing("0", with: "."))
        #expect(Board(string: board.string)?.values == board.values)
    }

    @Test func computesCandidatesFromGivens() throws {
        let board = try #require(Board(string: wikiPuzzle))
        #expect(board.candidates[2].digits == [1, 2, 4])
        #expect(board.candidates[0].isEmpty)
    }

    @Test(arguments: [
        String(repeating: "0", count: 80),
        String(repeating: "0", count: 82),
        "x" + String(repeating: "0", count: 80),
        "",
    ])
    func rejectsMalformedText(_ text: String) {
        #expect(Board.parse(text) == nil)
        #expect(Board(string: text) == nil)
    }

    @Test func placeUpdatesPeers() {
        var board = emptyBoard()
        board.place(5, at: 0)
        #expect(board.values[0] == 5)
        #expect(board.candidates[0].isEmpty)
        #expect(!board.candidates[1].contains(5))   // same row
        #expect(!board.candidates[9].contains(5))   // same column
        #expect(!board.candidates[20].contains(5))  // same box
        #expect(board.candidates[80].contains(5))   // unrelated
        #expect(!board.givens[0])
    }

    @Test func applyStep() {
        var board = emptyBoard()
        let step = Step(
            technique: .nakedSingle,
            placements: [CellDigit(cell: 0, digit: 1)],
            eliminations: [CellDigit(cell: 40, digit: 9)]
        )
        board.apply(step)
        #expect(board.values[0] == 1)
        #expect(!board.candidates[40].contains(9))
        #expect(!board.isSolved)
    }

    @Test func tierNamesAndOrder() {
        #expect(Tier(name: "Nightmare") == .nightmare)
        #expect(Tier(name: "bogus") == nil)
        #expect(Tier.easy < Tier.hard)
        #expect(TechniqueID.nakedPair.tier == .medium)
        #expect(TechniqueID.hiddenQuad.tier == .hard)
    }
}
