/// A digit confined to one row/column inside a box: remove it from the rest of that line.
public struct Pointing: Technique {
    public init() {}
    public var id: TechniqueID { .pointing }

    public func find(in board: Board) -> Step? {
        for b in 0..<9 {
            for digit in 1...9 {
                let cells = Geometry.boxes[b].filter { board.values[$0] == 0 && board.candidates[$0].contains(digit) }
                guard cells.count >= 2, !Geometry.boxes[b].contains(where: { board.values[$0] == digit }) else { continue }
                let line: Int
                if Set(cells.map(Geometry.row)).count == 1 {
                    line = Geometry.row(cells[0])
                } else if Set(cells.map(Geometry.col)).count == 1 {
                    line = 9 + Geometry.col(cells[0])
                } else {
                    continue
                }
                let eliminations = Geometry.houses[line]
                    .filter { Geometry.box($0) != b && board.values[$0] == 0 && board.candidates[$0].contains(digit) }
                    .map { CellDigit(cell: $0, digit: digit) }
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: cells,
                    patternCandidates: cells.map { CellDigit(cell: $0, digit: digit) },
                    eliminations: eliminations,
                    regions: [.box(b), Region(house: line)],
                    digits: [digit]
                )
            }
        }
        return nil
    }
}

/// A digit confined to one box inside a row/column: remove it from the rest of that box.
public struct BoxLineReduction: Technique {
    public init() {}
    public var id: TechniqueID { .boxLineReduction }

    public func find(in board: Board) -> Step? {
        for line in 0..<18 {
            let house = Geometry.houses[line]
            for digit in 1...9 {
                let cells = house.filter { board.values[$0] == 0 && board.candidates[$0].contains(digit) }
                guard cells.count >= 2, !house.contains(where: { board.values[$0] == digit }) else { continue }
                let b = Geometry.box(cells[0])
                guard cells.allSatisfy({ Geometry.box($0) == b }) else { continue }
                let eliminations = Geometry.boxes[b]
                    .filter { !house.contains($0) && board.values[$0] == 0 && board.candidates[$0].contains(digit) }
                    .map { CellDigit(cell: $0, digit: digit) }
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: cells,
                    patternCandidates: cells.map { CellDigit(cell: $0, digit: digit) },
                    eliminations: eliminations,
                    regions: [Region(house: line), .box(b)],
                    digits: [digit]
                )
            }
        }
        return nil
    }
}
