import Testing
import SudokuCore

@Suite struct GeometryTests {
    @Test func rowColBox() {
        #expect(Geometry.row(40) == 4)
        #expect(Geometry.col(40) == 4)
        #expect(Geometry.box(0) == 0)
        #expect(Geometry.box(Geometry.cell(4, 4)) == 4)
        #expect(Geometry.box(Geometry.cell(2, 6)) == 2)
        #expect(Geometry.box(80) == 8)
    }

    @Test func housesCoverEveryCellThreeTimes() {
        var counts = [Int](repeating: 0, count: 81)
        for house in Geometry.houses { for c in house { counts[c] += 1 } }
        #expect(Geometry.houses.count == 27)
        #expect(counts.allSatisfy { $0 == 3 })
    }

    @Test func everyCellHasTwentyPeers() {
        #expect(Geometry.peers.allSatisfy { $0.count == 20 })
        #expect(Geometry.sees(0, 8))
        #expect(Geometry.sees(0, 20))
        #expect(!Geometry.sees(0, 40))
        #expect(!Geometry.sees(5, 5))
    }

    @Test func regionFromHouse() {
        #expect(Region(house: 0) == .row(0))
        #expect(Region(house: 10) == .column(1))
        #expect(Region(house: 26) == .box(8))
        #expect(Region.box(4).cells == Geometry.boxes[4])
        #expect(Region.column(2).cells == Geometry.cols[2])
    }
}
