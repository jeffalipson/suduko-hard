import Foundation
import SudokuCore

/// One finished or abandoned game, as stats see it.
public struct GameRecordData: Codable, Equatable, Sendable {
    public var mode: Mode
    public var tier: Tier
    public var puzzleID: String
    public var endDate: Date
    public var elapsed: Double
    public var won: Bool
    /// Nil when mistake highlighting was never on during the game.
    public var mistakes: Int?
    public var hints: [String: Int]
    public var checks: Int
    public var reveals: Int
    public var assists: Int
    public var clean: Bool
    public var techniques: [TechniqueID]

    public init(mode: Mode, tier: Tier, puzzleID: String, endDate: Date, elapsed: Double, won: Bool, mistakes: Int?,
                hints: [String: Int], checks: Int, reveals: Int, assists: Int, clean: Bool, techniques: [TechniqueID]) {
        self.mode = mode; self.tier = tier; self.puzzleID = puzzleID; self.endDate = endDate; self.elapsed = elapsed
        self.won = won; self.mistakes = mistakes; self.hints = hints; self.checks = checks; self.reveals = reveals
        self.assists = assists; self.clean = clean; self.techniques = techniques
    }

    public init(session: GameSession, won: Bool, endDate: Date) {
        let log = session.log
        self.init(mode: session.puzzle.mode, tier: session.puzzle.grade.tier, puzzleID: session.puzzle.id, endDate: endDate,
                  elapsed: session.elapsed, won: won, mistakes: log.highlightingUsed ? log.mistakes : nil,
                  hints: log.hints, checks: log.checks, reveals: log.reveals, assists: log.autoCandidates + log.cageHelper,
                  clean: won && log.isClean, techniques: session.puzzle.techniquesRequired)
    }

    /// Wall-clock start, derived from play time.
    public var startDate: Date { endDate.addingTimeInterval(-elapsed) }
}

public struct TierStats: Equatable, Sendable {
    public var played = 0
    public var won = 0
    public var winRate = 0.0
    public var bestTime: Double?
    public var averageTime: Double?
    public var currentStreak = 0
    public var bestStreak = 0
}

public struct AssistanceSummary: Equatable, Sendable {
    public var games = 0
    public var mistakes = 0
    public var mistakeGames = 0
    public var hints: [String: Int] = [:]
    public var checks = 0
    public var reveals = 0
    public var assists = 0
    public var cleanSolves = 0
}

public enum StatsCalculator {
    static func filtered(_ records: [GameRecordData], mode: Mode, tier: Tier? = nil) -> [GameRecordData] {
        records.filter { $0.mode == mode && (tier == nil || $0.tier == tier) }.sorted { $0.endDate < $1.endDate }
    }

    public static func tier(_ records: [GameRecordData], mode: Mode, tier: Tier) -> TierStats {
        let list = filtered(records, mode: mode, tier: tier)
        var s = TierStats()
        s.played = list.count
        let wins = list.filter(\.won)
        s.won = wins.count
        s.winRate = list.isEmpty ? 0 : Double(wins.count) / Double(list.count)
        s.bestTime = wins.map(\.elapsed).min()
        s.averageTime = wins.isEmpty ? nil : wins.map(\.elapsed).reduce(0, +) / Double(wins.count)
        var run = 0
        for r in list {
            run = r.won ? run + 1 : 0
            s.bestStreak = max(s.bestStreak, run)
        }
        s.currentStreak = run
        return s
    }

    public static func assistance(_ records: [GameRecordData], mode: Mode) -> AssistanceSummary {
        var a = AssistanceSummary()
        for r in filtered(records, mode: mode) {
            a.games += 1
            if let m = r.mistakes {
                a.mistakes += m
                a.mistakeGames += 1
            }
            for (k, v) in r.hints { a.hints[k, default: 0] += v }
            a.checks += r.checks
            a.reveals += r.reveals
            a.assists += r.assists
            if r.clean { a.cleanSolves += 1 }
        }
        return a
    }

    /// For each technique, how many won puzzles needed it (most first).
    public static func techniques(_ records: [GameRecordData], mode: Mode) -> [(technique: TechniqueID, count: Int)] {
        var counts: [TechniqueID: Int] = [:]
        for r in filtered(records, mode: mode) where r.won { for t in r.techniques { counts[t, default: 0] += 1 } }
        return counts.map { ($0.key, $0.value) }.sorted { ($0.count, $1.technique.weight) > ($1.count, $0.technique.weight) }
    }

    /// Abandon rate per tier, highest first (tiers with no games left out).
    public static func abandonRates(_ records: [GameRecordData], mode: Mode) -> [(tier: Tier, rate: Double)] {
        Tier.allCases.compactMap { t -> (Tier, Double)? in
            let list = filtered(records, mode: mode, tier: t)
            guard !list.isEmpty else { return nil }
            return (t, Double(list.filter { !$0.won }.count) / Double(list.count))
        }
        .sorted { $0.1 > $1.1 }
    }

    /// Won games' solve times in date order, for the progress chart.
    public static func progress(_ records: [GameRecordData], mode: Mode, tier: Tier) -> [(date: Date, seconds: Double)] {
        filtered(records, mode: mode, tier: tier).filter(\.won).map { ($0.endDate, $0.elapsed) }
    }
}
