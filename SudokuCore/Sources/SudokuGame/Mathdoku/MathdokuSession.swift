import Foundation
import SudokuCore

/// A Mathdoku game in progress: the same play model as `GameSession` (digits, notes, Auto Pencil,
/// colours, undo, check, reveal, hints), on an n×n grid without boxes.
public struct MathdokuSession: Codable, Equatable, Sendable {
    struct Snapshot: Codable, Equatable, Sendable {
        let entries: [Int]
        let notes: [CandidateSet]
        var removed: [CandidateSet]? = nil
        var colors: [Int]? = nil
    }

    public let puzzle: MathdokuPuzzle
    public private(set) var entries: [Int]
    public private(set) var notes: [CandidateSet]
    public var selected: Int?
    public var inputMode: InputMode = .normal
    public private(set) var elapsed: Double = 0
    public private(set) var isPaused = false
    public internal(set) var log = AssistLog()
    public private(set) var flaggedWrong: Set<Int> = []
    public private(set) var startedAt: Date?
    var autoMode: Bool?
    var removedMarks: [CandidateSet]?
    var cellColors: [Int]?
    var undoStack: [Snapshot] = []
    var redoStack: [Snapshot] = []

    public init(puzzle: MathdokuPuzzle) {
        self.puzzle = puzzle
        self.entries = MathdokuBoard(puzzle: puzzle).values
        self.notes = Array(repeating: .empty, count: puzzle.cellCount)
        self.startedAt = Date()
    }

    public var n: Int { puzzle.n }
    public var cellCount: Int { puzzle.cellCount }
    public func isGiven(_ cell: Int) -> Bool { puzzle.cages[cageIndex(of: cell)].op == .given }
    public func isWrong(_ cell: Int) -> Bool { entries[cell] != 0 && entries[cell] != puzzle.solution[cell] }
    public var isComplete: Bool { entries == puzzle.solution }
    public func placedCount(of digit: Int) -> Int { entries.filter { $0 == digit }.count }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public func cageIndex(of cell: Int) -> Int { puzzle.cageIndex[cell] }

    // MARK: Entry

    /// Normal mode places (or clears, if repeated) a digit; candidate mode toggles a note.
    public mutating func input(_ digit: Int, settings: GameSettings) {
        guard let cell = selected, (1...n).contains(digit), !isGiven(cell), !isComplete else { return }
        switch inputMode {
        case .normal:
            record()
            if entries[cell] == digit {
                entries[cell] = 0
            } else {
                entries[cell] = digit
                notes[cell] = .empty
                if settings.mistakeHighlighting { log.highlightingUsed = true }
                if settings.mistakeHighlighting && digit != puzzle.solution[cell] { log.mistakes += 1 }
                if settings.autoRemoveCandidates { removeNote(digit, around: cell) }
            }
            flaggedWrong.remove(cell)
        case .candidate:
            guard entries[cell] == 0 else { return }
            record()
            if autoCandidateMode {
                var r = removals
                if r[cell].contains(digit) { r[cell].remove(digit) } else { r[cell].insert(digit) }
                removedMarks = r
                if !isFlaggable(cell) { flaggedWrong.remove(cell) }
            } else if notes[cell].contains(digit) {
                notes[cell].remove(digit)
            } else {
                notes[cell].insert(digit)
            }
        }
    }

    public mutating func erase() {
        guard let cell = selected, !isGiven(cell), !isComplete, entries[cell] != 0 || !notes[cell].isEmpty else { return }
        record()
        if entries[cell] != 0 { entries[cell] = 0 } else { notes[cell] = .empty }
        flaggedWrong.remove(cell)
    }

    /// Clears `digit` from the notes of the cell's row and column. (Not its cage: a cage may repeat a
    /// digit across rows and columns.)
    mutating func removeNote(_ digit: Int, around cell: Int) {
        let board = MathdokuBoard(n: n, cages: [], values: Array(repeating: 0, count: cellCount))
        for p in board.peers(of: cell) { notes[p].remove(digit) }
    }

    public mutating func undo() {
        guard !isComplete, let previous = undoStack.popLast() else { return }
        redoStack.append(Snapshot(entries: entries, notes: notes, removed: removals, colors: cellColors ?? []))
        restore(previous)
    }

    public mutating func redo() {
        guard !isComplete, let next = redoStack.popLast() else { return }
        undoStack.append(Snapshot(entries: entries, notes: notes, removed: removals, colors: cellColors ?? []))
        restore(next)
    }

    mutating func record() {
        undoStack.append(Snapshot(entries: entries, notes: notes, removed: removals, colors: cellColors ?? []))
        redoStack.removeAll()
    }

    mutating func restore(_ s: Snapshot) {
        entries = s.entries
        notes = s.notes
        if let r = s.removed { removedMarks = r }
        if let c = s.colors { cellColors = c }
        flaggedWrong = flaggedWrong.filter(isFlaggable)
    }

    // MARK: Checking

    public mutating func checkCell() {
        guard let cell = selected else { return }
        log.checks += 1
        if isFlaggable(cell) { flaggedWrong.insert(cell) }
    }

    public mutating func checkPuzzle() {
        log.checks += 1
        flaggedWrong.formUnion((0..<cellCount).filter(isFlaggable))
    }

