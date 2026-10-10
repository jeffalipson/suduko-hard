/// N cells of one house holding exactly N+1 candidates.
struct AlmostLockedSet {
    let cells: [Int]
    let digits: CandidateSet
    let house: Int

    func cells(with digit: Int, on board: Board) -> [Int] { cells.filter { board.has(digit, at: $0) } }

    /// Every ALS of 1...maxSize cells, each cell set listed once.
    static func all(in board: Board, maxSize: Int) -> [AlmostLockedSet] {
        var seen = Set<[Int]>()
        var out: [AlmostLockedSet] = []
        for (h, house) in Geometry.houses.enumerated() {
            let empties = house.filter { board.values[$0] == 0 }
            for k in 1...maxSize where k < empties.count {
                for combo in empties.combinations(of: k) {
                    let digits = combo.reduce(CandidateSet.empty) { $0.union(board.candidates[$1]) }
                    guard digits.count == k + 1, seen.insert(combo).inserted else { continue }
                    out.append(AlmostLockedSet(cells: combo, digits: digits, house: h))
                }
            }
        }
        return out
    }
}

/// Two almost locked sets joined by a restricted common digit x: another common digit z
/// must sit in one of them, so cells seeing every z in both lose z.
public struct ALSXZ: Technique {
    public init() {}
    public var id: TechniqueID { .alsXZ }

    public func find(in board: Board) -> Step? {
        let sets = AlmostLockedSet.all(in: board, maxSize: 3)
        for i in sets.indices {
            for j in sets.indices where j > i {
                let (a, b) = (sets[i], sets[j])
                guard Set(a.cells).isDisjoint(with: b.cells) else { continue }
                let common = a.digits.intersection(b.digits)
                guard common.count >= 2 else { continue }
                for x in common.digits {
                    let ax = a.cells(with: x, on: board), bx = b.cells(with: x, on: board)
                    guard ax.allSatisfy({ p in bx.allSatisfy { Geometry.sees(p, $0) } }) else { continue }
                    for z in common.digits where z != x {
                        let zCells = a.cells(with: z, on: board) + b.cells(with: z, on: board)
                        let eliminations = board.eliminations(of: z, seeingAll: zCells, excluding: a.cells + b.cells)
                        guard !eliminations.isEmpty else { continue }
                        return Step(
                            technique: id,
                            patternCells: a.cells + b.cells,
                            patternCandidates: board.candidateDigits(of: a.cells + b.cells),
                            eliminations: eliminations,
                            regions: [Region(house: a.house), Region(house: b.house)],
                            digits: [x, z]
                        )
                    }
                }
            }
        }
        return nil
    }
}
