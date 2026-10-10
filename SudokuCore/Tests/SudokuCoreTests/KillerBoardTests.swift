import Testing
import SudokuCore

@Suite struct KillerBoardTests {
    @Test func cageMatesLoseTheDigit() {
        var v = Array(repeating: 0, count: 81)
        v[0] = 5
        let board = Board(values: v, cages: [Cage(cells: [0, 40], sum: 10)])
        #expect(board.cageOf[40] == 0)
        #expect(board.cageOf[1] == -1)
        #expect(board.cageMates(of: 40) == [0])
        #expect(!board.candidates[40].contains(5))   // cage mate, not a peer
        var b = Board(values: Array(repeating: 0, count: 81), cages: [Cage(cells: [1, 50], sum: 9)])
        b.place(3, at: 1)
        #expect(!b.candidates[50].contains(3))
    }

    @Test func bruteForceRespectsCages() {
        let solution = values(wikiSolution)
        let cages = dominoCages(for: solution)
        #expect(BruteForceSolver.countSolutions(values(wikiPuzzle), cages: cages) == 1)
        #expect(BruteForceSolver.solve(values(wikiPuzzle), cages: cages) == solution)
        var wrong = cages
        wrong[0] = Cage(cells: wrong[0].cells, sum: wrong[0].sum + 1)
        #expect(BruteForceSolver.countSolutions(values(wikiPuzzle), cages: wrong) == 0)
    }

    @Test func malformedCagesHaveNoSolution() {
        let empty = Array(repeating: 0, count: 81)
        #expect(BruteForceSolver.countSolutions(empty, cages: [Cage(cells: [0, 1], sum: 3), Cage(cells: [1, 2], sum: 3)]) == 0)
        #expect(BruteForceSolver.countSolutions(empty, cages: [Cage(cells: [0, 81], sum: 3)]) == 0)
    }

    @Test func dominoCagesAloneLeaveFewSolutions() {
        let cages = dominoCages(for: values(wikiSolution))
        #expect(BruteForceSolver.countSolutions(Array(repeating: 0, count: 81), cages: cages, limit: 1) == 1)
    }

    @Test func cageOverflowIsContradictory() {
        var v = Array(repeating: 0, count: 81)
        v[0] = 9
        v[1] = 8
        #expect(Board(values: v, cages: [Cage(cells: [0, 1], sum: 10)]).isContradictory)
        #expect(!Board(values: v, cages: [Cage(cells: [0, 1], sum: 17)]).isContradictory)
    }

    @Test func gradesWithCages() throws {
        let cages = dominoCages(for: values(wikiSolution))
        let report = try #require(Grader.grade(values(wikiPuzzle), cages: cages))
        #expect(report.grade.tier == .easy)
    }

    @Test(arguments: 1...10)
    func partitionCoversBoardWithValidCages(seed: Int) {
        var rng = SplitMix64(seed: UInt64(seed))
        let solution = BruteForceSolver.randomSolution(using: &rng)
        let cages = KillerCages.partition(solution: solution, sizes: 2...5, using: &rng)
        #expect(cages.flatMap(\.cells).sorted() == Array(0..<81))
        for cage in cages {
            let digits = cage.cells.map { solution[$0] }
            #expect(Set(digits).count == digits.count)
            #expect(digits.reduce(0, +) == cage.sum)
            #expect(cage.cells.count <= 5)
        }
        #expect(BruteForceSolver.countSolutions(solution, cages: cages) == 1)
    }
}
