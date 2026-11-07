import SudokuCore

public enum MistakeKind: Equatable, Sendable {
    /// A placed digit that isn't the cell's answer.
    case wrongDigit
    /// In auto candidate mode, the player crossed out the cell's answer.
    case removedAnswer
}

public enum HintDiagnosis: Equatable, Sendable {
    case solved
    /// Something Check would flag: the first such cell and what's wrong with it.
    case mistake(cell: Int, kind: MistakeKind)
    /// The next step needs pencil marks the player hasn't made yet, in this house.
    case incomplete(Region)
    /// The next step needs pencil marks the player hasn't made yet, in this cage.
    case incompleteCage(Cage)
    case step(Step)
    /// Nothing in the catalog applies (beyond Nightmare).
    case beyond

    public var isMistake: Bool {
        if case .mistake = self { return true }
        return false
    }
}

public enum HintEngine {
    static let singles: Set<TechniqueID> = [.fullHouse, .nakedSingle, .hiddenSingle, .cageCompletion]

    public static func diagnose(_ session: GameSession) -> HintDiagnosis {
        if session.isComplete { return .solved }
        for c in 0..<81 where session.entries[c] != 0 && session.isWrong(c) { return .mistake(cell: c, kind: .wrongDigit) }
        // Only what Check can find counts as a mistake: wrong digits, and answers crossed out in Auto Pencil.
        for c in 0..<81 where session.ruledOutAnswer(c) { return .mistake(cell: c, kind: .removedAnswer) }
        let shown = usableNotes(session)
        let board = playerBoard(session)
        let solver: LogicalSolver = session.puzzle.mode == .classic ? .classic : .killer
        guard let step = solver.nextStep(on: board) else { return .beyond }
        func bareCell(of s: Step) -> Int? {
            guard !singles.contains(s.technique) else { return nil }
            // The pattern must be visible in the player's notes; eliminations can land on bare cells
            // (Show me fills them in), so they don't need notes.
            let pattern = s.patternCells + s.patternCandidates.map(\.cell)
            return pattern.first { session.entries[$0] == 0 && shown[$0].isEmpty }
        }
        // A step whose only effect lands on cells the player hasn't pencilled shows them nothing to do;
        // prefer one of the same difficulty they can act on, if there is one.
        func visibleEffect(_ s: Step) -> Bool {
            !s.placements.isEmpty || s.eliminations.contains { session.entries[$0.cell] == 0 && !shown[$0.cell].isEmpty }
        }
        guard let bare = bareCell(of: step) else {
            if !visibleEffect(step),
               let better = visibleStep(session, board: board, shown: shown, solver: solver, upTo: step.technique.tier, needsVisibleEffect: true) {
                return .step(better)
            }
            return .step(step)
        }

        // The easiest step runs through cells the player hasn't pencilled. Before asking for more
        // marks, look for a step of the same difficulty in the part they have pencilled.
        if let visible = visibleStep(session, board: board, shown: shown, solver: solver, upTo: step.technique.tier),
           bareCell(of: visible) == nil {
            return .step(visible)
        }
        // Name the cage when the step is about one, else a house that contains the bare cell.
        if let cage = session.puzzle.cages.first(where: { Set($0.cells) == Set(step.patternCells) }) {
            return .incompleteCage(cage)
        }
        return .incomplete(step.regions.first { $0.cells.contains(bare) } ?? .box(Geometry.box(bare)))
    }

    /// The first step whose pattern lies entirely in pencilled cells, no harder than `tier`. Bare cells
    /// start with every digit, so no pattern forms through them by accident. Steps that do run through
    /// bare cells are skipped by applying their (answer-checked) effects to those bare cells only, so the
    /// search moves on; pencilled cells keep exactly what the player sees. The step returned is checked
    /// against the answer and trimmed to eliminations that are real on the player's board.
    static func visibleStep(_ session: GameSession, board: Board, shown: [CandidateSet], solver: LogicalSolver, upTo tier: Tier,
                             needsVisibleEffect: Bool = false) -> Step? {
        let bare = Set((0..<81).filter { session.entries[$0] == 0 && shown[$0].isEmpty })
        let solution = session.puzzle.solution
        var masked = board
        for c in bare { masked.candidates[c] = .all }
        for _ in 0..<60 {
            guard let s = solver.nextStep(on: masked), s.technique.tier <= tier else { return nil }
            let touched = s.patternCells + s.patternCandidates.map(\.cell) + s.placements.map(\.cell)
            let sound = s.placements.allSatisfy { solution[$0.cell] == $0.digit }
                && s.eliminations.allSatisfy { solution[$0.cell] != $0.digit }
            if sound && !touched.contains(where: bare.contains) {
                let eliminations = s.eliminations.filter { board.candidates[$0.cell].contains($0.digit) }
                let seen = !s.placements.isEmpty || eliminations.contains { !bare.contains($0.cell) }
                if (!eliminations.isEmpty || !s.placements.isEmpty) && (seen || !needsVisibleEffect) {
                    return Step(technique: s.technique, patternCells: s.patternCells, patternCandidates: s.patternCandidates,
                                placements: s.placements, eliminations: eliminations, regions: s.regions, digits: s.digits, groups: s.groups)
                }
            }
            // Skip it: apply what's true of it to bare cells only.
            var progressed = false
            for e in s.eliminations where bare.contains(e.cell) && solution[e.cell] != e.digit && masked.candidates[e.cell].contains(e.digit) {
                masked.candidates[e.cell].remove(e.digit)
                progressed = true
            }
            for p in s.placements where bare.contains(p.cell) && solution[p.cell] == p.digit && masked.candidates[p.cell] != CandidateSet([p.digit]) {
                masked.candidates[p.cell] = CandidateSet([p.digit])
                progressed = true
            }
            if !progressed { return nil }
        }
        return nil
    }

    /// The player's position: their digits, and their notes (minus stale digits) where they made any.
    public static func playerBoard(_ session: GameSession) -> Board {
        var board = Board(values: session.entries, cages: session.puzzle.cages)
        let shown = usableNotes(session)
        for c in 0..<81 where session.entries[c] == 0 && !shown[c].isEmpty {
            board.candidates[c] = shown[c].intersection(board.candidates[c])
        }
        return board
    }

    /// The candidates the hint may build on. Hand-made marks are free-form (partial or "Snyder" marks
    /// are common), so marks that leave out a cell's answer are set aside rather than treated as a
    /// mistake; that cell then counts as un-pencilled, and a hint that needs it asks for every candidate.
    static func usableNotes(_ session: GameSession) -> [CandidateSet] {
        let shown = session.displayedNotes()
        guard !session.autoCandidateMode else { return shown }
        return (0..<81).map { c in shown[c].contains(session.puzzle.solution[c]) ? shown[c] : .empty }
    }
}
