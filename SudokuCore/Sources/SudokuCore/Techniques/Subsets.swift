/// N cells in a house whose candidates together are exactly N digits:
/// those digits leave every other cell of the house.
public struct NakedSubset: Technique {
    public let size: Int

    public init(size: Int) {
        precondition((2...4).contains(size), "Subset size must be 2, 3 or 4")
        self.size = size
    }

    public var id: TechniqueID {
        switch size {
        case 2: return .nakedPair
        case 3: return .nakedTriple
        default: return .nakedQuad
        }
    }

    public func find(in board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            let empties = house.filter { board.values[$0] == 0 }
            guard empties.count > size else { continue }
            let pool = empties.filter { (2...size).contains(board.candidates[$0].count) }
            for combo in pool.combinations(of: size) {
                let union = combo.reduce(CandidateSet.empty) { $0.union(board.candidates[$1]) }
                guard union.count == size else { continue }
                var eliminations: [CellDigit] = []
                for c in empties where !combo.contains(c) {
                    for d in board.candidates[c].intersection(union).digits {
                        eliminations.append(CellDigit(cell: c, digit: d))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: combo,
                    patternCandidates: combo.flatMap { c in board.candidates[c].digits.map { CellDigit(cell: c, digit: $0) } },
                    eliminations: eliminations,
                    regions: [Region(house: h)],
                    digits: union.digits
                )
            }
        }
        return nil
    }
}

/// N digits that, within a house, appear only in the same N cells:
/// every other candidate leaves those cells.
public struct HiddenSubset: Technique {
    public let size: Int

    public init(size: Int) {
        precondition((2...4).contains(size), "Subset size must be 2, 3 or 4")
        self.size = size
    }

    public var id: TechniqueID {
        switch size {
        case 2: return .hiddenPair
        case 3: return .hiddenTriple
        default: return .hiddenQuad
        }
    }

    public func find(in board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            let empties = house.filter { board.values[$0] == 0 }
            guard empties.count > size else { continue }
            var positions: [Int: [Int]] = [:]
            for d in 1...9 where !house.contains(where: { board.values[$0] == d }) {
                let cells = empties.filter { board.candidates[$0].contains(d) }
                if (2...size).contains(cells.count) { positions[d] = cells }
            }
            for combo in positions.keys.sorted().combinations(of: size) {
                let cells = Set(combo.flatMap { positions[$0]! }).sorted()
                guard cells.count == size else { continue }
                let digits = CandidateSet(combo)
                var eliminations: [CellDigit] = []
                for c in cells {
                    for d in board.candidates[c].subtracting(digits).digits {
                        eliminations.append(CellDigit(cell: c, digit: d))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: cells,
                    patternCandidates: cells.flatMap { c in
                        combo.filter { board.candidates[c].contains($0) }.map { CellDigit(cell: c, digit: $0) }
                    },
                    eliminations: eliminations,
                    regions: [Region(house: h)],
                    digits: combo
                )
            }
        }
        return nil
    }
}
