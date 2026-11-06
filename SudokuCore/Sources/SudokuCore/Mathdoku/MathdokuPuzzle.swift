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
            MathCage(cells: [0, 1], op: .divide, target: 2),       // 2 1
            MathCage(cells: [2, 3], op: .subtract, target: 1),     // 4 3
            MathCage(cells: [4, 8], op: .add, target: 7),          // 3 4
            MathCage(cells: [5, 6, 9], op: .multiply, target: 24), // 4 2 3
            MathCage(cells: [7, 11], op: .divide, target: 2),      // 1 2
            MathCage(cells: [10, 14], op: .subtract, target: 2),   // 1 3
            MathCage(cells: [12, 13], op: .multiply, target: 2),   // 1 2
            MathCage(cells: [15], op: .given, target: 4),
        ],
        solution: [2, 1, 4, 3,
                   3, 4, 2, 1,
                   4, 3, 1, 2,
                   1, 2, 3, 4],
        tier: .easy, techniques: [.cageArithmetic])
}
