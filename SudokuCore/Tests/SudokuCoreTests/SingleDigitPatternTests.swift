import Testing
import SudokuCore

@Suite struct SingleDigitPatternTests {
    @Test func skyscraper() throws {
        // Rows 1 and 6 are strong links on 4 sharing column 0; roofs (1,4) and (6,5).
        let b = board(digit: 4, onlyIn: [rc(1, 0), rc(1, 4), rc(6, 0), rc(6, 5), rc(0, 5), rc(2, 5)])
        let step = try #require(Skyscraper().find(in: b))
        #expect(step.technique == .skyscraper)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 5), digit: 4), CellDigit(cell: rc(2, 5), digit: 4)])
        #expect(step.regions == [.row(1), .row(6)])
    }

    @Test func alignedRoofsAreAnXWingNotASkyscraper() {
        let b = board(digit: 4, onlyIn: [rc(1, 0), rc(1, 4), rc(6, 0), rc(6, 4), rc(3, 4)])
        #expect(Skyscraper().find(in: b) == nil)
    }

    @Test func twoStringKite() throws {
        // Row 0 link (0,1)-(0,6); column 2 link (1,2)-(5,2); (0,1) and (1,2) share box 0.
        let b = board(digit: 6, onlyIn: [rc(0, 1), rc(0, 6), rc(1, 2), rc(5, 2), rc(5, 6)])
        let step = try #require(TwoStringKite().find(in: b))
        #expect(step.technique == .twoStringKite)
        #expect(step.eliminations == [CellDigit(cell: rc(5, 6), digit: 6)])
    }

    @Test func emptyRectangle() throws {
        // Box 0 holds 7 only on row 0 / column 0; column 5 link (0,5)-(6,5).
        let b = board(digit: 7, onlyIn: [rc(0, 1), rc(0, 2), rc(2, 0), rc(0, 5), rc(6, 5), rc(6, 0)])
        let step = try #require(EmptyRectangle().find(in: b))
        #expect(step.technique == .emptyRectangle)
        #expect(step.eliminations == [CellDigit(cell: rc(6, 0), digit: 7)])
        #expect(step.regions == [.box(0), .column(5)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(Skyscraper().find(in: emptyBoard()) == nil)
        #expect(TwoStringKite().find(in: emptyBoard()) == nil)
        #expect(EmptyRectangle().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: Skyscraper(), seeds: 1...30).isEmpty)
        #expect(soundnessViolations(of: TwoStringKite(), seeds: 1...30).isEmpty)
        #expect(soundnessViolations(of: EmptyRectangle(), seeds: 1...30).isEmpty)
    }
}
