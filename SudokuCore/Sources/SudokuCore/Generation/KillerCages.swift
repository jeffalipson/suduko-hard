public enum KillerCages {
    static func neighbours(_ cell: Int) -> [Int] {
        let r = Geometry.row(cell), c = Geometry.col(cell)
        var out: [Int] = []
        if r > 0 { out.append(cell - 9) }
        if r < 8 { out.append(cell + 9) }
        if c > 0 { out.append(cell - 1) }
        if c < 8 { out.append(cell + 1) }
        return out
    }

    /// Splits the grid into orthogonally connected cages whose digits (from `solution`) never repeat.
    /// Cages aim for a random size in `sizes`; leftover single cells merge into a neighbouring cage
    /// when that keeps the cage valid and within the maximum size.
    public static func partition<R: RandomNumberGenerator>(solution: [Int], sizes: ClosedRange<Int>, using rng: inout R) -> [Cage] {
        var cageOf = [Int](repeating: -1, count: 81)
        var groups: [[Int]] = []
        for start in Array(0..<81).shuffled(using: &rng) where cageOf[start] == -1 {
            let target = Int.random(in: sizes, using: &rng)
            var cells = [start]
            var digits = CandidateSet([solution[start]])
            cageOf[start] = groups.count
            while cells.count < target {
                let frontier = Set(cells.flatMap(neighbours))
                    .filter { cageOf[$0] == -1 && !digits.contains(solution[$0]) }
                    .sorted()
                guard let next = frontier.randomElement(using: &rng) else { break }
                cells.append(next)
                digits.insert(solution[next])
                cageOf[next] = groups.count
            }
            groups.append(cells)
        }
        for i in groups.indices where groups[i].count == 1 {
            let cell = groups[i][0]
            let options = neighbours(cell).map { cageOf[$0] }.filter { j in
                j != i && groups[j].count < sizes.upperBound && !groups[j].contains { solution[$0] == solution[cell] }
            }
            guard let j = options.first else { continue }
            groups[j].append(cell)
            groups[i] = []
            cageOf[cell] = j
        }
        return groups.filter { !$0.isEmpty }.map { cells in
            Cage(cells: cells.sorted(), sum: cells.map { solution[$0] }.reduce(0, +))
        }
    }
}
