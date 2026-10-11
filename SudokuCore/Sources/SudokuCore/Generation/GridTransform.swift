/// A validity- and grade-preserving remapping of a puzzle:
/// digit relabelling, row/column shuffles within bands/stacks, band/stack shuffles, transpose.
public struct GridTransform: Sendable, Equatable {
    /// `digitMap[old] = new`; index 0 always maps to 0.
    public let digitMap: [Int]
    /// New row `i` is old row `rowOrder[i]`.
    public let rowOrder: [Int]
    /// New column `i` is old column `colOrder[i]`.
    public let colOrder: [Int]
    public let transpose: Bool

    private let rowInverse: [Int]
    private let colInverse: [Int]

    public init(digitMap: [Int], rowOrder: [Int], colOrder: [Int], transpose: Bool) {
        self.digitMap = digitMap
        self.rowOrder = rowOrder
        self.colOrder = colOrder
        self.transpose = transpose
        var rowInverse = [Int](repeating: 0, count: 9)
        var colInverse = [Int](repeating: 0, count: 9)
        for i in 0..<9 {
            rowInverse[rowOrder[i]] = i
            colInverse[colOrder[i]] = i
        }
        self.rowInverse = rowInverse
        self.colInverse = colInverse
    }

    public static let identity = GridTransform(
        digitMap: Array(0...9), rowOrder: Array(0..<9), colOrder: Array(0..<9), transpose: false
    )

    public static func random<R: RandomNumberGenerator>(using rng: inout R, relabelDigits: Bool = true) -> GridTransform {
        var digits = Array(1...9)
        if relabelDigits { digits.shuffle(using: &rng) }
        let rows = lineOrder(using: &rng)
        let cols = lineOrder(using: &rng)
        return GridTransform(digitMap: [0] + digits, rowOrder: rows, colOrder: cols, transpose: Bool.random(using: &rng))
    }

    /// Random transform suitable for `puzzle`. Killer puzzles only get the 8 rotations/reflections of
    /// the grid: relabelling digits changes cage sums, and shuffling rows or columns (even within a
    /// band) separates neighbouring cells, which splits cages into disconnected pieces.
    public static func random<R: RandomNumberGenerator>(for puzzle: Puzzle, using rng: inout R) -> GridTransform {
        guard !puzzle.cages.isEmpty else { return random(using: &rng) }
        let forward = Array(0..<9)
        return GridTransform(
            digitMap: Array(0...9),
            rowOrder: Bool.random(using: &rng) ? forward : forward.reversed(),
            colOrder: Bool.random(using: &rng) ? forward : forward.reversed(),
            transpose: Bool.random(using: &rng)
        )
    }

    /// Shuffles the three bands (or stacks) and the three lines inside each.
    static func lineOrder<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        var bands = [0, 1, 2]
        bands.shuffle(using: &rng)
        var order: [Int] = []
        for band in bands {
            var lines = [0, 1, 2]
            lines.shuffle(using: &rng)
            order += lines.map { band * 3 + $0 }
        }
        return order
    }

    /// Where an old cell ends up.
    public func newCell(for old: Int) -> Int {
        let r = rowInverse[Geometry.row(old)]
        let c = colInverse[Geometry.col(old)]
        return transpose ? Geometry.cell(c, r) : Geometry.cell(r, c)
    }

    public func apply(to values: [Int]) -> [Int] {
        var out = [Int](repeating: 0, count: 81)
        for old in 0..<81 { out[newCell(for: old)] = digitMap[values[old]] }
        return out
    }

    public func apply(to cage: Cage) -> Cage {
        Cage(cells: cage.cells.map { newCell(for: $0) }.sorted(), sum: cage.sum)
    }

    public func apply(to puzzle: Puzzle) -> Puzzle {
        precondition(puzzle.cages.isEmpty || digitMap == Array(0...9), "Killer puzzles must not relabel digits")
        var p = puzzle
        p.givens = apply(to: puzzle.givens)
        p.solution = apply(to: puzzle.solution)
        p.cages = puzzle.cages.map { apply(to: $0) }
        return p
    }
}
