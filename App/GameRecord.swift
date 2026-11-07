import Foundation
import SwiftData
import SudokuCore
import SudokuGame

/// Persisted mirror of `GameRecordData` (stored as JSON-friendly primitives).
@Model
final class GameRecord {
    var mode: String
    var tier: Int
    var puzzleID: String
    var endDate: Date
    var elapsed: Double
    var won: Bool
    var mistakes: Int?
    var hintsJSON: Data
    var checks: Int
    var reveals: Int
    var assists: Int
    var clean: Bool
    var techniques: [String]
    var startedAt: Date?

    init(_ d: GameRecordData) {
        mode = d.mode.rawValue
        tier = d.tier.rawValue
        puzzleID = d.puzzleID
        endDate = d.endDate
        elapsed = d.elapsed
        won = d.won
        mistakes = d.mistakes
        hintsJSON = (try? JSONEncoder().encode(d.hints)) ?? Data()
        checks = d.checks
        reveals = d.reveals
        assists = d.assists
        clean = d.clean
        techniques = d.techniques.map(\.rawValue)
        startedAt = d.startedAt
    }

    /// A finished or abandoned Mathdoku game. Stored with mode "mathdoku", which Sudoku stats skip.
    init(mathdoku session: MathdokuSession, won: Bool, endDate: Date) {
        let log = session.log
        mode = "mathdoku"
        tier = session.puzzle.tier.rawValue
        puzzleID = session.puzzle.id
        self.endDate = endDate
        elapsed = session.elapsed
        self.won = won
        mistakes = GameRecordData.recordedMistakes(log)
        hintsJSON = (try? JSONEncoder().encode(log.hints)) ?? Data()
        checks = log.checks
        reveals = log.reveals
        assists = log.autoCandidates
        clean = won && log.isClean
        techniques = session.puzzle.techniques.map(\.rawValue)
        startedAt = session.startedAt
    }

    /// A Mathdoku record as stats data. Stats code filters by `Mode`, so Mathdoku records are read with
    /// a stand-in mode and only ever computed on their own.
    func mathdokuData(as stand: Mode) -> GameRecordData? {
        guard mode == "mathdoku", let t = Tier(rawValue: tier) else { return nil }
        return GameRecordData(mode: stand, tier: t, puzzleID: puzzleID, endDate: endDate, elapsed: elapsed, won: won,
                              mistakes: mistakes, hints: (try? JSONDecoder().decode([String: Int].self, from: hintsJSON)) ?? [:],
                              checks: checks, reveals: reveals, assists: assists, clean: clean, techniques: [], startedAt: startedAt)
    }

    var data: GameRecordData? {
        guard let m = Mode(rawValue: mode), let t = Tier(rawValue: tier) else { return nil }
        return GameRecordData(mode: m, tier: t, puzzleID: puzzleID, endDate: endDate, elapsed: elapsed, won: won,
                              mistakes: mistakes, hints: (try? JSONDecoder().decode([String: Int].self, from: hintsJSON)) ?? [:],
                              checks: checks, reveals: reveals, assists: assists, clean: clean,
                              techniques: techniques.compactMap(TechniqueID.init(rawValue:)), startedAt: startedAt)
    }
}
