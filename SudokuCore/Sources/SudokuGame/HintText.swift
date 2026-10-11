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

    public static func message(_ d: HintDiagnosis) -> String {
        switch d {
        case .solved: return "The puzzle is solved."
        case .mistake: return "There's a mistake on your board. Use Check to find it."
        case .incomplete(let r): return "Your candidates in \(region(r)) are incomplete — fill those in first."
        case .step(let s): return nudge(s)
        case .beyond: return "This position needs reasoning beyond the hint engine."
        }
    }
}
