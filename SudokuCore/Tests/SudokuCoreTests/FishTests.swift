import Testing
import SudokuCore

@Suite struct FishTests {
    @Test func xWing() throws {
        let b = board(digit: 5, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(7, 2), rc(0, 6)])
        let step = try #require(BasicFish(size: 2).find(in: b))
        #expect(step.technique == .xWing)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(7, 2), digit: 5), CellDigit(cell: rc(0, 6), digit: 5)])
        #expect(step.regions == [.row(1), .row(4), .column(2), .column(6)])
    }

    @Test func swordfish() throws {
        let b = board(digit: 3, onlyIn: [
            rc(0, 1), rc(0, 4), rc(3, 4), rc(3, 7), rc(6, 1), rc(6, 7), rc(2, 1), rc(8, 4),
        ])
        #expect(BasicFish(size: 2).find(in: b) == nil)
        let step = try #require(BasicFish(size: 3).find(in: b))
        #expect(step.technique == .swordfish)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(2, 1), digit: 3), CellDigit(cell: rc(8, 4), digit: 3)])
    }

    @Test func jellyfish() throws {
        let b = board(digit: 9, onlyIn: [
            rc(0, 0), rc(0, 2), rc(2, 2), rc(2, 4), rc(4, 4), rc(4, 6), rc(6, 6), rc(6, 0), rc(8, 0),
        ])
        #expect(BasicFish(size: 2).find(in: b) == nil)
        #expect(BasicFish(size: 3).find(in: b) == nil)
        let step = try #require(BasicFish(size: 4).find(in: b))
        #expect(step.technique == .jellyfish)
        #expect(step.eliminations == [CellDigit(cell: rc(8, 0), digit: 9)])
    }

    @Test func nothingOnEmptyBoard() {
        for size in 2...4 { #expect(BasicFish(size: size).find(in: emptyBoard()) == nil) }
    }

    @Test(arguments: 2...4)
    func sound(size: Int) {
        #expect(soundnessViolations(of: BasicFish(size: size), seeds: 1...30).isEmpty)
    }
}

@Suite struct FinnedFishTests {
    @Test func finnedXWing() throws {
        // Rows 1 and 4 on columns 2/6, fin at (4,7) in box 5.
        let b = board(digit: 2, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(4, 7), rc(3, 6)])
        #expect(BasicFish(size: 2).find(in: b) == nil)
        let step = try #require(FinnedFish(size: 2).find(in: b))
        #expect(step.technique == .finnedXWing)
        #expect(step.eliminations == [CellDigit(cell: rc(3, 6), digit: 2)])
        #expect(step.regions.last == .box(5))
    }

    @Test func finnedSwordfish() throws {
        // Rows 0, 3, 6 on columns 1/4/7, fin at (6,8) in box 8.
        let b = board(digit: 8, onlyIn: [
            rc(0, 1), rc(0, 4), rc(3, 4), rc(3, 7), rc(6, 1), rc(6, 7), rc(6, 8), rc(8, 7),
        ])
        let step = try #require(FinnedFish(size: 3).find(in: b))
        #expect(step.technique == .finnedSwordfish)
        #expect(step.eliminations == [CellDigit(cell: rc(8, 7), digit: 8)])
    }

    @Test func plainXWingHasNoFin() {
        // Rows give a basic X-Wing; the column view has fins in different boxes.
        let b = board(digit: 5, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(7, 2), rc(0, 6)])
        #expect(FinnedFish(size: 2).find(in: b) == nil)
    }

    @Test(arguments: 2...3)
    func sound(size: Int) {
        #expect(soundnessViolations(of: FinnedFish(size: size), seeds: 1...30).isEmpty)
    }
}