    public mutating func revealCell(settings: GameSettings) {
        guard let cell = selected, !isGiven(cell), !isComplete, entries[cell] != puzzle.solution[cell] else { return }
        record()
        entries[cell] = puzzle.solution[cell]
        notes[cell] = .empty
        if settings.autoRemoveCandidates { removeNote(puzzle.solution[cell], around: cell) }
        flaggedWrong.remove(cell)
        log.reveals += 1
    }

    /// The exact cell of a mistake hint: the same as a Check.
    public mutating func pointOutMistake(_ cell: Int) {
        log.checks += 1
        flaggedWrong.insert(cell)
    }

    // MARK: Clock

    public mutating func tick(_ seconds: Double) {
        guard !isPaused, !isComplete else { return }
        elapsed += seconds
    }

    public mutating func setPaused(_ paused: Bool) { isPaused = paused }

    public mutating func moveSelection(rows: Int, columns: Int) {
        guard let cell = selected else { selected = 0; return }
        let r = min(n - 1, max(0, cell / n + rows))
        let c = min(n - 1, max(0, cell % n + columns))
        selected = r * n + c
    }

    // MARK: Auto Pencil

    public var autoCandidateMode: Bool { autoMode ?? false }
    var removals: [CandidateSet] { removedMarks ?? Array(repeating: .empty, count: cellCount) }

    public mutating func setAutoCandidates(_ on: Bool) {
        autoMode = on
        if on && log.autoCandidates == 0 { log.autoCandidates = 1 }
    }

    /// In auto mode: digits not already in the cell's row or column that the cage's arithmetic allows,
    /// minus the player's removals. Otherwise the player's own notes.
    public func displayedNotes() -> [CandidateSet] {
        guard autoCandidateMode else { return (0..<cellCount).map { entries[$0] == 0 ? notes[$0] : .empty } }
        var computed = MathdokuBoard(n: n, cages: puzzle.cages, values: entries).candidates
        for cage in puzzle.cages {
            let possible = cage.possibleDigits(n: n)
            for cell in cage.cells { computed[cell] = computed[cell].intersection(possible) }
        }
        let r = removals
        return (0..<cellCount).map { entries[$0] == 0 ? computed[$0].subtracting(r[$0]) : .empty }
    }

    public func displayedNotes(_ cell: Int) -> CandidateSet { displayedNotes()[cell] }

    /// In auto mode, the player removed this empty cell's answer by hand.
    public func ruledOutAnswer(_ cell: Int) -> Bool {
        autoCandidateMode && entries[cell] == 0 && !displayedNotes(cell).contains(puzzle.solution[cell])
    }

    func isFlaggable(_ cell: Int) -> Bool { isWrong(cell) || ruledOutAnswer(cell) }

    // MARK: Colours

    public func color(of cell: Int) -> Int {
        guard let c = cellColors, c.indices.contains(cell) else { return 0 }
        return c[cell]
    }

    public var hasColors: Bool { cellColors?.contains { $0 != 0 } ?? false }

    public mutating func setColor(_ color: Int, at cell: Int) {
        guard (0...GameSession.colorCount).contains(color), (0..<cellCount).contains(cell) else { return }
        let next = self.color(of: cell) == color ? 0 : color
        guard next != self.color(of: cell) else { return }
        record()
        var c = cellColors.flatMap { $0.isEmpty ? nil : $0 } ?? Array(repeating: 0, count: cellCount)
        c[cell] = next
        cellColors = c
    }

    public mutating func clearColors() {
        guard hasColors else { return }
        record()
        cellColors = Array(repeating: 0, count: cellCount)
    }

    // MARK: Hints

    public mutating func useHint(_ level: String) { log.hints[level, default: 0] += 1 }

    /// Applies a hint's step (undoable); counts as a reveal.
    public mutating func showMe(_ step: MathStep) {
        record()
        let board = MathdokuHintEngine.playerBoard(self)
        for cd in step.eliminations where entries[cd.cell] == 0 && !autoCandidateMode {
            if notes[cd.cell].isEmpty { notes[cd.cell] = board.candidates[cd.cell] }
            notes[cd.cell].remove(cd.digit)
        }
        if autoCandidateMode {
            var r = removals
            for cd in step.eliminations { r[cd.cell].insert(cd.digit) }
            removedMarks = r
        }
        for cd in step.placements {
            entries[cd.cell] = cd.digit
            notes[cd.cell] = .empty
            removeNote(cd.digit, around: cd.cell)
        }
        log.hints["showMe", default: 0] += 1
        log.reveals += 1
    }

    // MARK: VoiceOver

    public func spokenDescription(of cell: Int) -> String {
        var parts = ["Row \(cell / n + 1), column \(cell % n + 1)."]
        let v = entries[cell]
        if v != 0 {
            parts.append(isGiven(cell) ? "\(v), given." : "\(v).")
        } else {
            parts.append("Empty.")
            let shown = displayedNotes(cell)
            if !shown.isEmpty { parts.append("Candidates \(shown.digits.map(String.init).joined(separator: ", ")).") }
        }
        if color(of: cell) != 0 { parts.append("Colour \(color(of: cell)).") }
        let cage = puzzle.cages[cageIndex(of: cell)]
        if cage.op != .given {
            let clue = cage.op == .hidden ? "\(cage.target), operation hidden" : cage.label
            parts.append("Cage \(clue), \(cage.cells.count) cells.")
        }
        return parts.joined(separator: " ")
    }
}
