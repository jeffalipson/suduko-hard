import Testing
import SudokuCore

@Suite struct ColoringTests {
    @Test func colorWrap() throws {
        // Chain (0,0)A-(0,4)B-(4,4)A-(4,1)B-(1,1)A; (0,0) and (1,1) share box 0.
        // (2,2) keeps box 0 from being a strong link.
        let b = board(digit: 1, onlyIn: [rc(0, 0), rc(0, 4), rc(4, 4), rc(4, 1), rc(1, 1), rc(2, 2)])
        let step = try #require(SimpleColoring().find(in: b))
        #expect(step.technique == .simpleColoring)
        #expect(Set(step.eliminations) == Set([rc(0, 0), rc(1, 1), rc(4, 4)].map { CellDigit(cell: $0, digit: 1) }))
    }

    @Test func colorTrap() throws {
        // Chain (0,0)A -box0- (1,2)B -col2- (5,2)A -row5- (5,6)B; (0,6) sees A and B.
        // (0,3) and (8,6) stop row 0 and column 6 from being strong links.
        let b = board(digit: 1, onlyIn: [rc(0, 0), rc(1, 2), rc(5, 2), rc(5, 6), rc(0, 6), rc(0, 3), rc(8, 6)])
        let step = try #require(SimpleColoring().find(in: b))
        #expect(step.eliminations == [CellDigit(cell: rc(0, 6), digit: 1)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(SimpleColoring().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: SimpleColoring(), seeds: 1...30).isEmpty)
    }
}
