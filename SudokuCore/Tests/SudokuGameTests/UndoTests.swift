import Foundation
import Testing
import SudokuCore
import SudokuGame

@Suite struct UndoTests {
    @Test func undoRedoEveryKindOfChange() {
        var g = GameSession(puzzle: classicPuzzle())
        let s = GameSettings()
        g.selected = 2
        g.input(4, settings: s)
        g.inputMode = .candidate
        g.selected = 3
        g.input(6, settings: s)
        g.fillAllCandidates()
        g.selected = 5
        g.inputMode = .normal
        g.revealCell()
        let end = g
        for _ in 0..<4 { g.undo() }
        #expect(g.entries == wikiGivens)
        #expect(g.notes.allSatisfy { $0.isEmpty })
        for _ in 0..<4 { g.redo() }
        #expect(g.entries == end.entries)
        #expect(g.notes == end.notes)
        g.undo()
        g.selected = 7
        g.input(1, settings: s)
        #expect(!g.canRedo)
    }

    @Test func autoCandidatesFillTrueCandidatesAndCountAsAssist() {
        var g = GameSession(puzzle: classicPuzzle())
        g.fillAllCandidates()
        #expect(g.notes[2].digits == [1, 2, 4])
        #expect(g.notes[0].isEmpty)
        #expect(g.log.autoCandidates == 1)
        #expect(!g.log.isClean)
    }

    @Test func checkFlagsWrongCellsAndCounts() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(9, settings: GameSettings())
        g.checkCell()
        #expect(g.flaggedWrong == [2])
        #expect(g.log.checks == 1)
        g.input(4, settings: GameSettings())
        #expect(g.flaggedWrong.isEmpty)
        g.selected = 3
        g.input(1, settings: GameSettings())
        g.checkPuzzle()
        #expect(g.flaggedWrong == [3])
        #expect(g.log.checks == 2)
    }

    @Test func revealFillsSolutionButNotGivens() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 0
        g.revealCell()
        #expect(g.log.reveals == 0)
        g.selected = 2
        g.revealCell()
        #expect(g.entries[2] == wikiAnswer[2])
        #expect(g.log.reveals == 1)
    }

    @Test func timerOnlyRunsWhilePlaying() {
        var g = GameSession(puzzle: classicPuzzle())
        g.tick(5)
        g.setPaused(true)
        g.tick(5)
        g.setPaused(false)
        g.tick(1)
        #expect(g.elapsed == 6)
        for c in 0..<81 where wikiGivens[c] == 0 {
            g.selected = c
            g.input(wikiAnswer[c], settings: GameSettings())
        }
        g.tick(10)
        #expect(g.elapsed == 6)
    }

    @Test func autosaveRoundTrips() throws {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(4, settings: GameSettings())
        g.tick(3)
        g.setPaused(true)
        let data = try JSONEncoder().encode(g)
        let back = try JSONDecoder().decode(GameSession.self, from: data)
        #expect(back == g)
        #expect(back.canUndo)
    }
}
