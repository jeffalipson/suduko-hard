import Foundation
import Testing
import SudokuCore
import SudokuGame

@Suite struct AutoCandidateTests {
    let s = GameSettings()

    @Test func autoModeShowsAllCandidatesAndTracksPlacements() {
        var g = GameSession(puzzle: classicPuzzle())
        #expect(g.displayedNotes(2).isEmpty)
        g.setAutoCandidates(true)
        #expect(g.displayedNotes(2).digits == [1, 2, 4])
        #expect(g.displayedNotes(0).isEmpty)          // given
        g.selected = 2
        g.input(4, settings: s)                       // place 4: peers update automatically
        #expect(!g.displayedNotes(3).contains(4))
        #expect(g.displayedNotes(2).isEmpty)
    }

    @Test func manualRemovalsSurviveTogglingOffAndOn() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setAutoCandidates(true)
        g.selected = 2
        g.inputMode = .candidate
        g.input(1, settings: s)                       // remove 1 by hand
        #expect(g.displayedNotes(2).digits == [2, 4])
        g.setAutoCandidates(false)
        #expect(g.displayedNotes(2).isEmpty)          // back to the player's own notes
        g.setAutoCandidates(true)
        #expect(g.displayedNotes(2).digits == [2, 4]) // removal remembered
        g.input(1, settings: s)                       // tapping again restores it
        #expect(g.displayedNotes(2).digits == [1, 2, 4])
    }

    @Test func ownNotesAreUntouchedByAutoMode() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.inputMode = .candidate
        g.input(4, settings: s)
        g.setAutoCandidates(true)
        g.input(1, settings: s)
        g.setAutoCandidates(false)
        #expect(g.displayedNotes(2).digits == [4])
    }

    @Test func removalsUndo() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setAutoCandidates(true)
        g.selected = 2
        g.inputMode = .candidate
        g.input(2, settings: s)
        g.undo()
        #expect(g.displayedNotes(2).digits == [1, 2, 4])
        g.redo()
        #expect(g.displayedNotes(2).digits == [1, 4])
    }

    @Test func enablingCountsAsOneAssist() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setAutoCandidates(true)
        g.setAutoCandidates(false)
        g.setAutoCandidates(true)
        #expect(g.log.autoCandidates == 1)
        #expect(!g.log.isClean)
    }

    @Test func hintsSeeWhatIsOnScreen() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setAutoCandidates(true)
        g.selected = 2
        g.inputMode = .candidate
        g.input(4, settings: s)                       // remove the answer by hand
        #expect(HintEngine.diagnose(g).isMistake)
        #expect(!HintEngine.playerBoard(g).candidates[2].contains(4))
    }

    @Test func oldSavesDecodeWithAutoModeOff() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GameSession(puzzle: classicPuzzle()))) as! [String: Any]
        json["autoCandidateMode"] = nil
        json["removedCandidates"] = nil
        let g = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!g.autoCandidateMode)
    }
}
