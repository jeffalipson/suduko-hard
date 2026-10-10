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
        // Grade only with techniques up to the target: anything harder leaves the solver stuck,
        // which rejects the removal without running expensive searches.
        let capped = LogicalSolver(techniques: solver.techniques.filter { $0.id.tier <= tier })
        let solution = BruteForceSolver.randomSolution(using: &rng)
        var givens = solution
        var accepted: GradeReport?

        func tryRemoving(_ cells: [Int]) {
            let saved = cells.map { givens[$0] }
            for p in cells { givens[p] = 0 }
            if BruteForceSolver.countSolutions(givens) == 1,
               let report = Grader.grade(givens, solution: solution, solver: capped) {
                accepted = report
            } else {
                for (p, v) in zip(cells, saved) { givens[p] = v }
            }
        }

        // Cell c pairs with 80 - c (180° symmetry); 40 is the centre.
        var order = Array(0...40)
        order.shuffle(using: &rng)
        for c in order { tryRemoving(c == 40 ? [40] : [c, 80 - c]) }

        // Diabolical and Nightmare may drop symmetry to dig deeper (spec §5.1).
        if tier >= .diabolical {
            var singles = (0..<81).filter { givens[$0] != 0 }
            singles.shuffle(using: &rng)
            for c in singles where (accepted?.grade.tier ?? .easy) < tier { tryRemoving([c]) }
        }

        guard let report = accepted, report.grade.tier == tier,
              report.tierSteps >= Grader.minimumTierSteps(tier) else { return nil }
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
