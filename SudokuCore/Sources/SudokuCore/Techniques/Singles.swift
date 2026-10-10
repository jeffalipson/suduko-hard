/// A house with exactly one empty cell.
public struct FullHouse: Technique {
    public init() {}
    public var id: TechniqueID { .fullHouse }

    public func find(in board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            let empty = house.filter { board.values[$0] == 0 }
            guard empty.count == 1, let digit = board.candidates[empty[0]].single else { continue }
            return Step(
                technique: id,
                patternCells: house,
                placements: [CellDigit(cell: empty[0], digit: digit)],
                regions: [Region(house: h)],
                digits: [digit]
            )
        }
        return nil
    }
}

/// A cell with exactly one candidate.
public struct NakedSingle: Technique {
    public init() {}
    public var id: TechniqueID { .nakedSingle }

    public func find(in board: Board) -> Step? {
        for c in 0..<81 where board.values[c] == 0 {
            guard let digit = board.candidates[c].single else { continue }
            return Step(
                technique: id,
                patternCells: [c],
                placements: [CellDigit(cell: c, digit: digit)],
                digits: [digit]
            )
        }
        return nil
    }
}

/// A digit with exactly one possible cell in a house.
public struct HiddenSingle: Technique {
    public init() {}
    public var id: TechniqueID { .hiddenSingle }

    public func find(in board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            for digit in 1...9 {
                var spot = -1
                var n = 0
                for c in house where board.values[c] == 0 && board.candidates[c].contains(digit) {
                    spot = c
                    n += 1
                }
                guard n == 1 else { continue }
                return Step(
                    technique: id,
                    patternCells: house,
                    placements: [CellDigit(cell: spot, digit: digit)],
                    regions: [Region(house: h)],
                    digits: [digit]
                )
            }
        }
        return nil
    }
}
