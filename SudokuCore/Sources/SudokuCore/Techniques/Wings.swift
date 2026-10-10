/// Pivot {a,b} seeing pincers {a,c} and {b,c}: one pincer is c, so cells seeing both lose c.
public struct XYWing: Technique {
    public init() {}
    public var id: TechniqueID { .xyWing }

    public func find(in board: Board) -> Step? {
        for pivot in 0..<81 where board.values[pivot] == 0 && board.candidates[pivot].count == 2 {
            let pc = board.candidates[pivot]
            let pincers = Geometry.peers[pivot].filter {
                board.values[$0] == 0 && board.candidates[$0].count == 2 && board.candidates[$0].intersection(pc).count == 1
            }
            for pair in pincers.combinations(of: 2) {
                let (x, y) = (pair[0], pair[1])
                let cx = board.candidates[x], cy = board.candidates[y]
                guard cx.intersection(pc) != cy.intersection(pc) else { continue }
                let ex = cx.subtracting(pc), ey = cy.subtracting(pc)
                guard ex == ey, let z = ex.single else { continue }
                let eliminations = board.eliminations(of: z, seeingAll: [x, y], excluding: [pivot])
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: [pivot, x, y],
                    patternCandidates: board.candidateDigits(of: [pivot, x, y]),
                    eliminations: eliminations,
                    digits: pc.digits + [z]
                )
            }
        }
        return nil
    }
}

/// Pivot {a,b,c} seeing pincers {a,c} and {b,c}: c is in one of the three,
/// so cells seeing all three lose c.
public struct XYZWing: Technique {
    public init() {}
    public var id: TechniqueID { .xyzWing }

    public func find(in board: Board) -> Step? {
        for pivot in 0..<81 where board.values[pivot] == 0 && board.candidates[pivot].count == 3 {
            let pc = board.candidates[pivot]
            let pincers = Geometry.peers[pivot].filter {
                board.values[$0] == 0 && board.candidates[$0].count == 2 && board.candidates[$0].subtracting(pc).isEmpty
            }
            for pair in pincers.combinations(of: 2) {
                let (x, y) = (pair[0], pair[1])
                let cx = board.candidates[x], cy = board.candidates[y]
                guard cx != cy, let z = cx.intersection(cy).single else { continue }
                let eliminations = board.eliminations(of: z, seeingAll: [pivot, x, y])
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: [pivot, x, y],
                    patternCandidates: board.candidateDigits(of: [pivot, x, y]),
                    eliminations: eliminations,
                    digits: pc.digits
                )
            }
        }
        return nil
    }
}

/// Two identical bivalue cells {a,b} that don't see each other, joined by a strong link on a
/// (each link end sees one wing): one wing is b, so cells seeing both wings lose b.
public struct WWing: Technique {
    public init() {}
    public var id: TechniqueID { .wWing }

    public func find(in board: Board) -> Step? {
        let bivalue = (0..<81).filter { board.values[$0] == 0 && board.candidates[$0].count == 2 }
        for wings in bivalue.combinations(of: 2) {
            let (i, j) = (wings[0], wings[1])
            guard board.candidates[i] == board.candidates[j], !Geometry.sees(i, j) else { continue }
            let ds = board.candidates[i].digits
            for (link, removed) in [(ds[0], ds[1]), (ds[1], ds[0])] {
                for pair in board.conjugatePairs(of: link) {
                    guard ![i, j].contains(pair.a), ![i, j].contains(pair.b) else { continue }
                    let joined = (Geometry.sees(pair.a, i) && Geometry.sees(pair.b, j))
                        || (Geometry.sees(pair.a, j) && Geometry.sees(pair.b, i))
                    guard joined else { continue }
                    let eliminations = board.eliminations(of: removed, seeingAll: [i, j])
                    guard !eliminations.isEmpty else { continue }
                    return Step(
                        technique: id,
                        patternCells: [i, j, pair.a, pair.b],
                        patternCandidates: board.candidateDigits(of: [i, j])
                            + [CellDigit(cell: pair.a, digit: link), CellDigit(cell: pair.b, digit: link)],
                        eliminations: eliminations,
                        regions: [Region(house: pair.house)],
                        digits: [link, removed]
                    )
                }
            }
        }
        return nil
    }
}
