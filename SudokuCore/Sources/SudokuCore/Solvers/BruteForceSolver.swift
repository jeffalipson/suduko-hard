/// Bitmask backtracking. Used only to prove uniqueness and to build random full grids — never for hints.
public enum BruteForceSolver {
    /// Counts solutions, stopping once `limit` is reached. Invalid givens → 0.
    public static func countSolutions(_ values: [Int], limit: Int = 2) -> Int {
        guard var state = SearchState(values) else { return 0 }
        var count = 0
        var first: [Int]?
        search(&state, limit: limit, count: &count, first: &first) { _ in }
        return count
    }

    /// The first solution found, or nil when there is none.
    public static func solve(_ values: [Int]) -> [Int]? {
        guard var state = SearchState(values) else { return nil }
        var count = 0
        var first: [Int]?
        search(&state, limit: 1, count: &count, first: &first) { _ in }
        return first
    }

    /// A uniformly shuffled complete valid grid.
    public static func randomSolution<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        var state = SearchState(Array(repeating: 0, count: 81))!
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

    /// Nil when the givens are malformed or already conflict.
    init?(_ values: [Int]) {
        guard values.count == 81 else { return nil }
        grid = Array(repeating: 0, count: 81)
        for c in 0..<81 where values[c] != 0 {
            let d = values[c]
            guard (1...9).contains(d), available(c) & (1 << d) != 0 else { return nil }
            set(c, d)
        }
    }

    func available(_ c: Int) -> UInt16 {
        ~(rowUsed[Geometry.row(c)] | colUsed[Geometry.col(c)] | boxUsed[Geometry.box(c)]) & 0b11_1111_1110
    }

    mutating func set(_ c: Int, _ d: Int) {
        grid[c] = d
        let bit: UInt16 = 1 << d
        rowUsed[Geometry.row(c)] |= bit
        colUsed[Geometry.col(c)] |= bit
        boxUsed[Geometry.box(c)] |= bit
    }

    mutating func unset(_ c: Int, _ d: Int) {
        grid[c] = 0
        let mask: UInt16 = ~(1 << d)
        rowUsed[Geometry.row(c)] &= mask
        colUsed[Geometry.col(c)] &= mask
        boxUsed[Geometry.box(c)] &= mask
    }
}
