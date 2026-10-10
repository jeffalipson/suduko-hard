import Testing
import SudokuCore

@Suite struct InnieOutieTests {
    func cages(_ list: [([Int], Int)]) -> Board {
        Board(values: Array(repeating: 0, count: 81), cages: list.map { Cage(cells: $0.0, sum: $0.1) })
    }

    @Test func innie() throws {
        let b = cages([
            ([rc(0, 0), rc(0, 1), rc(0, 2)], 6), ([rc(0, 3), rc(0, 4), rc(0, 5)], 15),
            ([rc(0, 6), rc(0, 7)], 15), ([rc(0, 8), rc(1, 8)], 10),
        ])
        let step = try #require(InnieOutie.oneHouse.find(in: b))
        #expect(step.technique == .innieOutie1)
        #expect(step.placements == [CellDigit(cell: rc(0, 8), digit: 9)])
        #expect(step.regions == [.row(0)])
    }

    @Test func outie() throws {
        let b = cages([
            ([rc(0, 0), rc(0, 1), rc(0, 2)], 6), ([rc(0, 3), rc(0, 4), rc(0, 5)], 15),
            ([rc(0, 6), rc(0, 7), rc(0, 8), rc(1, 8)], 30),
        ])
        let step = try #require(InnieOutie.oneHouse.find(in: b))
        #expect(step.placements == [CellDigit(cell: rc(1, 8), digit: 6)])
    }

    @Test func twoHouses() throws {
        let rows01 = (0..<18).filter { $0 != rc(1, 8) }
        let b = cages([(rows01, 81), ([rc(1, 8), rc(2, 8)], 10)])
        #expect(InnieOutie.oneHouse.find(in: b) == nil)
        let step = try #require(InnieOutie.twoHouses.find(in: b))
        #expect(step.technique == .innieOutie2)
        #expect(step.placements == [CellDigit(cell: rc(1, 8), digit: 9)])
        #expect(step.regions == [.row(0), .row(1)])
    }

    @Test func partlyCagedRegionsAreSkipped() {
        let b = cages([([rc(0, 0), rc(0, 1)], 3)])
        #expect(InnieOutie.oneHouse.find(in: b) == nil)
        #expect(InnieOutie.twoHouses.find(in: b) == nil)
        #expect(InnieOutie.manyHouses.find(in: b) == nil)
    }

    @Test func sound() {
        for t in [InnieOutie.oneHouse, .twoHouses, .manyHouses] {
            #expect(killerSoundnessViolations(of: t, seeds: 1...25).isEmpty, "\(t.id)")
        }
    }
}
