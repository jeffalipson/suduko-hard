import SudokuCore

public enum MathHintDiagnosis: Equatable, Sendable {
    case solved
    /// Something Check would flag.
    case mistake(cell: Int, kind: MistakeKind)
    /// The next step needs pencil marks the player hasn't made yet.
    case incomplete(MathRegion)
    case step(MathStep)
    /// Nothing in the catalogue applies.
    case beyond

    public var isMistake: Bool {
        if case .mistake = self { return true }
        return false
    }
}

public enum MathdokuHintEngine {
    /// Techniques a player can use without pencil marks.
    static let noNotesNeeded: Set<MathTechnique> = [.nakedSingle, .hiddenSingle, .cageArithmetic]

    public static func diagnose(_ session: MathdokuSession) -> MathHintDiagnosis {
        if session.isComplete { return .solved }
        for c in 0..<session.cellCount where session.isWrong(c) { return .mistake(cell: c, kind: .wrongDigit) }
        for c in 0..<session.cellCount where session.ruledOutAnswer(c) { return .mistake(cell: c, kind: .removedAnswer) }
        let shown = usableNotes(session)
        let board = playerBoard(session)
        guard let step = MathdokuSolver.nextStep(on: board) else { return .beyond }
        if !noNotesNeeded.contains(step.technique),
           let bare = step.cells.first(where: { session.entries[$0] == 0 && shown[$0].isEmpty }) {
            return .incomplete(step.regions.first { region(region: $0, contains: bare, in: session) } ?? .row(bare / session.n))
        }
        return .step(step)
    }

    static func region(region: MathRegion, contains cell: Int, in s: MathdokuSession) -> Bool {
        switch region {
        case .row(let r): cell / s.n == r
        case .column(let c): cell % s.n == c
        case .cage(let i): s.puzzle.cages[i].cells.contains(cell)
        }
    }

    /// The player's position: their digits, and their notes where they made any.
    public static func playerBoard(_ session: MathdokuSession) -> MathdokuBoard {
        var board = MathdokuBoard(n: session.n, cages: session.puzzle.cages, values: session.entries)
        let shown = usableNotes(session)
        for c in 0..<session.cellCount where session.entries[c] == 0 && !shown[c].isEmpty {
            board.candidates[c] = shown[c].intersection(board.candidates[c])
        }
        return board
    }

    /// Notes the hint may build on; the player's own marks that leave out the answer are set aside.
    static func usableNotes(_ session: MathdokuSession) -> [CandidateSet] {
        let shown = session.displayedNotes()
        guard !session.autoCandidateMode else { return shown }
        return (0..<session.cellCount).map { c in shown[c].contains(session.puzzle.solution[c]) ? shown[c] : .empty }
    }
}

/// Graduated hint wording: technique, then digit, then where.
public enum MathHintText {
    public static func levels(for diagnosis: MathHintDiagnosis) -> Int {
        switch diagnosis {
        case .step: 3
        case .mistake: 3
        default: 1
        }
    }

    public static func message(_ d: MathHintDiagnosis, level: Int, puzzle: MathdokuPuzzle) -> String {
        switch d {
        case .solved:
            return "Solved."
        case .beyond:
            return "No technique in the app finds the next step from here. Check your digits, or try Reveal."
        case .incomplete(let region):
            return "This hint needs pencil marks in \(name(region, puzzle)). Fill them in, or turn on Auto Pencil."
        case .mistake(let cell, let kind):
            let first = kind == .wrongDigit ? "One of the digits on the board is wrong." : "One of your crossed-out candidates was the right digit."
            switch level {
            case ...1: return first
            case 2: return "\(first) It's in row \(cell / puzzle.n + 1)."
            default: return "\(first) It's r\(cell / puzzle.n + 1)c\(cell % puzzle.n + 1)."
            }
        case .step(let step):
            let t = step.technique
            let digits = step.digits.map(String.init).joined(separator: " and ")
            let place = step.regions.first.map { name($0, puzzle) }
            switch level {
            case ...1:
                return "Try \(t.name)."
            case 2:
                return digits.isEmpty ? "Try \(t.name)." : "Try \(t.name) with \(digits)."
            default:
                let core = digits.isEmpty ? "Try \(t.name)" : "Try \(t.name) with \(digits)"
                return place.map { "\(core) in \($0)." } ?? "\(core)."
            }
        }
    }

