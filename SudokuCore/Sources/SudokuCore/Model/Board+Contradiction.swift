extension Board {
    /// An empty cell with no candidates, a repeated digit in a house, or a digit with no place left in a house.
    public var isContradictory: Bool {
        for c in 0..<81 where values[c] == 0 && candidates[c].isEmpty { return true }
        for house in Geometry.houses {
            var placed = CandidateSet.empty
            var possible = CandidateSet.empty
            for c in house {
                if values[c] != 0 {
                    if placed.contains(values[c]) { return true }
                    placed.insert(values[c])
                } else {
                    possible = possible.union(candidates[c])
                }
            }
            if placed.union(possible) != .all { return true }
        }
        for cage in cages {
            let placed = cage.cells.map { values[$0] }.filter { $0 != 0 }
            let total = placed.reduce(0, +)
            if Set(placed).count != placed.count || total > cage.sum { return true }
            if placed.count == cage.cells.count && total != cage.sum { return true }
        }
        return false
    }
}
