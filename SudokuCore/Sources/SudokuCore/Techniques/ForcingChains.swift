enum Propagation {
    /// Spelled out (not derived from the catalog) to avoid circular static initialisation.
    static let singles: [any Technique] = [FullHouse(), NakedSingle(), HiddenSingle()]
    /// No uniqueness techniques: they're invalid under a hypothetical assumption.
    static let basic: [any Technique] = singles + [
        Pointing(), BoxLineReduction(),
        NakedSubset(size: 2), HiddenSubset(size: 2),
        NakedSubset(size: 3), HiddenSubset(size: 3),
    ]

    /// Applies `change`, then `techniques` until stuck. Nil when the board becomes contradictory.
    static func run(_ board: Board, techniques: [any Technique], maxSteps: Int = 300, change: (inout Board) -> Void) -> Board? {
        var b = board
        change(&b)
        let solver = LogicalSolver(techniques: techniques)
        for _ in 0..<maxSteps {
            if b.isContradictory { return nil }
            guard let step = solver.nextStep(on: b) else { return b }
            b.apply(step)
        }
        return b.isContradictory ? nil : b
    }
}

public struct ForcingChain: Technique {
    enum Kind: Sendable { case digit, cell, unit }

    public let id: TechniqueID
    let kinds: [Kind]
    let propagation: [any Technique]

    public static let cell = ForcingChain(id: .cellForcingChain, kinds: [.cell], propagation: Propagation.singles)
    public static let unit = ForcingChain(id: .unitForcingChain, kinds: [.unit], propagation: Propagation.singles)
    public static let digit = ForcingChain(id: .digitForcingChain, kinds: [.digit], propagation: Propagation.singles)
    public static let nested = ForcingChain(id: .nestedForcingChain, kinds: [.digit, .cell, .unit], propagation: Propagation.basic)

    public func find(in board: Board) -> Step? {
        for kind in kinds {
            let step: Step?
            switch kind {
            case .digit: step = digitForcing(board)
            case .cell: step = cellForcing(board)
            case .unit: step = unitForcing(board)
            }
            if let step { return step }
        }
        return nil
    }

    private func assume(_ board: Board, _ digit: Int, at cell: Int) -> Board? {
        Propagation.run(board, techniques: propagation) { $0.place(digit, at: cell) }
    }

    private func cellForcing(_ board: Board) -> Step? {
        for c in 0..<81 where board.values[c] == 0 && (2...4).contains(board.candidates[c].count) {
            let digits = board.candidates[c].digits
            let branches = digits.compactMap { assume(board, $0, at: c) }
            if let step = common(board, branches, pattern: digits.map { CellDigit(cell: c, digit: $0) }) { return step }
        }
        return nil
    }

    private func unitForcing(_ board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            for d in 1...9 {
                let spots = board.cells(with: d, in: house)
                guard (2...4).contains(spots.count) else { continue }
                let branches = spots.compactMap { assume(board, d, at: $0) }
                if var step = common(board, branches, pattern: spots.map { CellDigit(cell: $0, digit: d) }) {
                    step = Step(
                        technique: step.technique, patternCells: step.patternCells, patternCandidates: step.patternCandidates,
                        placements: step.placements, eliminations: step.eliminations, regions: [Region(house: h)], digits: [d]
                    )
                    return step
                }
            }
        }
        return nil
    }

    private func digitForcing(_ board: Board) -> Step? {
        for c in 0..<81 where board.values[c] == 0 {
            for d in board.candidates[c].digits {
                let pattern = [CellDigit(cell: c, digit: d)]
                let ifTrue = assume(board, d, at: c)
                let ifFalse = Propagation.run(board, techniques: propagation) { $0.eliminate(d, at: c) }
                switch (ifTrue, ifFalse) {
                case (nil, nil):
                    continue
                case (nil, _):
                    return Step(technique: id, patternCells: [c], patternCandidates: pattern, eliminations: pattern, digits: [d])
                case (_, nil):
                    return Step(technique: id, patternCells: [c], patternCandidates: pattern, placements: pattern, digits: [d])
                case let (t?, f?):
                    if let step = common(board, [t, f], pattern: pattern) { return step }
                }
            }
        }
        return nil
    }

    /// The first conclusion shared by every branch: a placement, else one cell's eliminations.
    private func common(_ board: Board, _ branches: [Board], pattern: [CellDigit]) -> Step? {
        guard !branches.isEmpty else { return nil }
        let patternCells = Array(Set(pattern.map(\.cell))).sorted()
        let digits = Set(pattern.map(\.digit)).sorted()
        for c in 0..<81 where board.values[c] == 0 {
            let v = branches[0].values[c]
            if v != 0 && branches.allSatisfy({ $0.values[c] == v }) {
                return Step(technique: id, patternCells: patternCells, patternCandidates: pattern,
                            placements: [CellDigit(cell: c, digit: v)], digits: digits)
            }
        }
        for c in 0..<81 where board.values[c] == 0 {
            let gone = board.candidates[c].digits.filter { d in
                branches.allSatisfy { b in b.values[c] != 0 ? b.values[c] != d : !b.candidates[c].contains(d) }
            }
            if !gone.isEmpty {
                return Step(technique: id, patternCells: patternCells, patternCandidates: pattern,
                            eliminations: gone.map { CellDigit(cell: c, digit: $0) }, digits: digits)
            }
        }
        return nil
    }
}

extension ForcingChain {
    /// What follows from assuming `candidate` true (or false), step by step with this chain's
    /// propagation, stopping once `target` holds. `contradiction` is true if the grid breaks.
    /// Used to explain a forcing-chain step branch by branch.
    public func trace(_ board: Board, assuming candidate: CellDigit, isTrue: Bool,
                      until target: (Board) -> Bool) -> (steps: [Step], contradiction: Bool) {
        var b = board
        if isTrue { b.place(candidate.digit, at: candidate.cell) } else { b.eliminate(candidate.digit, at: candidate.cell) }
        let solver = LogicalSolver(techniques: propagation)
        var steps: [Step] = []
        for _ in 0..<300 {
            if b.isContradictory { return (steps, true) }
            if target(b) { return (steps, false) }
            guard let step = solver.nextStep(on: b) else { break }
            b.apply(step)
            steps.append(step)
        }
        return (steps, b.isContradictory)
    }

    /// The forcing chain behind a technique ID, if it is one.
    public static func named(_ id: TechniqueID) -> ForcingChain? {
        [ForcingChain.cell, .unit, .digit, .nested].first { $0.id == id }
    }
}
