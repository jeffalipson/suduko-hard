/// Bitmask backtracking. Used only to prove uniqueness and to build random full grids — never for hints.
public enum BruteForceSolver {
    /// Counts solutions, stopping once `limit` is reached. Invalid givens or cages → 0.
    public static func countSolutions(_ values: [Int], cages: [Cage] = [], limit: Int = 2) -> Int {
        guard var state = SearchState(values, cages: cages) else { return 0 }
        var count = 0
        var first: [Int]?
        search(&state, limit: limit, count: &count, first: &first) { _ in }
        return count
    }

    public static func solve(_ values: [Int], cages: [Cage] = []) -> [Int]? {
        guard var state = SearchState(values, cages: cages) else { return nil }
        var count = 0
        var first: [Int]?
        search(&state, limit: 1, count: &count, first: &first) { _ in }
        return first
    }

    /// A uniformly shuffled complete valid grid.
    public static func randomSolution<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        var state = SearchState(Array(repeating: 0, count: 81), cages: [])!
        var count = 0
        var first: [Int]?
        search(&state, limit: 1, count: &count, first: &first) { $0.shuffle(using: &rng) }
        return first!
    }

    private static func search(
        _ s: inout SearchState,
        limit: Int,
        count: inout Int,
        first: inout [Int]?,
        order: (inout [Int]) -> Void
    ) {
        // Pick the empty cell with the fewest options.
        var best = -1
        var bestMask: UInt16 = 0
        var bestCount = 10
        for c in 0..<81 where s.grid[c] == 0 {
            let mask = s.available(c)
            let n = mask.nonzeroBitCount
            if n == 0 { return }
            if n < bestCount {
                best = c
                bestMask = mask
                bestCount = n
                if n == 1 { break }
            }
        }
        if best < 0 {
            count += 1
            if first == nil { first = s.grid }
            return
        }
        var digits = (1...9).filter { bestMask & (1 << $0) != 0 }
        order(&digits)
        for d in digits {
            s.set(best, d)
            search(&s, limit: limit, count: &count, first: &first, order: order)
            s.unset(best, d)
            if count >= limit { return }
        }
    }
}

private struct SearchState {
    var grid: [Int]
    var rowUsed = [UInt16](repeating: 0, count: 9)
    var colUsed = [UInt16](repeating: 0, count: 9)
    var boxUsed = [UInt16](repeating: 0, count: 9)
    var cageOf = [Int](repeating: -1, count: 81)
    var cageUsed: [UInt16] = []
    var cageSumLeft: [Int] = []
    var cageCellsLeft: [Int] = []

    /// Nil when the givens or cages are malformed or already conflict.
    init?(_ values: [Int], cages: [Cage]) {
        guard values.count == 81 else { return nil }
        grid = Array(repeating: 0, count: 81)
        cageUsed = Array(repeating: 0, count: cages.count)
        cageSumLeft = cages.map(\.sum)
        cageCellsLeft = cages.map(\.cells.count)
        for (i, cage) in cages.enumerated() {
            guard !cage.cells.isEmpty || cage.sum == 0 else { return nil }
            for c in cage.cells {
                guard (0..<81).contains(c), cageOf[c] == -1 else { return nil }
                cageOf[c] = i
            }
        }
        for c in 0..<81 where values[c] != 0 {
            let d = values[c]
            guard (1...9).contains(d), available(c) & (1 << d) != 0 else { return nil }
            set(c, d)
        }
    }

    func available(_ c: Int) -> UInt16 {
        var mask = ~(rowUsed[Geometry.row(c)] | colUsed[Geometry.col(c)] | boxUsed[Geometry.box(c)]) & 0b11_1111_1110
        let k = cageOf[c]
        guard k >= 0 else { return mask }
        mask &= ~cageUsed[k]
        var ok: UInt16 = 0
        for d in 1...9 where mask & (1 << d) != 0 {
            if SearchState.fillable(sum: cageSumLeft[k] - d, cells: cageCellsLeft[k] - 1, used: cageUsed[k] | (1 << d)) {
                ok |= 1 << d
            }
        }
        return ok
    }

    /// Whether `cells` distinct digits outside `used` can sum to `sum`.
    static func fillable(sum: Int, cells: Int, used: UInt16) -> Bool {
        if cells == 0 { return sum == 0 }
        var low = 0, high = 0, n = 0
        for d in 1...9 where used & (1 << d) == 0 && n < cells {
            low += d
            n += 1
        }
        guard n == cells else { return false }
        n = 0
        for d in stride(from: 9, through: 1, by: -1) where used & (1 << d) == 0 && n < cells {
            high += d
            n += 1
        }
        return low <= sum && sum <= high
    }

    mutating func set(_ c: Int, _ d: Int) {
        grid[c] = d
        let bit: UInt16 = 1 << d
        rowUsed[Geometry.row(c)] |= bit
        colUsed[Geometry.col(c)] |= bit
        boxUsed[Geometry.box(c)] |= bit
        let k = cageOf[c]
        if k >= 0 {
            cageUsed[k] |= bit
            cageSumLeft[k] -= d
            cageCellsLeft[k] -= 1
        }
    }

    mutating func unset(_ c: Int, _ d: Int) {
        grid[c] = 0
        let mask: UInt16 = ~(1 << d)
        rowUsed[Geometry.row(c)] &= mask
        colUsed[Geometry.col(c)] &= mask
        boxUsed[Geometry.box(c)] &= mask
        let k = cageOf[c]
        if k >= 0 {
            cageUsed[k] &= mask
            cageSumLeft[k] += d
            cageCellsLeft[k] += 1
        }
    }
}
