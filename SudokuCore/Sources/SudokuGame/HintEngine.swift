import SudokuCore

public enum HintDiagnosis: Equatable, Sendable {
    case solved
    /// A wrong digit, or notes that leave out a cell's answer.
    case mistake
    /// The next step needs pencil marks the player hasn't made yet.
    case incomplete(Region)
    case step(Step)
    /// Nothing in the catalog applies (beyond Nightmare).
    case beyond
}

public enum HintEngine {
    static let singles: Set<TechniqueID> = [.fullHouse, .nakedSingle, .hiddenSingle, .cageCompletion]

    public static func diagnose(_ session: GameSession) -> HintDiagnosis {
        if session.isComplete { return .solved }
        for c in 0..<81 where session.entries[c] != 0 && session.isWrong(c) { return .mistake }
        for c in 0..<81 where session.entries[c] == 0 && !session.notes[c].isEmpty {
            if !session.notes[c].contains(session.puzzle.solution[c]) { return .mistake }
        }
        let board = playerBoard(session)
        let solver: LogicalSolver = session.puzzle.mode == .classic ? .classic : .killer
        guard let step = solver.nextStep(on: board) else { return .beyond }
        if !singles.contains(step.technique) {
            // The pattern must be visible in the player's notes; eliminations can land on bare cells
            // (Show me fills them in), so they don't need notes.
            let pattern = step.patternCells + step.patternCandidates.map(\.cell)
            if let bare = pattern.first(where: { session.entries[$0] == 0 && session.notes[$0].isEmpty }) {
                // Name a region that actually contains the bare cell, so filling it in makes progress.
                return .incomplete(step.regions.first { $0.cells.contains(bare) } ?? .box(Geometry.box(bare)))
            }
        }
        return .step(step)
    }

    /// The player's position: their digits, and their notes (minus stale digits) where they made any.
    public static func playerBoard(_ session: GameSession) -> Board {
        var board = Board(values: session.entries, cages: session.puzzle.cages)
        for c in 0..<81 where session.entries[c] == 0 && !session.notes[c].isEmpty {
            board.candidates[c] = session.notes[c].intersection(board.candidates[c])
        }
        return board
    }
}
