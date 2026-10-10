public struct SueDeCoq: Technique {
    public init() {}
    public var id: TechniqueID { .sueDeCoq }

    public func find(in board: Board) -> Step? {
        for b in 0..<9 {
            let box = Geometry.boxes[b]
            let lines = Set(box.map(Geometry.row)).sorted() + Set(box.map { 9 + Geometry.col($0) }).sorted()
            for line in lines {
                let lineCells = Geometry.houses[line]
                let intersection = box.filter { lineCells.contains($0) && board.values[$0] == 0 }
                let lineRest = lineCells.filter { !box.contains($0) && board.values[$0] == 0 }
                let boxRest = box.filter { !lineCells.contains($0) && board.values[$0] == 0 }
                for size in 2...3 where size <= intersection.count {
                    for core in intersection.combinations(of: size) {
                        let v = core.reduce(CandidateSet.empty) { $0.union(board.candidates[$1]) }
                        guard v.count == size + 2 else { continue }
                        for lc in lineRest where board.candidates[lc].count == 2 && board.candidates[lc].subtracting(v).isEmpty {
                            let l = board.candidates[lc]
                            for bc in boxRest where board.candidates[bc].count == 2 && board.candidates[bc].subtracting(v).isEmpty {
                                let bset = board.candidates[bc]
                                guard l.intersection(bset).isEmpty else { continue }
                                let rest = v.subtracting(l).subtracting(bset)
                                var eliminations: [CellDigit] = []
                                func remove(_ digits: CandidateSet, from cells: [Int]) {
                                    for c in cells {
                                        for d in board.candidates[c].intersection(digits).digits {
                                            eliminations.append(CellDigit(cell: c, digit: d))
                                        }
                                    }
                                }
                                remove(l.union(rest), from: lineRest.filter { $0 != lc })
                                remove(bset.union(rest), from: boxRest.filter { $0 != bc })
                                remove(v, from: intersection.filter { !core.contains($0) })
                                guard !eliminations.isEmpty else { continue }
                                return Step(
                                    technique: id,
                                    patternCells: core + [lc, bc],
                                    patternCandidates: board.candidateDigits(of: core + [lc, bc]),
                                    eliminations: eliminations,
                                    regions: [Region(house: line), .box(b)],
                                    digits: v.digits
                                )
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}
