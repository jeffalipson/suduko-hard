public struct ClassicGenerator: Sendable {
    public let solver: LogicalSolver

    public init(solver: LogicalSolver = .classic) {
        self.solver = solver
    }

    /// A unique, logic-solvable puzzle of exactly `tier`, or nil when the deadline passes
    /// or the solver has no techniques for that tier.
    public func generate<R: RandomNumberGenerator>(
        tier: Tier,
        using rng: inout R,
        deadline: ContinuousClock.Instant? = nil
    ) -> Puzzle? {
        guard tier <= solver.maxTier else { return nil }
        while deadline.map({ ContinuousClock.now < $0 }) ?? true {
            if let puzzle = attempt(tier: tier, using: &rng) { return puzzle }
        }
        return nil
    }

    private func attempt<R: RandomNumberGenerator>(tier: Tier, using rng: inout R) -> Puzzle? {
        let solution = BruteForceSolver.randomSolution(using: &rng)
        var givens = solution
        var accepted: GradeReport?
        // Cell c pairs with 80 - c (180° symmetry); 40 is the centre.
        var order = Array(0...40)
        order.shuffle(using: &rng)
        for c in order {
            let pair = c == 40 ? [40] : [c, 80 - c]
            let saved = pair.map { givens[$0] }
            for p in pair { givens[p] = 0 }
            if BruteForceSolver.countSolutions(givens) == 1,
               let report = Grader.grade(givens, solution: solution, solver: solver),
               report.grade.tier <= tier {
                accepted = report
            } else {
                for (p, v) in zip(pair, saved) { givens[p] = v }
            }
        }
        guard let report = accepted, report.grade.tier == tier else { return nil }
        return Puzzle(
            id: String(rng.next(), radix: 16),
            mode: .classic,
            givens: givens,
            cages: [],
            solution: solution,
            grade: report.grade,
            techniquesRequired: report.techniquesRequired
        )
    }
}
