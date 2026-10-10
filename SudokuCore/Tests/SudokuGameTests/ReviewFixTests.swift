import Foundation
import Testing
import SudokuCore
import SudokuGame

@Suite struct ReviewFixTests {
    @Test func settingsAndLogDecodeMissingKeysAsDefaults() throws {
        let settings = try JSONDecoder().decode(GameSettings.self, from: Data("{}".utf8))
        #expect(settings == GameSettings())
        let log = try JSONDecoder().decode(AssistLog.self, from: Data(#"{"checks":2}"#.utf8))
        #expect(log.checks == 2 && log.reveals == 0)
    }

    @Test func candidateSetsEncodeCompactly() throws {
        let json = String(decoding: try JSONEncoder().encode(CandidateSet([1, 2])), as: UTF8.self)
        #expect(json == "6")
        #expect(try JSONDecoder().decode(CandidateSet.self, from: Data(#"{"raw":6}"#.utf8)) == CandidateSet([1, 2]))
    }

    @Test func completedGamesIgnoreFurtherEdits() {
        var g = GameSession(puzzle: classicPuzzle())
        for c in 0..<81 where wikiGivens[c] == 0 {
            g.selected = c
            g.input(wikiAnswer[c], settings: GameSettings())
        }
        let done = g
        g.selected = 2
        g.erase()
        g.undo()
        g.revealCell(settings: GameSettings())
        #expect(g.entries == done.entries && g.notes == done.notes && g.log == done.log)
    }

    @Test func undoClearsStaleFlags() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(9, settings: GameSettings())
        g.checkCell()
        g.undo()
        #expect(g.flaggedWrong.isEmpty)
    }

    @Test func launchTopUpOnlyFillsEmptyQueues() {
        let key = QueueKey(mode: .classic, tier: .easy)
        let lib = PuzzleLibrary(puzzles: [key: (1...4).map { libraryPuzzle("p\($0)") }])
        var q = PuzzleQueues()
        var rng = SplitMix64(seed: 1)
        q.ensureNotEmpty(library: lib, using: &rng)
        #expect(q.count(key) == 1)
        q.ensureNotEmpty(library: lib, using: &rng)
        #expect(q.count(key) == 1)
    }
}
