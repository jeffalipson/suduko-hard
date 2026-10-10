import SudokuCore

extension GameSession {
    /// Records a hint level for stats: "nudge", "spotlight", "lesson" or "showMe".
    public mutating func useHint(_ level: String) {
        log.hints[level, default: 0] += 1
    }

    /// Applies a hint's step to the board (undoable). Logged as a reveal.
    public mutating func showMe(_ step: Step) {
        record()
        let board = HintEngine.playerBoard(self)
        var e = entries
        var n = notes
        for cd in step.eliminations where e[cd.cell] == 0 {
            if n[cd.cell].isEmpty { n[cd.cell] = board.candidates[cd.cell] }
            n[cd.cell].remove(cd.digit)
        }
        for cd in step.placements {
            e[cd.cell] = cd.digit
            n[cd.cell] = .empty
        }
        restore(Snapshot(entries: e, notes: n))
        log.hints["showMe", default: 0] += 1
        log.reveals += 1
    }
}

extension GameSession {
    /// A display-only session for lesson boards, with the example's candidates as notes.
    public init(lessonPuzzle: Puzzle, notes: [CandidateSet]) {
        self.init(puzzle: lessonPuzzle)
        restore(Snapshot(entries: lessonPuzzle.givens, notes: notes))
    }
}
