import Foundation
import Testing
import SudokuCore

@Suite struct MathdokuModelTests {
    // 4×4 cells: index = row * 4 + column.
    @Test func cageArithmetic() {
        #expect(MathCage(cells: [0, 1], op: .add, target: 7).satisfies([3, 4]))
        #expect(!MathCage(cells: [0, 1], op: .add, target: 7).satisfies([3, 3]))
        #expect(MathCage(cells: [0, 1], op: .subtract, target: 2).satisfies([1, 3]))      // either order
        #expect(MathCage(cells: [0, 1], op: .divide, target: 2).satisfies([4, 2]))
        #expect(!MathCage(cells: [0, 1], op: .divide, target: 2).satisfies([3, 2]))
        #expect(MathCage(cells: [0, 1, 4], op: .multiply, target: 24).satisfies([2, 3, 4]))
        #expect(MathCage(cells: [5], op: .given, target: 3).satisfies([3]))
        #expect(MathCage(cells: [0, 1], op: .hidden, target: 2).satisfies([1, 3]))        // 3 − 1
        #expect(MathCage(cells: [0, 1], op: .hidden, target: 2).satisfies([1, 2]))        // 2 ÷ 1 or 2 × 1
        #expect(!MathCage(cells: [0, 1, 2], op: .hidden, target: 1).satisfies([4, 2, 1])) // − only on 2 cells
    }

    @Test func labels() {
        #expect(MathCage(cells: [0, 1], op: .add, target: 7).label == "7+")
        #expect(MathCage(cells: [0, 1], op: .subtract, target: 2).label == "2−")
        #expect(MathCage(cells: [0, 1], op: .multiply, target: 12).label == "12×")
        #expect(MathCage(cells: [0, 1], op: .divide, target: 3).label == "3÷")
        #expect(MathCage(cells: [0], op: .given, target: 4).label == "4")
        #expect(MathCage(cells: [0, 1], op: .hidden, target: 6).label == "6")
    }

    @Test func fillingsAllowRepeatsOnlyAcrossLines() {
        let all = Array(repeating: CandidateSet.range(1...4), count: 16)
        // Straight cage (one row): no repeats.
        let straight = MathCage(cells: [0, 1], op: .multiply, target: 4)
        #expect(Set(straight.fillings(n: 4, candidates: all)) == [[1, 4], [4, 1]])
        // L-shaped cage: cells 0 and 5 share neither row nor column, so they may repeat.
        let bent = MathCage(cells: [0, 1, 5], op: .multiply, target: 12)
        let fs = bent.fillings(n: 4, candidates: all)
        #expect(fs.contains([2, 3, 2]))
        #expect(!fs.contains([3, 3, 4].reversed()))       // 1 and 5 share column 1: no repeat
        #expect(fs.allSatisfy { $0[0] != $0[1] && $0[1] != $0[2] })
    }

    @Test func possibleDigitsUseOnlyTheCageArithmetic() {
        // 9×9: a 2-cell 7+ can't hold 7, 8 or 9.
        #expect(MathCage(cells: [0, 1], op: .add, target: 7).possibleDigits(n: 9).digits == [1, 2, 3, 4, 5, 6])
        // A 2-cell 12× in a row: 3×4 or 2×6 (6×2 too); never 1, 5, 7, 8, 9.
        #expect(MathCage(cells: [0, 1], op: .multiply, target: 12).possibleDigits(n: 9).digits == [2, 3, 4, 6])
        // 2-cell 4÷ in a 9×9: 1-4, 2-8.
        #expect(MathCage(cells: [0, 1], op: .divide, target: 4).possibleDigits(n: 9).digits == [1, 2, 4, 8])
        // 2-cell 8− in a 9×9: only 1 and 9.
        #expect(MathCage(cells: [0, 1], op: .subtract, target: 8).possibleDigits(n: 9).digits == [1, 9])
    }

    @Test func boardStartsWithGivensPlacedAndLinesCleared() {
        let p = MathdokuPuzzle.sample4
        let b = MathdokuBoard(puzzle: p)
        #expect(b.values[15] == 4)                        // the single-cell cage
        #expect(!b.candidates[3].contains(4))             // same column
        #expect(!b.candidates[12].contains(4))            // same row
        #expect(b.candidates[0] == .range(1...4))
    }

    @Test func puzzleRoundTripsThroughJSON() throws {
        let p = MathdokuPuzzle.sample4
        let back = try JSONDecoder().decode(MathdokuPuzzle.self, from: JSONEncoder().encode(p))
        #expect(back == p)
    }
}
