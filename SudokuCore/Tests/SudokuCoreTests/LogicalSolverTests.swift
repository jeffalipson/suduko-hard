import Testing
import SudokuCore

@Suite struct LogicalSolverTests {
    @Test func solvesEasyPuzzleWithSingles() {
        let result = LogicalSolver.classic.solve(Board(values: values(wikiPuzzle)))
        #expect(result.solved)
        #expect(result.board.values == values(wikiSolution))
        #expect(result.steps.allSatisfy { $0.technique.tier == .easy })
    }

    @Test func gradesEasyPuzzle() throws {
        let report = try #require(Grader.grade(values(wikiPuzzle)))
        #expect(report.grade.tier == .easy)
        #expect(report.grade.score > 0)
        #expect(report.techniquesRequired.allSatisfy { $0.tier == .easy })
    }

    @Test func inkalaIsBeyondNightmare() {
        // Needs deeper nesting than any published tier: the full ladder progresses but stays ungraded.
        let result = LogicalSolver.classic.solve(Board(values: values(inkalaPuzzle)))
        #expect(!result.solved)
        #expect(result.steps.contains { $0.technique.tier == .nightmare })
        #expect(Grader.grade(values(inkalaPuzzle)) == nil)
    }

    @Test func multipleSolutionsHaveNoGrade() {
        #expect(Grader.grade(Array(repeating: 0, count: 81)) == nil)
    }

    @Test func contradictoryGivensHaveNoGrade() {
        var v = values(wikiPuzzle)
        v[2] = 5   // second 5 in row 0
        #expect(Grader.grade(v) == nil)
    }

    @Test func maxTierOfClassicCatalog() {
        #expect(LogicalSolver.classic.maxTier == .nightmare)
    }

    @Test func catalogCoversEveryTechniqueOnceInTierOrder() {
        let classic = TechniqueCatalog.classic.map(\.id)
        let killer = TechniqueCatalog.killer.map(\.id)
        #expect(Set(classic) == Set(TechniqueID.allCases.filter { !$0.isKillerOnly }))
        #expect(classic.count == Set(classic).count)
        #expect(classic.map(\.tier) == classic.map(\.tier).sorted())
        #expect(killer.count == Set(killer).count)
        #expect(killer.map(\.tier) == killer.map(\.tier).sorted())
        #expect(Set(killer) == Set(TechniqueID.allCases.filter { !$0.rawValue.hasPrefix("uniqueRectangle") }))
    }

    @Test func nextStepPrefersEasiestTechnique() throws {
        var v = values(wikiSolution)
        v[0] = 0
        let step = try #require(LogicalSolver.classic.nextStep(on: Board(values: v)))
        #expect(step.technique == .fullHouse)
    }
}
