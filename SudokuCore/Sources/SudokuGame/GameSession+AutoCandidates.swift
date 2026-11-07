import SudokuCore

extension GameSession {
    public var autoCandidateMode: Bool { autoMode ?? false }

    var removals: [CandidateSet] { removedMarks ?? Array(repeating: .empty, count: 81) }

    /// Turns auto candidate mode on or off. Manual removals are kept either way; turning it on
    /// counts once per game as an assist.
    public mutating func setAutoCandidates(_ on: Bool) {
        autoMode = on
        if on && log.autoCandidates == 0 { log.autoCandidates = 1 }
    }

    /// The candidates shown in every cell: in auto mode all possible candidates (from the digits on
    /// the board and each cage's total) minus manual removals; otherwise the player's own notes.
    /// Filled cells show none.
    public func displayedNotes() -> [CandidateSet] {
        guard autoCandidateMode else { return (0..<81).map { entries[$0] == 0 ? notes[$0] : .empty } }
        var computed = Board(values: entries, cages: puzzle.cages).candidates
        // Killer: also drop digits the cage's total and size rule out (a 2-cell 7 can't hold 7, 8 or 9).
        for cage in puzzle.cages {
            let possible = cage.possibleDigits
            for cell in cage.cells { computed[cell] = computed[cell].intersection(possible) }
        }
        let r = removals
        return (0..<81).map { entries[$0] == 0 ? computed[$0].subtracting(r[$0]) : .empty }
    }

    public func displayedNotes(_ cell: Int) -> CandidateSet { displayedNotes()[cell] }

    /// Records eliminations as removals in auto mode (used by Show me).
    mutating func removeShown(_ eliminations: [CellDigit]) {
        var r = removals
        for cd in eliminations { r[cd.cell].insert(cd.digit) }
        removedMarks = r
    }

    /// The cell's pencil marks leave out its answer: in auto mode the player crossed it out, in manual
    /// mode the marks they wrote don't include it. A real error that Check and hints point out.
    /// (A cell with no marks at all is just un-pencilled.)
    public func ruledOutAnswer(_ cell: Int) -> Bool {
        guard entries[cell] == 0 else { return false }
        let shown = displayedNotes(cell)
        return (autoCandidateMode || !shown.isEmpty) && !shown.contains(puzzle.solution[cell])
    }

    /// Puts a cell's answer back among its pencil marks (undoable): un-crosses it in auto mode, or adds
    /// it to the player's own marks.
    public mutating func restoreAnswerMark(_ cell: Int) {
        guard ruledOutAnswer(cell) else { return }
        record()
        let answer = puzzle.solution[cell]
        if autoCandidateMode {
            var r = removals
            r[cell].remove(answer)
            removedMarks = r
            restore(Snapshot(entries: entries, notes: notes))   // re-filters flags
        } else {
            var n = notes
            n[cell].insert(answer)
            restore(Snapshot(entries: entries, notes: n))
        }
    }

    /// Something Check should flag: a wrong digit, or (auto mode) a removed answer.
    func isFlaggable(_ cell: Int) -> Bool { isWrong(cell) || ruledOutAnswer(cell) }
}
