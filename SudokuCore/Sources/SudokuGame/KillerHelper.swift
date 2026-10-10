import SudokuCore

public struct CageCombination: Equatable, Sendable {
    public let digits: [Int]
    public let possible: Bool
}

extension GameSession {
    public func cageIndex(of cell: Int) -> Int? {
        puzzle.cages.firstIndex { $0.cells.contains(cell) }
    }

    /// The cage total minus the digits entered in it.
    public func remainingSum(ofCage index: Int) -> Int {
        let cage = puzzle.cages[index]
        return cage.sum - cage.cells.map { entries[$0] }.reduce(0, +)
    }

    /// Every set of distinct digits that fills the cage; impossible when it lacks an entered digit.
    public func combinations(ofCage index: Int) -> [CageCombination] {
        let cage = puzzle.cages[index]
        let entered = Set(cage.cells.map { entries[$0] }.filter { $0 != 0 })
        var out: [[Int]] = []
        func go(_ from: Int, _ left: Int, _ acc: [Int]) {
            if acc.count == cage.cells.count {
                if left == 0 { out.append(acc) }
                return
            }
            guard from <= 9 else { return }
            for d in from...9 where d <= left { go(d + 1, left - d, acc + [d]) }
        }
        go(1, cage.sum, [])
        return out.map { CageCombination(digits: $0, possible: entered.isSubset(of: $0)) }
    }

    /// Records that the cage helper was opened (counted once per game).
    public mutating func useCageHelper() {
        if log.cageHelper == 0 { log.cageHelper = 1 }
    }
}
