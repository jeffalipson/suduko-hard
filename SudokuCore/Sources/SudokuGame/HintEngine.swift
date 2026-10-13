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
    /// The next step needs pencil marks the player hasn't made yet.
    case incomplete(Region)
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
        // Only what Check can find counts as a mistake: wrong digits, and answers removed in auto mode.
        for c in 0..<81 where session.ruledOutAnswer(c) { return .mistake(cell: c, kind: .removedAnswer) }
        let shown = usableNotes(session)
        let board = playerBoard(session)
        let solver: LogicalSolver = session.puzzle.mode == .classic ? .classic : .killer
        guard let step = solver.nextStep(on: board) else { return .beyond }
        if !singles.contains(step.technique) {
            // The pattern must be visible in the player's notes; eliminations can land on bare cells
            // (Show me fills them in), so they don't need notes.
            let pattern = step.patternCells + step.patternCandidates.map(\.cell)
            if let bare = pattern.first(where: { session.entries[$0] == 0 && shown[$0].isEmpty }) {
                // Name a region that actually contains the bare cell, so filling it in makes progress.
                return .incomplete(step.regions.first { $0.cells.contains(bare) } ?? .box(Geometry.box(bare)))
            }
        }
        return .step(step)
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

    /// The candidates the hint may build on. The player's own pencil marks are free-form (partial
    /// or "Snyder" marks are common), so marks that leave out a cell's answer are set aside rather
    /// than treated as a mistake; that cell then counts as un-pencilled.
    static func usableNotes(_ session: GameSession) -> [CandidateSet] {
        let shown = session.displayedNotes()
        guard !session.autoCandidateMode else { return shown }
        return (0..<81).map { c in shown[c].contains(session.puzzle.solution[c]) ? shown[c] : .empty }
    }
}