    public static func name(_ region: MathRegion, _ puzzle: MathdokuPuzzle) -> String {
        switch region {
        case .row(let r): return "row \(r + 1)"
        case .column(let c): return "column \(c + 1)"
        case .cage(let i):
            let cage = puzzle.cages[i]
            return cage.op == .hidden ? "the \(cage.target) cage" : "the \(cage.label) cage"
        }
    }

    /// Whether the hint should offer to turn on Auto Pencil.
    public static func offersAutoPencil(_ d: MathHintDiagnosis) -> Bool {
        if case .incomplete = d { return true }
        return false
    }
}

/// What each technique is, for the lesson sheet.
public enum MathLessonText {
    public static func summary(_ t: MathTechnique) -> String {
        switch t {
        case .nakedSingle: "A cell with only one possible digit."
        case .hiddenSingle: "A digit with only one possible cell in a row or column."
        case .cageArithmetic: "A cage's clue rules out digits."
        case .cageLineForced: "A cage must put a digit in a row or column."
        case .nakedPair: "Two cells, two digits."
        case .hiddenPair: "Two digits, two cells."
        case .nakedTriple: "Three cells, three digits."
        case .hiddenTriple: "Three digits, three cells."
        case .xWing: "A digit locked into a rectangle."
        case .swordfish: "An X-Wing across three rows."
        case .cagePair: "Two cages that share a line limit each other."
        case .contradiction: "If a digit breaks the puzzle, it can't go there."
        }
    }

    public static func body(_ t: MathTechnique) -> String {
        switch t {
        case .nakedSingle:
            "When a cell's pencil marks are down to one digit, that digit goes there."
        case .hiddenSingle:
            "Every row and column needs each digit once. If a digit fits in only one cell of a row or column, it goes there, even if that cell has other candidates."
        case .cageArithmetic:
            "List what can make the cage's clue. A two-cell 7+ in a 9×9 can be 1+6, 2+5 or 3+4, so 7, 8 and 9 can't go in it. A two-cell 12× can be 2×6, 3×4 or the reverse, never 1 or 5. Cells in the same row or column of a cage can't repeat a digit; cells that share neither can."
        case .cageLineForced:
            "If every way to fill a cage puts a digit in the cage's part of one row or column, that digit can't appear anywhere else in that row or column."
        case .nakedPair:
            "Two cells in a row or column whose candidates are the same two digits must hold those two digits between them. Remove both digits from the rest of the line."
        case .hiddenPair:
            "If two digits can only go in the same two cells of a row or column, those cells hold those digits. Remove every other candidate from the two cells."
        case .nakedTriple:
            "Three cells in a line whose candidates use only three digits between them hold those three digits. Remove them from the rest of the line."
        case .hiddenTriple:
            "If three digits can only go in the same three cells of a line, those cells hold those digits. Remove every other candidate from them."
        case .xWing:
            "If a digit has exactly two spots in each of two rows, and those spots share the same two columns, the digit fills two corners of that rectangle. Remove it from the rest of both columns. It works with rows and columns swapped too."
        case .swordfish:
            "Like an X-Wing with three rows: if a digit's spots in three rows all fall in the same three columns, remove it from the rest of those columns."
        case .cagePair:
            "When two cages share a row or column, a filling of one can rule out fillings of the other. Keep only combinations that work together, and remove digits no surviving combination uses."
        case .contradiction:
            "Pick a cell with two or three candidates and suppose one of them is the answer. Follow the easier techniques. If the board breaks (a cell runs out of candidates, a cage can't be made, or a row needs a digit it can't hold), the supposed digit was wrong, so remove it."
        }
    }
}
