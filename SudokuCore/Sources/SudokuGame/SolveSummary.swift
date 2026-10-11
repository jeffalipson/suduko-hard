import Foundation
import SudokuCore

/// What a puzzle took to solve, for the completion screen and sharing.
public enum SolveSummary {
    static let singles: Set<TechniqueID> = [.fullHouse, .nakedSingle, .hiddenSingle, .cageCompletion]

    /// Uses of each technique beyond singles in the engine's solve, hardest first.
    public static func techniqueCounts(_ puzzle: Puzzle) -> [(technique: TechniqueID, count: Int)] {
        let solver: LogicalSolver = puzzle.mode == .classic ? .classic : .killer
        var counts: [TechniqueID: Int] = [:]
        for step in solver.solve(Board(values: puzzle.givens, cages: puzzle.cages)).steps where !singles.contains(step.technique) {
            counts[step.technique, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }.sorted {
            ($0.technique.tier, $0.count, $0.technique.weight) > ($1.technique.tier, $1.count, $1.technique.weight)
        }
    }

    /// "1 X-Wing", "2 Naked Pairs", "2 uses of the 45 Rule (One House)".
    public static func phrase(_ id: TechniqueID, _ n: Int) -> String {
        let name = id.displayName
        if n == 1 {
            return id.isKillerOnly && name.hasPrefix("45") ? "1 use of the \(name)" : "1 \(name)"
        }
        switch id {
        case .boxLineReduction: return "\(n) Box/Line Reductions"
        case .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle3, .uniqueRectangle4:
            return "\(n) \(name.replacingOccurrences(of: "Rectangle", with: "Rectangles"))"
        case .innieOutie1, .innieOutie2, .innieOutieMulti: return "\(n) uses of the \(name)"
        case .sueDeCoq, .alsXZ: return "\(n) \(name) patterns"
        default: return "\(n) \(name)s"
        }
    }

    public static func clock(_ seconds: Double) -> String {
        let s = Int(seconds)
        let (h, m, sec) = (s / 3600, s / 60 % 60, s % 60)
        let mm = h > 0 && m < 10 ? "0\(m)" : "\(m)"
        let ss = sec < 10 ? "0\(sec)" : "\(sec)"
        return h > 0 ? "\(h):\(mm):\(ss)" : "\(mm):\(ss)"
    }

    /// The text shared from the completion screen.
    public static func shareText(session: GameSession, counts: [(technique: TechniqueID, count: Int)]) -> String {
        let tier = session.puzzle.grade.tier.name.capitalized
        let article = "AEIOU".contains(tier.first ?? "x") ? "an" : "a"
        let mode = session.puzzle.mode.rawValue.capitalized
        var lines = ["I solved \(article) \(tier) \(mode) Sudoku in \(clock(session.elapsed))."]
        let items = counts.map { phrase($0.technique, $0.count) }
        lines.append(items.isEmpty ? "It took only singles." : "It took \(items.joined(separator: ", ")) and plenty of singles.")
        let log = session.log
        if log.isClean {
            lines.append("Clean solve: no hints, checks or reveals.")
        } else {
            let hints = log.hints.values.reduce(0, +)
            var used: [String] = []
            if hints > 0 { used.append("\(hints) hint\(hints == 1 ? "" : "s")") }
            if log.checks > 0 { used.append("\(log.checks) check\(log.checks == 1 ? "" : "s")") }
            if log.reveals > 0 { used.append("\(log.reveals) reveal\(log.reveals == 1 ? "" : "s")") }
            let assists = log.autoCandidates + log.cageHelper
            if assists > 0 { used.append("\(assists) assist\(assists == 1 ? "" : "s")") }
            if !used.isEmpty { lines.append("Used \(used.joined(separator: ", ")).") }
        }
        lines.append("Hard Sudoku")
        return lines.joined(separator: "\n")
    }
}
