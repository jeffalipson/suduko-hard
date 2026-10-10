enum KillerRegions {
    /// Two adjacent houses: consecutive rows, consecutive columns, side-by-side boxes.
    static let pairs: [[Int]] =
        (0..<8).map { [$0, $0 + 1] }
        + (9..<17).map { [$0, $0 + 1] }
        + (0..<9).filter { $0 % 3 != 2 }.map { [18 + $0, 19 + $0] }
        + (0..<6).map { [18 + $0, 21 + $0] }

    /// `k` consecutive rows, then `k` consecutive columns.
    static func lines(_ k: Int) -> [[Int]] {
        (0...(9 - k)).map { Array($0..<($0 + k)) } + (0...(9 - k)).map { Array((9 + $0)..<(9 + $0 + k)) }
    }
}

/// The 45 rule: k disjoint houses sum to 45k.
public struct InnieOutie: Technique {
    public let id: TechniqueID
    let regions: [[Int]]

    public static let oneHouse = InnieOutie(id: .innieOutie1, regions: (0..<27).map { [$0] })
    public static let twoHouses = InnieOutie(id: .innieOutie2, regions: KillerRegions.pairs)
    public static let manyHouses = InnieOutie(id: .innieOutieMulti, regions: KillerRegions.lines(3) + KillerRegions.lines(4))

    public func find(in board: Board) -> Step? {
        guard !board.cages.isEmpty else { return nil }
        var groups: [(cells: [Int], sum: Int, region: [Int])] = []
        for region in regions {
            let inRegion = Set(region.flatMap { Geometry.houses[$0] })
            guard inRegion.allSatisfy({ board.cageOf[$0] >= 0 }) else { continue }
            let touching = Set(inRegion.map { board.cageOf[$0] }).sorted()
            let inside = touching.filter { board.cages[$0].cells.allSatisfy(inRegion.contains) }
            let partial = touching.filter { !inside.contains($0) }
            guard !partial.isEmpty else { continue }
            let innieSum = 45 * region.count - inside.map { board.cages[$0].sum }.reduce(0, +)
            let innies = partial.flatMap { board.cages[$0].cells.filter(inRegion.contains) }.sorted()
            let outies = partial.flatMap { board.cages[$0].cells.filter { !inRegion.contains($0) } }.sorted()
            let outieSum = partial.map { board.cages[$0].sum }.reduce(0, +) - innieSum
            groups.append((innies, innieSum, region))
            groups.append((outies, outieSum, region))
        }
        // Single unknown cells first, then small groups.
        for g in groups {
            let empties = g.cells.filter { board.values[$0] == 0 }
            guard empties.count == 1 else { continue }
            let d = g.sum - g.cells.map { board.values[$0] }.reduce(0, +)
            guard (1...9).contains(d), board.has(d, at: empties[0]) else { continue }
            return Step(technique: id, patternCells: g.cells, placements: [CellDigit(cell: empties[0], digit: d)],
                        regions: g.region.map(Region.init(house:)), digits: [d])
        }
        for g in groups where g.cells.count <= 5 {
            let empties = g.cells.filter { board.values[$0] == 0 }
            guard empties.count >= 2 else { continue }
            let possible = CageMath.possibilities(of: g.cells, sum: g.sum, on: board) { a, b in
                Geometry.sees(a, b) || board.cageOf[a] == board.cageOf[b]
            }
            let eliminations = zip(g.cells, possible).flatMap { c, ok in
                board.values[c] != 0 ? [] : board.candidates[c].subtracting(ok).digits.map { CellDigit(cell: c, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            return Step(technique: id, patternCells: g.cells, patternCandidates: board.candidateDigits(of: empties),
                        eliminations: eliminations, regions: g.region.map(Region.init(house:)))
        }
        return nil
    }
}
