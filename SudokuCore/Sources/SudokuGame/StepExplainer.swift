import SudokuCore

/// One beat of a step-by-step explanation: a sentence, plus what to show on the board.
public struct ExplanationFrame: Equatable, Sendable {
    public let text: String
    /// Cells to spotlight.
    public let cells: [Int]
    /// Candidates shown as true (green).
    public let truths: [CellDigit]
    /// Candidates shown as false (red, struck).
    public let falsehoods: [CellDigit]
    /// Digits shown as placed.
    public let placements: [CellDigit]

    public init(_ text: String, cells: [Int] = [], truths: [CellDigit] = [], falsehoods: [CellDigit] = [],
                placements: [CellDigit] = []) {
        self.text = text
        self.cells = cells
        self.truths = truths
        self.falsehoods = falsehoods
        self.placements = placements
    }
}

/// Turns a step into a walk-through of why it works, beat by beat.
public enum StepExplainer {
    public static func frames(for step: Step, on board: Board) -> [ExplanationFrame] {
        switch step.technique {
        case .xCycle, .xyChain, .aic:
            return chainFrames(step, board)
        case .cellForcingChain, .unitForcingChain, .digitForcingChain, .nestedForcingChain:
            return forcingFrames(step, board)
        case .xWing, .swordfish, .jellyfish, .finnedXWing, .finnedSwordfish:
            return fishFrames(step)
        case .xyWing, .xyzWing:
            return wingFrames(step, board)
        default:
            return genericFrames(step)
        }
    }

    // MARK: Names

    static func cell(_ c: Int) -> String { "r\(Geometry.row(c) + 1)c\(Geometry.col(c) + 1)" }
    static func name(_ cd: CellDigit) -> String { "\(cd.digit) in \(cell(cd.cell))" }

    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    static func house(_ index: Int) -> String {
        switch index {
        case 0..<9: return "row \(index + 1)"
        case 9..<18: return "column \(index - 8)"
        default: return "box \(index - 17)"
        }
    }

    static func conclusion(_ step: Step) -> ExplanationFrame {
        if !step.placements.isEmpty {
            return ExplanationFrame("So \(list(step.placements.map(name))) is certain.", placements: step.placements)
        }
        return ExplanationFrame("So \(list(step.eliminations.map(name))) can go.", falsehoods: step.eliminations)
    }

    // MARK: Chains

    /// Why one candidate leads to the next. Strong: at least one is true. Weak: not both.
    static func linkReason(_ a: CellDigit, _ b: CellDigit, strong: Bool, _ board: Board) -> String {
        if a.cell == b.cell {
            return strong
                ? "\(cell(a.cell)) has only two candidates, \(a.digit) and \(b.digit), so if it isn't \(a.digit) it's \(b.digit)."
                : "A cell holds one digit, so if \(cell(a.cell)) is \(a.digit) it isn't \(b.digit)."
        }
        let shared = Geometry.houses.indices.filter { Geometry.houses[$0].contains(a.cell) && Geometry.houses[$0].contains(b.cell) }
        if strong {
            let pair = shared.first { h in
                Geometry.houses[h].filter { board.values[$0] == 0 && board.candidates[$0].contains(a.digit) }.count == 2
            } ?? shared.first ?? 0
            return "In \(house(pair)), \(a.digit) can only go in \(cell(a.cell)) or \(cell(b.cell)), so if it isn't the first it's the second."
        }
        return "\(cell(a.cell)) and \(cell(b.cell)) share \(house(shared.first ?? 0)), so they can't both be \(a.digit)."
    }

    static func chainFrames(_ step: Step, _ board: Board) -> [ExplanationFrame] {
        let nodes = step.patternCandidates
        guard let first = nodes.first, let last = nodes.last, nodes.count >= 2 else { return genericFrames(step) }
        let cells = step.patternCells
        var truths: [CellDigit] = []
        var falsehoods = [first]
        var frames = [ExplanationFrame("Follow the chain from \(name(first)). Suppose it's false.",
                                       cells: cells, falsehoods: falsehoods)]
        for i in 1..<nodes.count {
            let strong = i % 2 == 1
            let reason = linkReason(nodes[i - 1], nodes[i], strong: strong, board)
            if strong {
                truths.append(nodes[i])
                frames.append(ExplanationFrame("\(reason) So \(name(nodes[i])) is true.",
                                               cells: cells, truths: truths, falsehoods: falsehoods))
            } else {
                falsehoods.append(nodes[i])
                frames.append(ExplanationFrame("\(reason) So \(name(nodes[i])) is false.",
                                               cells: cells, truths: truths, falsehoods: falsehoods))
            }
        }
        frames.append(ExplanationFrame(
            "So if \(name(first)) is false, \(name(last)) is true. Either way, at least one of the two ends is true.",
            cells: cells, truths: [first, last]))
        let removed = list(step.eliminations.map(name))
        frames.append(ExplanationFrame(
            "\(removed) can't be true at the same time as either end (same cell, or same digit where they see each other), so it goes.",
            cells: cells, truths: [first, last], falsehoods: step.eliminations))
        return frames
    }

    // MARK: Forcing chains

