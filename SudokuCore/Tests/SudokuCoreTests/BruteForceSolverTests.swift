import Testing
import SudokuCore

@Suite struct BruteForceSolverTests {
    @Test func solvesUniquePuzzle() {
        #expect(BruteForceSolver.countSolutions(values(wikiPuzzle)) == 1)
        #expect(BruteForceSolver.solve(values(wikiPuzzle)) == values(wikiSolution))
    }

    @Test func hardestKnownPuzzleIsUnique() {
        #expect(BruteForceSolver.countSolutions(values(inkalaPuzzle)) == 1)
    }

    @Test func emptyGridHasManySolutions() {
        let empty = Array(repeating: 0, count: 81)
        #expect(BruteForceSolver.countSolutions(empty, limit: 2) == 2)
    }

    @Test func conflictingGivensHaveNoSolution() {
        var v = Array(repeating: 0, count: 81)
        v[0] = 5
        v[1] = 5
        #expect(BruteForceSolver.countSolutions(v) == 0)
        #expect(BruteForceSolver.solve(v) == nil)
    }

    @Test func outOfRangeDigitHasNoSolution() {
        var v = Array(repeating: 0, count: 81)
        v[0] = 10
        #expect(BruteForceSolver.countSolutions(v) == 0)
    }

    @Test func randomSolutionsAreValidAndSeeded() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 1)
        var c = SplitMix64(seed: 2)
        let s1 = BruteForceSolver.randomSolution(using: &a)
        let s2 = BruteForceSolver.randomSolution(using: &b)
        let s3 = BruteForceSolver.randomSolution(using: &c)
        #expect(isValidSolution(s1))
        #expect(isValidSolution(s3))
        #expect(s1 == s2)
        #expect(s1 != s3)
    }
}
