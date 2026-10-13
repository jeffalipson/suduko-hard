import Testing
import SudokuCore
import SudokuGame

@Suite struct KeyboardTests {
    @Test func firstMoveSelectsTopLeft() {
        for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            var g = GameSession(puzzle: classicPuzzle())
            g.selected = nil
            g.moveSelection(rows: dr, columns: dc)
            #expect(g.selected == 0)
        }
    }

    @Test func movesInEachDirection() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = rc(4, 4)
        g.moveSelection(rows: -1, columns: 0); #expect(g.selected == rc(3, 4))
        g.moveSelection(rows: 1, columns: 0);  #expect(g.selected == rc(4, 4))
        g.moveSelection(rows: 0, columns: -1); #expect(g.selected == rc(4, 3))
        g.moveSelection(rows: 0, columns: 1);  #expect(g.selected == rc(4, 4))
    }

    @Test func stopsAtEveryEdge() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = rc(0, 0)
        g.moveSelection(rows: -1, columns: 0); #expect(g.selected == rc(0, 0))
        g.moveSelection(rows: 0, columns: -1); #expect(g.selected == rc(0, 0))
        g.selected = rc(8, 8)
        g.moveSelection(rows: 1, columns: 0);  #expect(g.selected == rc(8, 8))
        g.moveSelection(rows: 0, columns: 1);  #expect(g.selected == rc(8, 8))
        g.selected = rc(0, 8)
        g.moveSelection(rows: 0, columns: 1);  #expect(g.selected == rc(0, 8))   // no wrap to the next row
    }

    @Test func keyMapping() {
        #expect(KeyCommand.action(for: .up) == .move(rows: -1, columns: 0))
        #expect(KeyCommand.action(for: .down) == .move(rows: 1, columns: 0))
        #expect(KeyCommand.action(for: .left) == .move(rows: 0, columns: -1))
        #expect(KeyCommand.action(for: .right) == .move(rows: 0, columns: 1))
        for d in 1...9 { #expect(KeyCommand.action(for: .text("\(d)")) == .digit(d)) }
        #expect(KeyCommand.action(for: .delete) == .erase)
        #expect(KeyCommand.action(for: .text("\u{7F}")) == .erase)   // backspace as a character
        #expect(KeyCommand.action(for: .text("\u{8}")) == .erase)
        #expect(KeyCommand.action(for: .text(" ")) == .toggleInputMode)
    }

    @Test func unmappedKeysDoNothing() {
        for t in ["0", "a", "z", "12", "", "\t", "\r"] { #expect(KeyCommand.action(for: .text(t)) == nil) }
    }
}
