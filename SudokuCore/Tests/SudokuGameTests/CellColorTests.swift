import Foundation
import Testing
import SudokuCore
import SudokuGame

@Suite struct CellColorTests {
    @Test func paintingAndClearingACell() {
        var g = GameSession(puzzle: classicPuzzle())
        #expect(g.color(of: 10) == 0)
        g.setColor(3, at: 10)
        #expect(g.color(of: 10) == 3)
        g.setColor(5, at: 10)                  // a different colour replaces it
        #expect(g.color(of: 10) == 5)
        g.setColor(5, at: 10)                  // the same colour again clears it
        #expect(g.color(of: 10) == 0)
        g.setColor(2, at: 0)                   // givens can be coloured too
        #expect(g.color(of: 0) == 2)
        g.setColor(0, at: 0)
        #expect(g.color(of: 0) == 0)
    }

    @Test func coloursAreUndoable() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setColor(4, at: 20)
        #expect(g.canUndo)
        g.undo()
        #expect(g.color(of: 20) == 0)
        g.redo()
        #expect(g.color(of: 20) == 4)
    }

    @Test func clearAllRemovesEveryColour() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setColor(1, at: 2)
        g.setColor(9, at: 80)
        #expect(g.hasColors)
        g.clearColors()
        #expect(!g.hasColors)
        #expect(g.color(of: 80) == 0)
    }

    @Test func outOfRangeColoursAreIgnored() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setColor(GameSession.colorCount + 1, at: 3)
        g.setColor(-1, at: 3)
        #expect(g.color(of: 3) == 0)
        #expect(!g.canUndo)
    }

    @Test func coloursSurviveSavingAndOldSavesLoad() throws {
        var g = GameSession(puzzle: classicPuzzle())
        g.setColor(7, at: 40)
        let data = try JSONEncoder().encode(g)
        #expect(try JSONDecoder().decode(GameSession.self, from: data).color(of: 40) == 7)
        // A save from before colours existed has no colour key.
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "cellColors")
        let old = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.color(of: 40) == 0)
    }

    @Test func voiceOverMentionsTheColour() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setColor(3, at: 0)
        #expect(g.spokenDescription(of: 0) == "Row 1, column 1. 5, given. Colour 3.")
    }
}
