public struct GradeReport: Hashable, Sendable {
    public let grade: Grade
    /// Distinct techniques used, in `TechniqueID` declaration order (easiest first).
    public let techniquesRequired: [TechniqueID]
}

public enum Grader {
    /// Grades a puzzle. Nil unless it has exactly one solution and the solver finishes it.
    public static func grade(_ givens: [Int], cages: [Cage] = [], solver: LogicalSolver = .classic) -> GradeReport? {
        guard BruteForceSolver.countSolutions(givens, cages: cages) == 1,
              let solution = BruteForceSolver.solve(givens, cages: cages) else { return nil }
        return grade(givens, cages: cages, solution: solution, solver: solver)
    }

    /// Grades a puzzle whose uniqueness the caller has already proved.
    public static func grade(_ givens: [Int], cages: [Cage] = [], solution: [Int], solver: LogicalSolver = .classic) -> GradeReport? {
        let result = solver.solve(Board(values: givens, cages: cages))
        guard result.solved, result.board.values == solution else { return nil }
        let used = Set(result.steps.map(\.technique))
        let techniques = TechniqueID.allCases.filter(used.contains)
        let tier = techniques.map(\.tier).max() ?? .easy
        let score = result.steps.reduce(0) { $0 + $1.technique.weight }
        return GradeReport(grade: Grade(tier: tier, score: score), techniquesRequired: techniques)
    }
}
