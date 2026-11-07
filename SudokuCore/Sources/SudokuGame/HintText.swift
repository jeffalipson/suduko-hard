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

    /// "the 15 cage at r3c4" (its top-left cell, where the total is printed).
    public static func cage(_ cage: Cage) -> String { "the \(cage.sum) cage at \(cell(cage.cells.min() ?? 0))" }

    /// How a nudge opens: "Look for an X-Wing", "Look for Pointing", "Use the 45 Rule (One House)".
    static func opening(_ t: TechniqueID) -> String {
        let name = t.displayName
        switch t {
        case .pointing, .cageCombination: return "Look for \(name)"
        case .innieOutie1, .innieOutie2, .innieOutieMulti: return "Use the \(name)"
        default:
            let an = ["A", "E", "I", "O", "X"].contains { name.hasPrefix($0) }
            return "Look for \(an ? "an" : "a") \(name)"
        }
    }

    /// How many increasingly specific nudges a step has: technique, then digit (if any), then place.
    public static func nudgeLevels(_ step: Step) -> Int { step.digits.isEmpty ? 2 : 3 }

    /// Level 1 names the technique, level 2 adds the digit, level 3 adds where to look. `cages` lets a
    /// cage step name its cage ("in the 15 cage at r3c4") instead of a nearby cell.
    public static func nudge(_ step: Step, level: Int, cages: [Cage] = []) -> String {
        var text = opening(step.technique)
        let digitsGiven = !step.digits.isEmpty
        if level >= 2 && digitsGiven { text += " on \(step.digits.map(String.init).joined(separator: "/"))" }
        if level >= (digitsGiven ? 3 : 2) {
            // Cage techniques name their cage; a cage-locked digit also says which house it clears.
            if step.technique.isKillerOnly, step.patternCells.count > 1,
               let c = cages.first(where: { Set($0.cells) == Set(step.patternCells) }) {
                text += " in \(cage(c))"
                if step.technique == .cageLockedDigit, let house = step.regions.first { text += ", along \(region(house))" }
            } else if !step.regions.isEmpty {
                text += " in " + step.regions.prefix(2).map(region).joined(separator: " and ")
            } else if step.patternCells.count == 1 {
                text += " in \(cell(step.patternCells[0]))"
            } else if let first = step.patternCells.min() {
                text += " around \(cell(first))"
            }
        }
        return text + "."
    }

    /// The most specific nudge.
    public static func nudge(_ step: Step, cages: [Cage] = []) -> String { nudge(step, level: nudgeLevels(step), cages: cages) }

    /// How many increasingly specific messages a diagnosis has. A wrong digit ends at its cell (erase
    /// it); marks that leave out the answer go one further and name the missing digit.
    public static func levels(for d: HintDiagnosis) -> Int {
        switch d {
        case .step(let step): return nudgeLevels(step)
        case .mistake(_, .wrongDigit): return 3
        case .mistake: return 4
        default: return 1
        }
    }

    /// The level at which a mistake hint names the exact cell (and flags it, like Check).
    public static let mistakeCellLevel = 3

    /// The hint text at a given level (clamped to the diagnosis's levels). `answer` is the mistake
    /// cell's answer, shown at the last level of a missing-mark mistake.
    public static func message(_ d: HintDiagnosis, level: Int, cages: [Cage] = [], answer: Int? = nil) -> String {
        let level = max(1, min(level, levels(for: d)))
        switch d {
        case .solved:
            return "The puzzle is solved."
        case .mistake(let c, let kind):
            switch kind {
            case .wrongDigit:
                var text = "One of the digits on the board is wrong."
                if level == 2 { text += " It's in box \(Geometry.box(c) + 1)." }
                if level >= 3 { text += " It's \(cell(c))." }
                return text
            case .removedAnswer, .marksMissAnswer:
                var text = kind == .removedAnswer
                    ? "You crossed out a candidate that's the right digit."
                    : "One cell's pencil marks leave out its answer."
                if level == 2 { text += " It's in box \(Geometry.box(c) + 1)." }
                if level == 3 { text += " It's \(cell(c))." }
                if level >= 4 {
                    text = answer.map { "\(cell(c)) can still be \($0)." } ?? text + " It's \(cell(c))."
                }
                return text
            }
        case .incomplete(let r):
            return "The next step needs pencil marks in \(region(r)). Fill them in, or turn on Auto Pencil."
        case .incompleteCage(let c):
            return "The next step needs pencil marks in \(cage(c)). Fill them in, or turn on Auto Pencil."
        case .step(let s):
            return nudge(s, level: level, cages: cages)
        case .beyond:
            return "This position needs reasoning beyond the hint engine."
        }
    }

    /// The most specific message.
    public static func message(_ d: HintDiagnosis, cages: [Cage] = [], answer: Int? = nil) -> String {
        message(d, level: levels(for: d), cages: cages, answer: answer)
    }

    /// Whether the hint should offer to turn on Auto candidates.
    public static func offersAutoCandidates(_ d: HintDiagnosis) -> Bool {
        switch d {
        case .incomplete, .incompleteCage: return true
        default: return false
        }
    }

    /// The one-tap fix a mistake hint offers once it has named the cell: erase a wrong digit, or put the
    /// missing answer back among the marks.
    public static func fixLabel(_ d: HintDiagnosis, level: Int) -> String? {
        switch d {
        case .mistake(_, .wrongDigit) where level >= mistakeCellLevel: return "Erase it"
        case .mistake where level >= 4: return "Put it back"
        default: return nil
        }
    }
}
