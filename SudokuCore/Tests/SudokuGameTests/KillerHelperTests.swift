import Testing
import SudokuCore
import SudokuGame

func killerPuzzle() -> Puzzle {
    var cages: [Cage] = []
    for r in 0..<9 {
        for k in 0..<3 {
            let cells = (0..<3).map { r * 9 + k * 3 + $0 }
            cages.append(Cage(cells: cells, sum: cells.map { wikiAnswer[$0] }.reduce(0, +)))
        }
    }
    return Puzzle(id: "k", mode: .killer, givens: Array(repeating: 0, count: 81), cages: cages,
                  solution: wikiAnswer, grade: Grade(tier: .medium, score: 1), techniquesRequired: [])
}

@Suite struct KillerHelperTests {
    @Test func remainingSumTracksEntries() {
        var g = GameSession(puzzle: killerPuzzle())
        #expect(g.cageIndex(of: 1) == 0)
        #expect(g.remainingSum(ofCage: 0) == 12)   // 5 + 3 + 4
        g.selected = 0
        g.input(5, settings: GameSettings())
        #expect(g.remainingSum(ofCage: 0) == 7)
    }

    @Test func combinationsStrikeImpossibleOnes() {
        var g = GameSession(puzzle: killerPuzzle())
        let all = g.combinations(ofCage: 0).map(\.digits)
        #expect(all == [[1, 2, 9], [1, 3, 8], [1, 4, 7], [1, 5, 6], [2, 3, 7], [2, 4, 6], [3, 4, 5]])
        g.selected = 0
        g.input(5, settings: GameSettings())
        let possible = g.combinations(ofCage: 0).filter(\.possible).map(\.digits)
        #expect(possible == [[1, 5, 6], [3, 4, 5]])
    }

    @Test func helperIsLoggedOnce() {
        var g = GameSession(puzzle: killerPuzzle())
        g.useCageHelper()
        g.useCageHelper()
        #expect(g.log.cageHelper == 1)
    }
}
