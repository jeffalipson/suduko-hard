/// A Mathdoku puzzle: an n×n Latin square divided into arithmetic cages.
public struct MathdokuPuzzle: Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var n: Int
    public var cages: [MathCage]
    /// The answer, row by row (`row * n + column`).
    public var solution: [Int]
    public var tier: Tier
    /// Techniques the grader needed, easiest first.
    public var techniques: [MathTechnique]

    public init(id: String, n: Int, cages: [MathCage], solution: [Int], tier: Tier, techniques: [MathTechnique]) {
        self.id = id
        self.n = n
        self.cages = cages
        self.solution = solution
        self.tier = tier
        self.techniques = techniques
    }

    public var cellCount: Int { n * n }
    /// Whether the cages show only their targets (Nightmare).
    public var hidesOperations: Bool { cages.contains { $0.op == .hidden } }

    /// The cage holding each cell.
    public var cageIndex: [Int] {
        var index = Array(repeating: 0, count: cellCount)
        for (i, cage) in cages.enumerated() { for c in cage.cells { index[c] = i } }
        return index
    }

    /// A small 4×4 puzzle for tests and previews.
    public static let sample4 = MathdokuPuzzle(
        id: "sample4", n: 4,
        cages: [
            MathCage(cells: [0, 1, 4], op: .add, target: 6),       // 2 1 3
            MathCage(cells: [2, 3], op: .subtract, target: 1),     // 4 3
            MathCage(cells: [8, 12], op: .add, target: 5),         // 4 1
            MathCage(cells: [5, 6, 9], op: .multiply, target: 24), // 4 2 3
            MathCage(cells: [7, 11], op: .divide, target: 2),      // 1 2
            MathCage(cells: [10, 14], op: .subtract, target: 2),   // 1 3
            MathCage(cells: [13], op: .given, target: 2),
            MathCage(cells: [15], op: .given, target: 4),
        ],
        solution: [2, 1, 4, 3,
                   3, 4, 2, 1,
                   4, 3, 1, 2,
                   1, 2, 3, 4],
        tier: .easy, techniques: [.cageArithmetic])
}

extension MathdokuPuzzle {
    /// One of the 8 rotations/reflections (0 = unchanged). The only reshuffles that keep every cage's
    /// arithmetic: swapping rows or relabelling digits would break the clues.
    public func transformed(_ k: Int) -> MathdokuPuzzle {
        let k = ((k % 8) + 8) % 8
        guard k != 0 else { return self }
        let last = n - 1
        func map(_ cell: Int) -> Int {
            var r = cell / n, c = cell % n
            if k >= 4 { c = last - c }                     // mirror first for 4…7
            for _ in 0..<(k % 4) { (r, c) = (c, last - r) } // then rotate 90° k times
            return r * n + c
        }
        var solution = Array(repeating: 0, count: cellCount)
        for cell in 0..<cellCount { solution[map(cell)] = self.solution[cell] }
        let cages = self.cages.map { MathCage(cells: $0.cells.map(map), op: $0.op, target: $0.target) }
        return MathdokuPuzzle(id: id, n: n, cages: cages, solution: solution, tier: tier, techniques: techniques)
    }
}
