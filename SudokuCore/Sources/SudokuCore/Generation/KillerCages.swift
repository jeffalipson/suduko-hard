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
        // Layouts are cheap: retry until every cage reaches the minimum size.
        var cages: [Cage] = []
        for _ in 0..<100 {
            cages = layout(solution: solution, sizes: sizes, using: &rng)
            if cages.allSatisfy({ $0.cells.count >= sizes.lowerBound }) { break }
        }
        return cages
    }

    static func layout<R: RandomNumberGenerator>(solution: [Int], sizes: ClosedRange<Int>, using rng: inout R) -> [Cage] {
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
        // Merge cages smaller than the minimum (including single cells) into a neighbouring cage
        // when the result keeps distinct digits and stays within the maximum size.
        var merged = true
        while merged {
            merged = false
            for i in groups.indices where !groups[i].isEmpty && groups[i].count < max(2, sizes.lowerBound) {
                let digits = Set(groups[i].map { solution[$0] })
                let options = Set(groups[i].flatMap(neighbours).map { cageOf[$0] }).sorted().filter { j in
                    j != i && !groups[j].isEmpty && groups[j].count + groups[i].count <= sizes.upperBound
                        && digits.isDisjoint(with: groups[j].map { solution[$0] })
                }
                guard let j = options.first else { continue }
                for cell in groups[i] { cageOf[cell] = j }
                groups[j] += groups[i]
                groups[i] = []
                merged = true
            }
        }
        return groups.filter { !$0.isEmpty }.map { cells in
            Cage(cells: cells.sorted(), sum: cells.map { solution[$0] }.reduce(0, +))
        }
    }

    /// Index pairs of orthogonally adjacent cages that can merge: combined size within `maxSize`
    /// and no digit (from `solution`) repeated.
    static func mergeablePairs(_ cages: [Cage], solution: [Int], maxSize: Int) -> [(Int, Int)] {
        var owner = [Int](repeating: -1, count: 81)
        for (i, cage) in cages.enumerated() { for c in cage.cells { owner[c] = i } }
        var pairs = Set<[Int]>()
        for (i, cage) in cages.enumerated() {
            for c in cage.cells {
                for n in neighbours(c) where owner[n] > i {
                    let j = owner[n]
                    guard cage.cells.count + cages[j].cells.count <= maxSize,
                          Set(cage.cells.map { solution[$0] }).isDisjoint(with: cages[j].cells.map { solution[$0] }) else { continue }
                    pairs.insert([i, j])
                }
            }
        }
        return pairs.sorted { $0.lexicographicallyPrecedes($1) }.map { ($0[0], $0[1]) }
    }

    /// `cages` with cage `j` folded into cage `i`.
    static func merging(_ cages: [Cage], _ i: Int, _ j: Int) -> [Cage] {
        var out = cages
        out[i] = Cage(cells: (cages[i].cells + cages[j].cells).sorted(), sum: cages[i].sum + cages[j].sum)
        out.remove(at: j)
        return out
    }
}
