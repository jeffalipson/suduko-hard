/// Builds Mathdoku puzzles for a tier: random Latin square, random cages, an operation per cage, then
/// keeps the puzzle only if the grader solves it needing exactly the tier's technique level.
public struct MathdokuGenerator: Sendable {
    public struct Config: Sendable {
        public let n: Int
        /// Cage-size weights.
        let sizes: [(Int, Double)]
        /// How many single-cell (given) cages to keep.
        let singles: Int
        let maxSize: Int
        public let level: Int
        /// Chance a 3+-cell cage is + rather than ×.
        let plusBias: Double
        public let hidden: Bool
        /// Contradiction steps the solve must need (level 4 tiers).
        let minContradictions: Int
    }

    public static func config(_ tier: Tier) -> Config {
        switch tier {
        case .easy: Config(n: 5, sizes: [(2, 5), (3, 3), (1, 1)], singles: 3, maxSize: 3, level: 1, plusBias: 0.5, hidden: false, minContradictions: 0)
        case .medium: Config(n: 6, sizes: [(2, 5), (3, 4), (4, 1)], singles: 1, maxSize: 4, level: 2, plusBias: 0.5, hidden: false, minContradictions: 0)
        case .hard: Config(n: 7, sizes: [(2, 4), (3, 4), (4, 2)], singles: 0, maxSize: 4, level: 3, plusBias: 0.55, hidden: false, minContradictions: 0)
        case .expert: Config(n: 8, sizes: [(2, 4), (3, 4), (4, 2)], singles: 0, maxSize: 4, level: 3, plusBias: 0.6, hidden: false, minContradictions: 0)
        case .fiendish: Config(n: 9, sizes: [(2, 4), (3, 4), (4, 2)], singles: 0, maxSize: 4, level: 3, plusBias: 0.6, hidden: false, minContradictions: 0)
        case .diabolical: Config(n: 9, sizes: [(2, 3), (3, 4), (4, 3), (5, 1)], singles: 0, maxSize: 5, level: 4, plusBias: 0.65, hidden: false, minContradictions: 2)
        case .nightmare: Config(n: 9, sizes: [(2, 4), (3, 4), (4, 2)], singles: 0, maxSize: 4, level: 4, plusBias: 0.6, hidden: true, minContradictions: 1)
        }
    }

    public init() {}

    public func generate<R: RandomNumberGenerator>(tier: Tier, using rng: inout R, deadline: ContinuousClock.Instant) -> MathdokuPuzzle? {
        let cfg = Self.config(tier)
        while ContinuousClock.now < deadline {
            let solution = Self.latinSquare(cfg.n, using: &rng)
            let cages = Self.cages(cfg, solution: solution, using: &rng)
            let candidate = MathdokuPuzzle(id: "", n: cfg.n, cages: cages, solution: solution, tier: tier, techniques: [])
            let grade = MathdokuGrader.grade(candidate, maxLevel: cfg.level)
            guard grade.solution == solution, grade.level == cfg.level,
                  grade.counts[.contradiction, default: 0] >= cfg.minContradictions else { continue }
            var puzzle = candidate
            puzzle.techniques = grade.techniques
            puzzle.id = "md-\(tier.name)-\(String(rng.next() % 1_000_000_000, radix: 36))"
            return puzzle
        }
        return nil
    }

    /// A random Latin square, filled cell by cell with shuffled digits and backtracking.
    static func latinSquare<R: RandomNumberGenerator>(_ n: Int, using rng: inout R) -> [Int] {
        var grid = Array(repeating: 0, count: n * n)
        var rowUsed = Array(repeating: CandidateSet.empty, count: n)
        var colUsed = Array(repeating: CandidateSet.empty, count: n)
        func fill(_ i: Int) -> Bool {
            if i == n * n { return true }
            let r = i / n, c = i % n
            for d in Array(1...n).shuffled(using: &rng) where !rowUsed[r].contains(d) && !colUsed[c].contains(d) {
                grid[i] = d
                rowUsed[r].insert(d)
                colUsed[c].insert(d)
                if fill(i + 1) { return true }
                rowUsed[r].remove(d)
                colUsed[c].remove(d)
            }
            grid[i] = 0
            return false
        }
        _ = fill(0)
        return grid
    }

    /// Grows random cages, merges spare single cells into neighbours, then picks each cage's operation.
    static func cages<R: RandomNumberGenerator>(_ cfg: Config, solution: [Int], using rng: inout R) -> [MathCage] {
        let n = cfg.n
        var owner = Array(repeating: -1, count: n * n)
        var groups: [[Int]] = []
        func neighbours(_ c: Int) -> [Int] {
            var out: [Int] = []
            if c / n > 0 { out.append(c - n) }
            if c / n < n - 1 { out.append(c + n) }
            if c % n > 0 { out.append(c - 1) }
            if c % n < n - 1 { out.append(c + 1) }
            return out
        }
        let total = cfg.sizes.reduce(0) { $0 + $1.1 }
        for start in Array(0..<(n * n)).shuffled(using: &rng) where owner[start] == -1 {
            var pick = Double(rng.next() % 1_000_000) / 1_000_000 * total
            var want = cfg.sizes[0].0
            for (size, weight) in cfg.sizes {
                if pick < weight { want = size; break }
                pick -= weight
            }
            var group = [start]
            owner[start] = groups.count
            while group.count < want {
                let frontier = group.flatMap(neighbours).filter { owner[$0] == -1 }
                guard let next = frontier.randomElement(using: &rng) else { break }
                owner[next] = groups.count
                group.append(next)
            }
            groups.append(group)
        }
        // Keep only `singles` single-cell cages; fold the rest into a neighbouring cage.
        let singles = groups.indices.filter { groups[$0].count == 1 }.shuffled(using: &rng)
        for g in singles.dropFirst(cfg.singles) {
            let cell = groups[g][0]
            let options = Set(neighbours(cell).map { owner[$0] }).filter { $0 != g }
            let target = options.filter { groups[$0].count < cfg.maxSize }.randomElement(using: &rng) ?? options.randomElement(using: &rng)
            guard let t = target else { continue }
            groups[t].append(cell)
            owner[cell] = t
            groups[g] = []
        }
        return groups.filter { !$0.isEmpty }.map { cells in
            let values = cells.map { solution[$0] }
            var (op, target) = operation(values, plusBias: cfg.plusBias, using: &rng)
            if cfg.hidden && cells.count > 1 { op = .hidden }
            return MathCage(cells: cells, op: op, target: target)
        }
    }

    static func operation<R: RandomNumberGenerator>(_ values: [Int], plusBias: Double, using rng: inout R) -> (MathOp, Int) {
        let sum = values.reduce(0, +), product = values.reduce(1, *)
        switch values.count {
        case 1: return (.given, values[0])
        case 2:
            let hi = values.max()!, lo = values.min()!
            var options: [(MathOp, Int)] = [(.add, sum), (.subtract, hi - lo), (.multiply, product)]
            if hi % lo == 0 { options.append((.divide, hi / lo)) }
            return options.randomElement(using: &rng)!
        default:
            return Double(rng.next() % 1000) / 1000 < plusBias ? (.add, sum) : (.multiply, product)
        }
    }
}
