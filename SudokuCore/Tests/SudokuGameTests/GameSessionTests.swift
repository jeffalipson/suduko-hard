import Foundation
import Testing
import SudokuCore
import SudokuGame

let wikiGivens = Board.parse("530070000600195000098000060800060003400803001700020006060000280000419005000080079")!
let wikiAnswer = Board.parse("534678912672195348198342567859761423426853791713924856961537284287419635345286179")!

func classicPuzzle() -> Puzzle {
    Puzzle(id: "w", mode: .classic, givens: wikiGivens, cages: [], solution: wikiAnswer,
           grade: Grade(tier: .easy, score: 1), techniquesRequired: [.nakedSingle])
}

@Suite struct GameSessionTests {
    @Test func defaultsFollowTheSpec() {
        let s = GameSettings()
        #expect(!s.autoCandidates && !s.autoRemoveCandidates && !s.mistakeHighlighting)
        #expect(!s.cageHelper && !s.remainingSum)
        #expect(s.highlightMatching)
    }

    @Test func normalInputPlacesAndToggles() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(4, settings: GameSettings())
        #expect(g.entries[2] == 4)
        g.input(4, settings: GameSettings())   // same digit again clears it, like NYT
        #expect(g.entries[2] == 0)
    }

    @Test func givensAreImmutable() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 0
        g.input(9, settings: GameSettings())
        g.erase()
        #expect(g.entries[0] == 5)
        #expect(!g.canUndo)
    }

    @Test func candidateModeTogglesNotes() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.inputMode = .candidate
        g.input(1, settings: GameSettings())
        g.input(2, settings: GameSettings())
        g.input(1, settings: GameSettings())
        #expect(g.notes[2].digits == [2])
        g.inputMode = .normal
        g.input(4, settings: GameSettings())
        #expect(g.notes[2].isEmpty)
    }

    @Test func mistakesCountOnlyWithHighlighting() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(9, settings: GameSettings())
        #expect(g.log.mistakes == 0)
        #expect(g.isWrong(2))
        var on = GameSettings()
        on.mistakeHighlighting = true
        g.input(8, settings: on)
        #expect(g.log.mistakes == 1)
    }

    @Test func autoRemoveClearsPeerNotes() {
        var g = GameSession(puzzle: classicPuzzle())
        g.inputMode = .candidate
        g.selected = 3
        g.input(4, settings: GameSettings())
        g.inputMode = .normal
        g.selected = 2
        var s = GameSettings()
        s.autoRemoveCandidates = true
        g.input(4, settings: s)
        #expect(!g.notes[3].contains(4))
    }

    @Test func completionAndCounts() {
        var g = GameSession(puzzle: classicPuzzle())
        #expect(g.placedCount(of: 5) == wikiGivens.filter { $0 == 5 }.count)
        for c in 0..<81 where wikiGivens[c] == 0 {
            g.selected = c
            g.input(wikiAnswer[c], settings: GameSettings())
        }
        #expect(g.isComplete)
        #expect(g.placedCount(of: 9) == 9)
    }
}

@Suite struct AppearanceSettingTests {
    @Test func defaultsToSystemAndRoundTrips() throws {
        var s = GameSettings()
        #expect(s.appearance == .system)
        s.appearance = .dark
        let back = try JSONDecoder().decode(GameSettings.self, from: JSONEncoder().encode(s))
        #expect(back.appearance == .dark)
        let old = try JSONDecoder().decode(GameSettings.self, from: Data(#"{"highlightMatching":true}"#.utf8))
        #expect(old.appearance == .system)
    }
}