    static func forcingFrames(_ step: Step, _ board: Board) -> [ExplanationFrame] {
        guard let forcing = ForcingChain.named(step.technique) else { return genericFrames(step) }
        let target: (Board) -> Bool
        let goal: String
        if let p = step.placements.first {
            target = { $0.values[p.cell] == p.digit }
            goal = "\(cell(p.cell)) is \(p.digit)"
        } else {
            let gone = step.eliminations
            target = { b in gone.allSatisfy { b.values[$0.cell] != 0 ? b.values[$0.cell] != $0.digit : !b.candidates[$0.cell].contains($0.digit) } }
            goal = "\(list(gone.map(name))) is ruled out"
        }
        // Digit forcing tries one candidate both ways; the others try each candidate as true.
        let branches: [(CellDigit, Bool)] = step.technique == .digitForcingChain && step.patternCandidates.count == 1
            ? [(step.patternCandidates[0], true), (step.patternCandidates[0], false)]
            : step.patternCandidates.map { ($0, true) }
        var frames: [ExplanationFrame] = []
        for (assumption, isTrue) in branches {
            let premise = isTrue ? "If \(cell(assumption.cell)) is \(assumption.digit)" : "If \(cell(assumption.cell)) isn't \(assumption.digit)"
            let trace = forcing.trace(board, assuming: assumption, isTrue: isTrue, until: target)
            let placed = trace.steps.flatMap(\.placements)
            if trace.contradiction {
                frames.append(ExplanationFrame("\(premise), the grid breaks: some cell or house runs out of options. So that can't happen.",
                                               cells: [assumption.cell], truths: isTrue ? [assumption] : [],
                                               falsehoods: isTrue ? [] : [assumption], placements: placed))
                continue
            }
            let shown = trace.steps.prefix(5).map { s -> String in
                if let p = s.placements.first { return "\(cell(p.cell)) is \(p.digit)" }
                if let e = s.eliminations.first { return "\(cell(e.cell)) can't be \(e.digit)" }
                return s.technique.displayName
            }
            let more = trace.steps.count > 5 ? " → …" : ""
            let path = shown.isEmpty ? "" : " → " + shown.joined(separator: " → ") + more
            frames.append(ExplanationFrame("\(premise)\(path) → \(goal).",
                                           cells: [assumption.cell] + placed.map(\.cell),
                                           truths: isTrue ? [assumption] : [], falsehoods: isTrue ? [] : [assumption],
                                           placements: placed))
        }
        let last = conclusion(step)
        frames.append(ExplanationFrame("Every possibility leads to the same place: \(goal). " + last.text,
                                       truths: last.truths, falsehoods: last.falsehoods, placements: last.placements))
        return frames
    }

    // MARK: Fish

    static func fishFrames(_ step: Step) -> [ExplanationFrame] {
        guard let d = step.digits.first else { return genericFrames(step) }
        let size: Int
        switch step.technique {
        case .xWing, .finnedXWing: size = 2
        case .swordfish, .finnedSwordfish: size = 3
        default: size = 4
        }
        let regionNames = step.regions.map(HintText.region)
        guard regionNames.count >= 2 * size else { return genericFrames(step) }
        let base = list(Array(regionNames.prefix(size)))
        let cover = list(Array(regionNames[size..<(2 * size)]))
        let fins = step.groups.first ?? []
        var frames = [
            ExplanationFrame("In \(base), \(d) can only go in \(cover)\(fins.isEmpty ? "" : ", apart from the fins (orange)").",
                             cells: step.patternCells, truths: step.patternCandidates),
            ExplanationFrame("Each of those \(size) lines needs its \(d) in a different one of \(cover). So those \(size) \(d)s fill \(cover) completely.",
                             cells: step.patternCells, truths: step.patternCandidates),
        ]
        if !fins.isEmpty {
            frames.append(ExplanationFrame("If a fin is the \(d) instead, it still rules out the cells it sees. Only cells that see the fins and lie in \(cover) are safe to clear either way.",
                                           cells: step.patternCells, truths: fins))
        }
        frames.append(conclusion(step))
        return frames
    }

    // MARK: Wings

    static func wingFrames(_ step: Step, _ board: Board) -> [ExplanationFrame] {
        guard step.patternCells.count == 3, let z = step.eliminations.first?.digit else { return genericFrames(step) }
        let (pivot, x, y) = (step.patternCells[0], step.patternCells[1], step.patternCells[2])
        let pivotDigits = board.candidates[pivot].digits.filter { $0 != z || step.technique == .xyzWing }
        let xOther = board.candidates[x].digits.first { $0 != z } ?? z
        let yOther = board.candidates[y].digits.first { $0 != z } ?? z
        var frames = [ExplanationFrame("\(cell(pivot)) can only be \(list(pivotDigits.map(String.init))).",
                                       cells: [pivot], truths: board.candidates[pivot].digits.map { CellDigit(cell: pivot, digit: $0) })]
        frames.append(ExplanationFrame(
            "If it's \(xOther), then \(cell(x)) (which sees it) can't be \(xOther), so \(cell(x)) is \(z). If it's \(yOther), \(cell(y)) is \(z) the same way."
                + (step.technique == .xyzWing ? " And if it's \(z), \(cell(pivot)) itself is \(z)." : ""),
            cells: [pivot, x, y], truths: [CellDigit(cell: x, digit: z), CellDigit(cell: y, digit: z)]))
        frames.append(ExplanationFrame(
            "Either way \(z) lands in one of those cells, so any cell that sees all of them can't be \(z).",
            cells: [pivot, x, y], truths: [CellDigit(cell: x, digit: z), CellDigit(cell: y, digit: z)], falsehoods: step.eliminations))
        return frames
    }

    // MARK: Everything else

    static func genericFrames(_ step: Step) -> [ExplanationFrame] {
        [ExplanationFrame("\(LessonText.explanation(for: step.technique)) Here's the pattern.",
                          cells: step.patternCells, truths: step.patternCandidates),
         conclusion(step)]
    }
}
