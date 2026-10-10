/// Avoids the "deadly pattern": four unsolved cells in two rows, two columns and two boxes
/// that could swap a and b would give the puzzle two solutions, which a valid puzzle can't have.
public struct UniqueRectangle: Technique {
    public let type: Int

    public init(type: Int) {
        precondition((1...4).contains(type), "Unique rectangle type must be 1–4")
        self.type = type
    }

    public var id: TechniqueID {
        [TechniqueID.uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle3, .uniqueRectangle4][type - 1]
    }

    public func find(in board: Board) -> Step? {
        for rows in Array(0..<9).combinations(of: 2) {
            for cols in Array(0..<9).combinations(of: 2) {
                let corners = [
                    Geometry.cell(rows[0], cols[0]), Geometry.cell(rows[0], cols[1]),
                    Geometry.cell(rows[1], cols[0]), Geometry.cell(rows[1], cols[1]),
                ]
                guard Set(corners.map(Geometry.box)).count == 2,
                      corners.allSatisfy({ board.values[$0] == 0 }) else { continue }
                let common = corners.reduce(CandidateSet.all) { $0.intersection(board.candidates[$1]) }
                for pair in common.digits.combinations(of: 2) {
                    let ab = CandidateSet(pair)
                    let regions: [Region] = [.row(rows[0]), .row(rows[1]), .column(cols[0]), .column(cols[1])]
                    if let step = step(board: board, corners: corners, ab: ab, regions: regions) { return step }
                }
            }
        }
        return nil
    }

    private func step(board: Board, corners: [Int], ab: CandidateSet, regions: [Region]) -> Step? {
        let floor = corners.filter { board.candidates[$0] == ab }
        let roof = corners.filter { board.candidates[$0] != ab }

        func make(_ eliminations: [CellDigit], extraRegions: [Region] = [], groups: [[CellDigit]] = [], extraDigits: [Int] = []) -> Step? {
            guard !eliminations.isEmpty else { return nil }
            return Step(
                technique: id,
                patternCells: corners,
                patternCandidates: corners.flatMap { c in ab.digits.map { CellDigit(cell: c, digit: $0) } },
                eliminations: eliminations,
                regions: regions + extraRegions,
                digits: ab.digits + extraDigits,
                groups: groups
            )
        }

        if type == 1 {
            guard floor.count == 3 else { return nil }
            return make(ab.digits.map { CellDigit(cell: roof[0], digit: $0) })
        }

        guard floor.count == 2,
              Geometry.row(floor[0]) == Geometry.row(floor[1]) || Geometry.col(floor[0]) == Geometry.col(floor[1])
        else { return nil }
        let extras = roof.reduce(CandidateSet.empty) { $0.union(board.candidates[$1].subtracting(ab)) }
        let sharedHouses = Geometry.houses.indices.filter { h in roof.allSatisfy { Geometry.houses[h].contains($0) } }

        switch type {
        case 2:
            guard let z = extras.single else { return nil }
            return make(board.eliminations(of: z, seeingAll: roof, excluding: corners), extraDigits: [z])
        case 3:
            for h in sharedHouses {
                let others = Geometry.houses[h].filter { board.values[$0] == 0 && !roof.contains($0) }
                for k in 1...3 {
                    for combo in others.combinations(of: k) {
                        let union = combo.reduce(extras) { $0.union(board.candidates[$1]) }
                        guard union.count == k + 1 else { continue }
                        let eliminations = others.filter { !combo.contains($0) }.flatMap { c in
                            board.candidates[c].intersection(union).digits.map { CellDigit(cell: c, digit: $0) }
                        }
                        if let step = make(eliminations, extraRegions: [Region(house: h)], groups: [board.candidateDigits(of: combo)]) {
                            return step
                        }
                    }
                }
            }
            return nil
        default:
            let (a, b) = (ab.digits[0], ab.digits[1])
            for h in sharedHouses {
                for (kept, removed) in [(a, b), (b, a)] where Set(board.cells(with: kept, in: Geometry.houses[h])) == Set(roof) {
                    if let step = make(roof.map { CellDigit(cell: $0, digit: removed) }, extraRegions: [Region(house: h)]) { return step }
                }
            }
            return nil
        }
    }
}
