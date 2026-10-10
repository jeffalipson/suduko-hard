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

extension KillerRules {
    /// Every cage fits this tier's sizes (one-cell cages are allowed; they count as givens).
    public func admits(_ cages: [Cage]) -> Bool {
        cages.allSatisfy { $0.cells.count == 1 || cageSizes.contains($0.cells.count) }
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
            if let puzzle = attempt(tier: tier, deadline: deadline, using: &rng) { return puzzle }
        }
        return nil
    }

    private func attempt<R: RandomNumberGenerator>(tier: Tier, deadline: ContinuousClock.Instant?, using rng: inout R) -> Puzzle? {
        let rules = KillerRules.forTier(tier)
        let capped = LogicalSolver(techniques: solver.techniques.filter { $0.id.tier <= tier })
        if rules.givens.upperBound == 0 {
            return attemptByMerging(tier: tier, rules: rules, capped: capped, deadline: deadline, using: &rng)
        }
        let solution = BruteForceSolver.randomSolution(using: &rng)
        let cages = KillerCages.partition(solution: solution, sizes: rules.cageSizes, using: &rng)
        guard rules.admits(cages) else { return nil }
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
        guard let report = accepted, report.grade.tier == tier, report.tierSteps >= Grader.minimumTierSteps(tier),
              rules.givens.contains(revealed()) else { return nil }
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

    /// Zero-given tiers: random large-cage layouts almost never have a unique solution, so start from
    /// minimum-size cages (which pin the solution down) and merge neighbouring cages while the puzzle
    /// stays logically solvable within the tier — the cage counterpart of removing givens.
    private func attemptByMerging<R: RandomNumberGenerator>(
        tier: Tier, rules: KillerRules, capped: LogicalSolver, deadline: ContinuousClock.Instant?, using rng: inout R
    ) -> Puzzle? {
        let solution = BruteForceSolver.randomSolution(using: &rng)
        let empty = [Int](repeating: 0, count: 81)
        // Smallest cages (plus one size up, so 81 cells tile without one-cell leftovers).
        let smallest = rules.cageSizes.lowerBound
        var cages = KillerCages.partition(solution: solution, sizes: smallest...min(smallest + 1, rules.cageSizes.upperBound), using: &rng)
        guard rules.admits(cages), !cages.contains(where: { $0.cells.count == 1 }),
              var report = Grader.grade(empty, cages: cages, solution: solution, solver: capped) else { return nil }
        var merged = true
        while merged && report.grade.tier < tier {
            merged = false
            let pairs = KillerCages.mergeablePairs(cages, solution: solution, maxSize: rules.cageSizes.upperBound)
            for (i, j) in pairs.shuffled(using: &rng) {
                // Checked between grades: one grade can overrun the deadline (seconds at Nightmare).
                if let deadline, ContinuousClock.now >= deadline { return nil }
                let candidate = KillerCages.merging(cages, i, j)
                // A complete logical solve (no uniqueness techniques in the Killer catalog) proves uniqueness.
                if let r = Grader.grade(empty, cages: candidate, solution: solution, solver: capped) {
                    cages = candidate
                    report = r
                    merged = true
                    break
                }
            }
        }
        guard report.grade.tier == tier else { return nil }

        // Keep merging while the puzzle stays at the target tier, so cages grow toward the sizes
        // the tier allows instead of stopping at mostly two- and three-cell cages. Capped so the
        // extra grading (expensive at the top tiers) stays bounded.
        var tries = 0
        growth: while tries < 60 {
            for (i, j) in KillerCages.mergeablePairs(cages, solution: solution, maxSize: rules.cageSizes.upperBound)
                .shuffled(using: &rng) {
                if let deadline, ContinuousClock.now >= deadline { break growth }
                tries += 1
                if tries > 60 { break growth }
                let candidate = KillerCages.merging(cages, i, j)
                if let r = Grader.grade(empty, cages: candidate, solution: solution, solver: capped), r.grade.tier == tier {
                    cages = candidate
                    report = r
                    continue growth
                }
            }
            break
        }
        guard report.tierSteps >= Grader.minimumTierSteps(tier) else { return nil }

        return Puzzle(
            id: String(rng.next(), radix: 16),
            mode: .killer,
            givens: empty,
            cages: cages,
            solution: solution,
            grade: report.grade,
            techniquesRequired: report.techniquesRequired
        )
    }
}
