import SudokuCore

public enum HintText {
    /// "row 4", "column 2", "box 5" (1-based, as players count).
    public static func region(_ r: Region) -> String {
        switch r {
        case .row(let i): return "row \(i + 1)"
        case .column(let i): return "column \(i + 1)"
        case .box(let i): return "box \(i + 1)"
        }
    }

    public static func cell(_ c: Int) -> String { "r\(Geometry.row(c) + 1)c\(Geometry.col(c) + 1)" }

    /// "an X-Wing", "an Empty Rectangle", "a Naked Pair", "Cage Combinations".
    static func articled(_ name: String) -> String {
        guard let first = name.first, !name.hasSuffix("s") else { return name }
        return ("AEIOUX".contains(first) ? "an " : "a ") + name
    }

    /// How many increasingly specific nudges a step has: technique, then digit (if any), then place.
    public static func nudgeLevels(_ step: Step) -> Int { step.digits.isEmpty ? 2 : 3 }

    /// Level 1 names the technique, level 2 adds the digit, level 3 adds where to look.
    public static func nudge(_ step: Step, level: Int) -> String {
        var text = "Look for \(articled(step.technique.displayName))"
        let digitsGiven = !step.digits.isEmpty
        if level >= 2 && digitsGiven { text += " on \(step.digits.map(String.init).joined(separator: "/"))" }
        if level >= (digitsGiven ? 3 : 2) {
            if !step.regions.isEmpty {
                text += " in " + step.regions.prefix(2).map(region).joined(separator: " and ")
            } else if step.patternCells.count == 1 {
                text += " in \(cell(step.patternCells[0]))"
            } else if let first = step.patternCells.first {
                text += " around \(cell(first))"
            }
        }
        return text + "."
    }

    /// The most specific nudge.
    public static func nudge(_ step: Step) -> String { nudge(step, level: nudgeLevels(step)) }

    /// How many increasingly specific messages a diagnosis has.
    public static func levels(for d: HintDiagnosis) -> Int {
        switch d {
        case .step(let step): return nudgeLevels(step)
        case .mistake: return 3
        default: return 1
        }
    }

    /// The hint text at a given level (clamped to the diagnosis's levels).
    public static func message(_ d: HintDiagnosis, level: Int) -> String {
        let level = max(1, min(level, levels(for: d)))
        switch d {
        case .solved:
            return "The puzzle is solved."
        case .mistake(let c, let kind):
            var text = kind == .wrongDigit
                ? "One of the digits on the board is wrong."
                : "One of your crossed-out candidates was the right digit."
            if level == 2 { text += " It's in box \(Geometry.box(c) + 1)." }
            if level >= 3 { text += " It's \(cell(c))." }
            return text
        case .incomplete(let r):
            return "This hint needs candidates in \(region(r)). Fill them in, or turn on Auto Pencil."
        case .step(let s):
            return nudge(s, level: level)
        case .beyond:
            return "This position needs reasoning beyond the hint engine."
        }
    }

    /// The most specific message.
    public static func message(_ d: HintDiagnosis) -> String { message(d, level: levels(for: d)) }

    /// Whether the hint should offer to turn on Auto candidates.
    public static func offersAutoCandidates(_ d: HintDiagnosis) -> Bool {
        if case .incomplete = d { return true }
        return false
    }
}
