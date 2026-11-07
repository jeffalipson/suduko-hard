import Testing
import SudokuCore

@Suite struct CagePossibleDigitsTests {
    @Test func twoCellCagesDropDigitsNoPairCanUse() {
        #expect(Cage(cells: [0, 1], sum: 7).possibleDigits.digits == [1, 2, 3, 4, 5, 6])
        #expect(Cage(cells: [0, 1], sum: 12).possibleDigits.digits == [3, 4, 5, 7, 8, 9])   // 6+6 repeats
        #expect(Cage(cells: [0, 1], sum: 3).possibleDigits.digits == [1, 2])
        #expect(Cage(cells: [0, 1], sum: 17).possibleDigits.digits == [8, 9])
    }

    @Test func largerCages() {
        #expect(Cage(cells: [0, 1, 2], sum: 6).possibleDigits.digits == [1, 2, 3])
        #expect(Cage(cells: [0, 1, 2], sum: 24).possibleDigits.digits == [7, 8, 9])
        #expect(Cage(cells: Array(0..<9), sum: 45).possibleDigits == .all)
        #expect(Cage(cells: [0, 1, 2, 3], sum: 20).possibleDigits == .all)
    }

    @Test func singleCellCageIsItsSum() {
        #expect(Cage(cells: [4], sum: 6).possibleDigits.digits == [6])
    }
}
