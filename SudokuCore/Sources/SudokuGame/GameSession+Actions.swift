import SudokuCore

extension GameSession {
    public mutating func undo() {
        guard !isComplete, let previous = undoStack.popLast() else { return }
        redoStack.append(Snapshot(entries: entries, notes: notes))
        restore(previous)
    }

    public mutating func redo() {
        guard !isComplete, let next = redoStack.popLast() else { return }
        undoStack.append(Snapshot(entries: entries, notes: notes))
        restore(next)
    }

    /// Fills every empty cell's notes with its true candidates (an assist).
    public mutating func fillAllCandidates() {
        guard !isComplete else { return }
        record()
        let board = Board(values: entries, cages: puzzle.cages)
        var filled = notes
        for c in 0..<81 { filled[c] = entries[c] == 0 ? board.candidates[c] : .empty }
        restore(Snapshot(entries: entries, notes: filled))
        log.autoCandidates += 1
    }

    /// Flags the selected cell if it's wrong.
    public mutating func checkCell() {
        guard let cell = selected else { return }
        log.checks += 1
        if isWrong(cell) { flag([cell]) }
    }

    /// Flags every wrong cell.
    public mutating func checkPuzzle() {
        log.checks += 1
        flag((0..<81).filter(isWrong))
    }

    /// Fills the selected cell with its solution digit.
    public mutating func revealCell() {
        guard let cell = selected, !isGiven(cell), !isComplete, entries[cell] != puzzle.solution[cell] else { return }
        record()
        var e = entries
        e[cell] = puzzle.solution[cell]
        var n = notes
        n[cell] = .empty
        restore(Snapshot(entries: e, notes: n))
        unflag(cell)
        log.reveals += 1
    }

    /// Advances the clock while the game is running.
    public mutating func tick(_ seconds: Double) {
        guard !isPaused, !isComplete else { return }
        addElapsed(seconds)
    }
}
