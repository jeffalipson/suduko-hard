enum CageMath {
    /// What's left of a cage: its empty cells, the sum they need, and the digits still unused.
    struct CageState {
        let empties: [Int]
        let sumLeft: Int
        let allowed: CandidateSet
    }

    static func state(of cage: Cage, on board: Board) -> CageState {
        let placed = cage.cells.map { board.values[$0] }.filter { $0 != 0 }
        return CageState(
            empties: cage.cells.filter { board.values[$0] == 0 },
            sumLeft: cage.sum - placed.reduce(0, +),
            allowed: CandidateSet.all.subtracting(CandidateSet(placed))
        )
    }

    /// Sets of `count` distinct digits from `allowed` that sum to `sum`.
    static func combinations(sum: Int, count: Int, allowed: CandidateSet = .all) -> [CandidateSet] {
        var out: [CandidateSet] = []
        func go(_ from: Int, _ left: Int, _ n: Int, _ acc: CandidateSet) {
            if n == 0 {
                if left == 0 { out.append(acc) }
                return
            }
            guard from <= 9 else { return }
            for d in from...9 where allowed.contains(d) && d <= left {
                var next = acc
                next.insert(d)
                go(d + 1, left - d, n - 1, next)
            }
        }
        go(1, sum, count, .empty)
        return out
    }

    /// For each cell, the digits it takes in at least one assignment where the cells sum to `sum`,
    /// fit their candidates (placed cells are fixed), and pairs that `mustDiffer` differ.
    static func possibilities(of cells: [Int], sum: Int, on board: Board, mustDiffer: (Int, Int) -> Bool) -> [CandidateSet] {
        var result = [CandidateSet](repeating: .empty, count: cells.count)
        var chosen = [Int](repeating: 0, count: cells.count)
        func options(_ i: Int) -> [Int] {
            board.values[cells[i]] != 0 ? [board.values[cells[i]]] : board.candidates[cells[i]].digits
        }
        func go(_ i: Int, _ left: Int) {
            if i == cells.count {
                if left == 0 { for j in cells.indices { result[j].insert(chosen[j]) } }
                return
            }
            let after = cells.count - i - 1
            for d in options(i) where d <= left && left - d <= 9 * after {
                guard (0..<i).allSatisfy({ chosen[$0] != d || !mustDiffer(cells[$0], cells[i]) }) else { continue }
                chosen[i] = d
                go(i + 1, left - d)
            }
        }
        go(0, sum)
        return result
    }
}
