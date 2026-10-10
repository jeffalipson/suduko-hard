/// Two-colours each cluster of strong links on a digit. Exactly one colour is true.
/// Wrap: a colour with two cells seeing each other is false everywhere.
/// Trap: a cell outside the cluster seeing both colours loses the digit.
public struct SimpleColoring: Technique {
    public init() {}
    public var id: TechniqueID { .simpleColoring }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            var links: [Int: [Int]] = [:]
            for pair in board.conjugatePairs(of: digit) {
                links[pair.a, default: []].append(pair.b)
                links[pair.b, default: []].append(pair.a)
            }
            var color: [Int: Int] = [:]
            for start in links.keys.sorted() where color[start] == nil {
                var cluster = [start]
                var queue = [start]
                var consistent = true
                color[start] = 0
                while let cell = queue.popLast() {
                    for next in links[cell, default: []] {
                        if let existing = color[next] {
                            if existing == color[cell] { consistent = false }
                        } else {
                            color[next] = 1 - color[cell]!
                            cluster.append(next)
                            queue.append(next)
                        }
                    }
                }
                // An odd cycle only happens on an inconsistent board; skip it.
                guard consistent else { continue }
                cluster.sort()
                let groups = [0, 1].map { k in cluster.filter { color[$0] == k } }

                func step(_ eliminations: [CellDigit]) -> Step {
                    Step(
                        technique: id,
                        patternCells: cluster,
                        patternCandidates: cluster.map { CellDigit(cell: $0, digit: digit) },
                        eliminations: eliminations,
                        digits: [digit],
                        groups: groups.map { $0.map { CellDigit(cell: $0, digit: digit) } }
                    )
                }

                for group in groups where group.combinations(of: 2).contains(where: { Geometry.sees($0[0], $0[1]) }) {
                    return step(group.map { CellDigit(cell: $0, digit: digit) })
                }
                let trapped = (0..<81).filter { c in
                    board.has(digit, at: c) && !cluster.contains(c)
                        && groups[0].contains { Geometry.sees($0, c) }
                        && groups[1].contains { Geometry.sees($0, c) }
                }
                if !trapped.isEmpty {
                    return step(trapped.map { CellDigit(cell: $0, digit: digit) })
                }
            }
        }
        return nil
    }
}
