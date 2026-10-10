import SudokuCore

public enum InputMode: String, Codable, Sendable {
    case normal, candidate
}

/// Everything a finished game reports to stats.
public struct AssistLog: Codable, Equatable, Sendable {
    /// Wrong digits entered while mistake highlighting was on.
    public var mistakes = 0
    public var checks = 0
    public var reveals = 0
    public var autoCandidates = 0
    public var cageHelper = 0
    /// Hint uses by level name (Plan 6).
    public var hints: [String: Int] = [:]
    /// Whether mistake highlighting was on for any placement (mistakes only count then).
    public var highlightingUsed = false

    public init() {}

    private enum CodingKeys: String, CodingKey { case mistakes, checks, reveals, autoCandidates, cageHelper, hints, highlightingUsed }

    /// Missing keys decode as zero so older save files keep working.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mistakes = try c.decodeIfPresent(Int.self, forKey: .mistakes) ?? 0
        checks = try c.decodeIfPresent(Int.self, forKey: .checks) ?? 0
        reveals = try c.decodeIfPresent(Int.self, forKey: .reveals) ?? 0
        autoCandidates = try c.decodeIfPresent(Int.self, forKey: .autoCandidates) ?? 0
        cageHelper = try c.decodeIfPresent(Int.self, forKey: .cageHelper) ?? 0
        hints = try c.decodeIfPresent([String: Int].self, forKey: .hints) ?? [:]
        highlightingUsed = try c.decodeIfPresent(Bool.self, forKey: .highlightingUsed) ?? false
    }

    public var isClean: Bool {
        checks == 0 && reveals == 0 && autoCandidates == 0 && cageHelper == 0 && hints.values.allSatisfy { $0 == 0 }
    }
}

public struct GameSession: Codable, Equatable, Sendable {
    struct Snapshot: Codable, Equatable, Sendable {
        let entries: [Int]
        let notes: [CandidateSet]
    }

    public let puzzle: Puzzle
    public private(set) var entries: [Int]
    public private(set) var notes: [CandidateSet]
    public var selected: Int?
    public var inputMode: InputMode = .normal
    public private(set) var elapsed: Double = 0
    public private(set) var isPaused = false
    public internal(set) var log = AssistLog()
    /// Cells a Check flagged as wrong; cleared when the cell changes.
    public private(set) var flaggedWrong: Set<Int> = []
    var undoStack: [Snapshot] = []
    var redoStack: [Snapshot] = []

    public init(puzzle: Puzzle) {
        self.puzzle = puzzle
        self.entries = puzzle.givens
        self.notes = Array(repeating: .empty, count: 81)
    }

    public func isGiven(_ cell: Int) -> Bool { puzzle.givens[cell] != 0 }
    public func isWrong(_ cell: Int) -> Bool { entries[cell] != 0 && entries[cell] != puzzle.solution[cell] }
    public var isComplete: Bool { entries == puzzle.solution }
    public func placedCount(of digit: Int) -> Int { entries.filter { $0 == digit }.count }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Normal mode places (or clears, if repeated) a digit; candidate mode toggles a note.
    public mutating func input(_ digit: Int, settings: GameSettings) {
        guard let cell = selected, !isGiven(cell), !isComplete else { return }
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
            if notes[cell].contains(digit) { notes[cell].remove(digit) } else { notes[cell].insert(digit) }
        }
    }

    /// Clears the selected cell's digit, or its notes when it has no digit.
    public mutating func erase() {
        guard let cell = selected, !isGiven(cell), !isComplete, entries[cell] != 0 || !notes[cell].isEmpty else { return }
        record()
        if entries[cell] != 0 { entries[cell] = 0 } else { notes[cell] = .empty }
        flaggedWrong.remove(cell)
    }

    mutating func removeNote(_ digit: Int, around cell: Int) {
        for p in Geometry.peers[cell] { notes[p].remove(digit) }
        if let cage = puzzle.cages.first(where: { $0.cells.contains(cell) }) {
            for p in cage.cells where p != cell { notes[p].remove(digit) }
        }
    }

    /// Saves the current state for undo and clears redo.
    mutating func record() {
        undoStack.append(Snapshot(entries: entries, notes: notes))
        redoStack.removeAll()
    }

    mutating func restore(_ s: Snapshot) {
        entries = s.entries
        notes = s.notes
        flaggedWrong = flaggedWrong.filter(isWrong)
    }

    public mutating func setPaused(_ paused: Bool) { isPaused = paused }
    mutating func addElapsed(_ seconds: Double) { elapsed += seconds }
    mutating func flag(_ cells: [Int]) { flaggedWrong.formUnion(cells) }
    mutating func unflag(_ cell: Int) { flaggedWrong.remove(cell) }
}
