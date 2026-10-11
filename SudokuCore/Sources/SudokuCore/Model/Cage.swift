/// A Killer Sudoku cage: its cells sum to `sum` and contain no repeated digit.
public struct Cage: Hashable, Sendable, Codable {
    public var cells: [Int]
    public var sum: Int

    public init(cells: [Int], sum: Int) {
        self.cells = cells
        self.sum = sum
    }

    /// Every cell reachable from the first through orthogonal neighbours inside the cage.
    public var isConnected: Bool {
        guard let start = cells.first else { return false }
        let members = Set(cells)
        var seen: Set<Int> = [start]
        var stack = [start]
        while let c = stack.popLast() {
            let neighbours = [c >= 9 ? c - 9 : -1, c < 72 ? c + 9 : -1, c % 9 > 0 ? c - 1 : -1, c % 9 < 8 ? c + 1 : -1]
            for n in neighbours where members.contains(n) && !seen.contains(n) {
                seen.insert(n)
                stack.append(n)
            }
        }
        return seen.count == members.count
    }
}
