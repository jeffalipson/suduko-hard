/// A Killer Sudoku cage: its cells sum to `sum` and contain no repeated digit.
public struct Cage: Hashable, Sendable, Codable {
    public var cells: [Int]
    public var sum: Int

    public init(cells: [Int], sum: Int) {
        self.cells = cells
        self.sum = sum
    }
}
