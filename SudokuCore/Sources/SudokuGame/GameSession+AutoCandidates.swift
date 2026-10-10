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
    /// the board) minus manual removals; otherwise the player's own notes. Filled cells show none.
    public func displayedNotes() -> [CandidateSet] {
        guard autoCandidateMode else { return (0..<81).map { entries[$0] == 0 ? notes[$0] : .empty } }
        let computed = Board(values: entries, cages: puzzle.cages).candidates
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

    /// In auto candidate mode, the player removed this empty cell's answer by hand — a real error
    /// that Check flags. (The player's own pencil marks are free-form and never count as wrong.)
    public func ruledOutAnswer(_ cell: Int) -> Bool {
        autoCandidateMode && entries[cell] == 0 && !displayedNotes(cell).contains(puzzle.solution[cell])
    }

    /// Something Check should flag: a wrong digit, or (auto mode) a removed answer.
    func isFlaggable(_ cell: Int) -> Bool { isWrong(cell) || ruledOutAnswer(cell) }
}
