/// A Mathdoku position: placed digits and each open cell's candidates.
public struct MathdokuBoard: Hashable, Sendable {
    public let n: Int
    public let cages: [MathCage]
    public var values: [Int]
    public var candidates: [CandidateSet]

    /// The starting position: single-cell cages placed, everything else open.
    public init(puzzle: MathdokuPuzzle) {
        var values = Array(repeating: 0, count: puzzle.cellCount)
        for cage in puzzle.cages where cage.op == .given { values[cage.cells[0]] = cage.target }
        self.init(n: puzzle.n, cages: puzzle.cages, values: values)
    }

    /// A position with `values` placed; candidates are 1…n minus digits placed in the same row or column.
    public init(n: Int, cages: [MathCage], values: [Int]) {
        self.n = n
        self.cages = cages
        self.values = values
        self.candidates = Array(repeating: .empty, count: n * n)
        for cell in 0..<(n * n) where values[cell] == 0 {
            var c = CandidateSet.range(1...n)
            for peer in peers(of: cell) where values[peer] != 0 { c.remove(values[peer]) }
            candidates[cell] = c
        }
    }

    public func row(_ cell: Int) -> Int { cell / n }
    public func col(_ cell: Int) -> Int { cell % n }
    public func rowCells(_ r: Int) -> [Int] { (0..<n).map { r * n + $0 } }
    public func colCells(_ c: Int) -> [Int] { (0..<n).map { $0 * n + c } }
    /// Every row, then every column.
    public var lines: [[Int]] { (0..<n).map(rowCells) + (0..<n).map(colCells) }

    /// Cells sharing a row or column with `cell`.
    public func peers(of cell: Int) -> [Int] {
        (rowCells(row(cell)) + colCells(col(cell))).filter { $0 != cell }
    }

    public var isSolved: Bool { !values.contains(0) }

    /// Places `digit` and removes it from the cell's row and column.
    public mutating func place(_ cell: Int, _ digit: Int) {
        values[cell] = digit
        candidates[cell] = .empty
        for peer in peers(of: cell) { candidates[peer].remove(digit) }
    }

    /// Candidates for the cell, or just its digit if placed.
    public func options(_ cell: Int) -> CandidateSet { values[cell] != 0 ? CandidateSet([values[cell]]) : candidates[cell] }
}
