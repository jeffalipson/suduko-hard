/// Structure allowed at each Killer tier (spec §4.6).
public struct KillerRules: Sendable, Equatable {
    public let givens: ClosedRange<Int>
    public let cageSizes: ClosedRange<Int>

    public static func forTier(_ tier: Tier) -> KillerRules {
        switch tier {
        case .easy: return KillerRules(givens: 6...12, cageSizes: 2...3)
        case .medium: return KillerRules(givens: 0...6, cageSizes: 2...4)
        case .hard: return KillerRules(givens: 0...3, cageSizes: 2...5)
        case .expert: return KillerRules(givens: 0...0, cageSizes: 2...5)
        case .fiendish: return KillerRules(givens: 0...0, cageSizes: 2...6)
        case .diabolical: return KillerRules(givens: 0...0, cageSizes: 3...7)
        case .nightmare: return KillerRules(givens: 0...0, cageSizes: 3...8)
        }
    }
}

public struct KillerGenerator: Sendable {
    public let solver: LogicalSolver

    public init(solver: LogicalSolver = .killer) {
        self.solver = solver
    }

    /// A unique, logic-solvable Killer puzzle of exactly `tier` whose givens and cages fit the
    /// tier's rules, or nil when the deadline passes.
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
        let rules = KillerRules.forTier(tier)
        let capped = LogicalSolver(techniques: solver.techniques.filter { $0.id.tier <= tier })
        let solution = BruteForceSolver.randomSolution(using: &rng)
        let cages = KillerCages.partition(solution: solution, sizes: rules.cageSizes, using: &rng)
        // A one-cell cage gives its digit away, so it counts as a given.
        let singletonCells = Set(cages.filter { $0.cells.count == 1 }.map { $0.cells[0] })
        guard singletonCells.count <= rules.givens.upperBound else { return nil }

        var givens = solution
        func revealed() -> Int { (0..<81).filter { givens[$0] != 0 || singletonCells.contains($0) }.count }
        var accepted: GradeReport?
        for c in Array(0..<81).shuffled(using: &rng) where revealed() > rules.givens.lowerBound {
            givens[c] = 0
            // The Killer catalog has no uniqueness techniques, so a complete logical solve proves the
            // solution is unique; brute-force counting near zero givens is far too slow for Killer.
            if let report = Grader.grade(givens, cages: cages, solution: solution, solver: capped) {
                accepted = report
            } else {
                givens[c] = solution[c]
            }
        }
        guard let report = accepted, report.grade.tier == tier, rules.givens.contains(revealed()) else { return nil }
        return Puzzle(
            id: String(rng.next(), radix: 16),
            mode: .killer,
            givens: givens,
            cages: cages,
            solution: solution,
            grade: report.grade,
            techniquesRequired: report.techniquesRequired
        )
    }
}
