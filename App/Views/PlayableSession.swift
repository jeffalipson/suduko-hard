import SudokuCore
import SudokuGame

/// What the controls need from a game, so Sudoku and Mathdoku share one keypad, palette and tool row.
protocol PlayableSession {
    var inputMode: InputMode { get set }
    var selected: Int? { get set }
    /// Digits 1…digitCount (9 for Sudoku, n for an n×n Mathdoku).
    var digitCount: Int { get }
    var canUndo: Bool { get }
    var canRedo: Bool { get }
    var autoCandidateMode: Bool { get }
    var hasColors: Bool { get }
    /// Whether the Killer cage helper applies to this game.
    var hasCageHelper: Bool { get }
    func placedCount(of digit: Int) -> Int
    func color(of cell: Int) -> Int
    mutating func input(_ digit: Int, settings: GameSettings)
    mutating func erase()
    mutating func undo()
    mutating func redo()
    mutating func setAutoCandidates(_ on: Bool)
    mutating func setColor(_ color: Int, at cell: Int)
    mutating func clearColors()
    mutating func useCageHelper()
}

extension GameSession: PlayableSession {
    var digitCount: Int { 9 }
    var hasCageHelper: Bool { !puzzle.cages.isEmpty }
}

extension MathdokuSession: PlayableSession {
    var digitCount: Int { n }
    var hasCageHelper: Bool { false }
    mutating func useCageHelper() {}
}
