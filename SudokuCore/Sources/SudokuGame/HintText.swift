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

    /// "an X-Wing", "an Empty Rectangle", "a Naked Pair".
    static func article(_ name: String) -> String {
        guard let first = name.first else { return "a" }
        return "AEIOUX".contains(first) ? "an" : "a"
    }

    public static func nudge(_ step: Step) -> String {
        let name = step.technique.displayName
        let digits = step.digits.isEmpty ? "" : " on \(step.digits.map(String.init).joined(separator: "/"))"
        if !step.regions.isEmpty {
            let places = step.regions.prefix(2).map(region).joined(separator: " and ")
            return "Look for \(article(name)) \(name)\(digits) in \(places)."
        }
        let around = step.patternCells.first.map { " around \(cell($0))" } ?? ""
        return "Look for \(article(name)) \(name)\(digits)\(around)."
    }

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
