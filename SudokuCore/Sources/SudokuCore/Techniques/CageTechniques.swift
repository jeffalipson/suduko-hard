/// A cage with one empty cell: it takes whatever the sum still needs.
public struct CageCompletion: Technique {
    public init() {}
    public var id: TechniqueID { .cageCompletion }

    public func find(in board: Board) -> Step? {
        for cage in board.cages {
            let s = CageMath.state(of: cage, on: board)
            guard s.empties.count == 1, (1...9).contains(s.sumLeft), board.has(s.sumLeft, at: s.empties[0]) else { continue }
            return Step(technique: id, patternCells: cage.cells, placements: [CellDigit(cell: s.empties[0], digit: s.sumLeft)], digits: [s.sumLeft])
        }
        return nil
    }
}

/// A cage whose sum and size allow only one set of digits (e.g. 3 in two cells = 1+2).
public struct UniqueCageCombination: Technique {
    public init() {}
    public var id: TechniqueID { .uniqueCageCombination }

    public func find(in board: Board) -> Step? {
        for cage in board.cages {
            let s = CageMath.state(of: cage, on: board)
            guard s.empties.count >= 2 else { continue }
            let combos = CageMath.combinations(sum: s.sumLeft, count: s.empties.count, allowed: s.allowed)
            guard combos.count == 1 else { continue }
            let eliminations = s.empties.flatMap { c in
                board.candidates[c].subtracting(combos[0]).digits.map { CellDigit(cell: c, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            return Step(technique: id, patternCells: cage.cells, eliminations: eliminations, digits: combos[0].digits)
        }
        return nil
    }
}

/// Keeps only digits that appear in some way of filling the cage that fits the candidates.
public struct CageCombination: Technique {
    public init() {}
    public var id: TechniqueID { .cageCombination }

    public func find(in board: Board) -> Step? {
        for cage in board.cages {
            let s = CageMath.state(of: cage, on: board)
            guard s.empties.count >= 2 else { continue }
            let possible: [CandidateSet]
            if s.empties.count <= 5 {
                possible = CageMath.possibilities(of: s.empties, sum: s.sumLeft, on: board) { _, _ in true }
            } else {
                // Large cages: digit-level filtering keeps the search small.
                let union = CageMath.combinations(sum: s.sumLeft, count: s.empties.count, allowed: s.allowed)
                    .filter { combo in combo.digits.allSatisfy { d in s.empties.contains { board.candidates[$0].contains(d) } } }
                    .reduce(CandidateSet.empty) { $0.union($1) }
                possible = s.empties.map { _ in union }
            }
            let eliminations = zip(s.empties, possible).flatMap { c, ok in
                board.candidates[c].subtracting(ok).digits.map { CellDigit(cell: c, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            return Step(technique: id, patternCells: cage.cells, patternCandidates: board.candidateDigits(of: s.empties),
                        eliminations: eliminations)
        }
        return nil
    }
}

/// A digit every possible combination of a cage needs, whose places in the cage all lie in one
/// house: it leaves the rest of that house (a killer pair is the two-digit case).
public struct CageLockedDigit: Technique {
    public init() {}
    public var id: TechniqueID { .cageLockedDigit }

    public func find(in board: Board) -> Step? {
        for cage in board.cages {
            let s = CageMath.state(of: cage, on: board)
            guard s.empties.count >= 2 else { continue }
            let combos = CageMath.combinations(sum: s.sumLeft, count: s.empties.count, allowed: s.allowed)
                .filter { combo in combo.digits.allSatisfy { d in s.empties.contains { board.candidates[$0].contains(d) } } }
            guard let first = combos.first else { continue }
            let required = combos.reduce(first) { $0.intersection($1) }
            for d in required.digits {
                let hosts = s.empties.filter { board.candidates[$0].contains(d) }
                guard !hosts.isEmpty else { continue }
                let houses = Geometry.houses.indices.filter { h in hosts.allSatisfy { Geometry.houses[h].contains($0) } }
                var eliminations: [CellDigit] = []
                for h in houses {
                    for c in Geometry.houses[h] where !cage.cells.contains(c) && board.has(d, at: c) {
                        let cd = CellDigit(cell: c, digit: d)
                        if !eliminations.contains(cd) { eliminations.append(cd) }
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return Step(technique: id, patternCells: cage.cells, patternCandidates: hosts.map { CellDigit(cell: $0, digit: d) },
                            eliminations: eliminations, regions: houses.map(Region.init(house:)), digits: [d])
            }
        }
        return nil
    }
}
