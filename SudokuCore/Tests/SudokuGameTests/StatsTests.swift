import Foundation
import Testing
import SudokuCore
import SudokuGame

func record(_ won: Bool, _ elapsed: Double, day: Double, tier: Tier = .hard, mistakes: Int? = nil,
            hints: [String: Int] = [:], techniques: [TechniqueID] = [.xWing]) -> GameRecordData {
    GameRecordData(mode: .classic, tier: tier, puzzleID: UUID().uuidString, endDate: Date(timeIntervalSince1970: day * 86_400),
                   elapsed: elapsed, won: won, mistakes: mistakes, hints: hints, checks: 0, reveals: 0, assists: 0,
                   clean: won && hints.isEmpty, techniques: techniques)
}

@Suite struct StatsTests {
    @Test func tierStatsAndStreaks() {
        let records = [record(true, 300, day: 1), record(true, 200, day: 2), record(false, 50, day: 3),
                       record(true, 400, day: 4), record(true, 100, day: 5), record(true, 500, day: 6, tier: .easy)]
        let s = StatsCalculator.tier(records, mode: .classic, tier: .hard)
        #expect(s.played == 5)
        #expect(s.won == 4)
        #expect(s.winRate == 0.8)
        #expect(s.bestTime == 100)
        #expect(s.averageTime == 250)
        #expect(s.currentStreak == 2)
        #expect(s.bestStreak == 2)
    }

    @Test func emptyStatsAreZero() {
        let s = StatsCalculator.tier([], mode: .killer, tier: .nightmare)
        #expect(s.played == 0 && s.winRate == 0 && s.bestTime == nil && s.averageTime == nil && s.currentStreak == 0)
        #expect(StatsCalculator.assistance([], mode: .classic).games == 0)
    }

    @Test func mistakesOnlyFromHighlightedGames() {
        let records = [record(true, 1, day: 1, mistakes: 3), record(true, 1, day: 2, mistakes: nil)]
        let a = StatsCalculator.assistance(records, mode: .classic)
        #expect(a.mistakes == 3)
        #expect(a.mistakeGames == 1)
        #expect(a.cleanSolves == 2)
    }

    @Test func techniquesCountWonPuzzlesOnly() {
        let records = [record(true, 1, day: 1, techniques: [.xWing, .aic]), record(false, 1, day: 2, techniques: [.aic]),
                       record(true, 1, day: 3, techniques: [.aic])]
        let t = StatsCalculator.techniques(records, mode: .classic)
        #expect(t.first { $0.technique == .aic }?.count == 2)
        #expect(t.first { $0.technique == .xWing }?.count == 1)
    }

    @Test func abandonRatesRankTiers() {
        let records = [record(false, 1, day: 1, tier: .nightmare), record(true, 1, day: 2, tier: .nightmare),
                       record(true, 1, day: 3, tier: .easy)]
        let rates = StatsCalculator.abandonRates(records, mode: .classic)
        #expect(rates.first?.tier == .nightmare)
        #expect(rates.first?.rate == 0.5)
    }

    @Test func sessionRecordsMistakesOnlyWithHighlighting() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(9, settings: GameSettings())
        #expect(GameRecordData(session: g, won: false, endDate: .now).mistakes == nil)
        var on = GameSettings()
        on.mistakeHighlighting = true
        g.input(8, settings: on)
        #expect(GameRecordData(session: g, won: false, endDate: .now).mistakes == 1)
    }
}
