import Testing
import SudokuCore

@Suite struct PolishCoreTests {
    @Test func solverStopsAtItsDeadline() {
        let start = ContinuousClock.now
        let result = LogicalSolver.classic.solve(Board(values: values(inkalaPuzzle)), deadline: start)
        #expect(result.steps.isEmpty)
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    @Test func graderPassesTheDeadlineThrough() {
        #expect(Grader.grade(values(wikiPuzzle), solution: values(wikiSolution), deadline: .now - .seconds(1)) == nil)
        #expect(Grader.grade(values(wikiPuzzle), solution: values(wikiSolution), deadline: .now + .seconds(60)) != nil)
    }
}
