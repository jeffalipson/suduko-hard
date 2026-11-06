import Testing
import SudokuCore

@Suite struct MathdokuSolverTests {
    @Test func samplePuzzleSolvesWithCageArithmeticAndSingles() {
        let g = MathdokuGrader.grade(.sample4)
        #expect(g.solution == MathdokuPuzzle.sample4.solution)
        #expect(g.level == 1)
    }

    @Test(arguments: [(MathdokuFixtures.hard11, 3), (MathdokuFixtures.really14, 4), (MathdokuFixtures.nightmare12, 4)])
    func spikePuzzlesGradeAtTheirLevel(puzzle: MathdokuPuzzle, level: Int) {
        let g = MathdokuGrader.grade(puzzle)
        #expect(g.solution == puzzle.solution)
        #expect(g.level == level)
        // One level lower can't finish it.
        #expect(MathdokuGrader.grade(puzzle, maxLevel: level - 1).solution == nil)
    }

    @Test func cageArithmeticStepRemovesImpossibleDigits() {
        // A 9×9 with a 2-cell 7+ in the corner; everything else open.
        let cages = [MathCage(cells: [0, 1], op: .add, target: 7)]
        let board = MathdokuBoard(n: 9, cages: cages, values: Array(repeating: 0, count: 81))
        let step = MathdokuSolver.step(.cageArithmetic, on: board)
        #expect(step?.technique == .cageArithmetic)
        let removed = Set(step?.eliminations.filter { $0.cell == 0 }.map(\.digit) ?? [])
        #expect(removed == [7, 8, 9])
    }

    @Test func nakedPairInARow() {
        // 4×4 row 0: cells 0 and 1 hold only {1,2}; cell 2 has {1,2,3}.
        var board = MathdokuBoard(n: 4, cages: [], values: Array(repeating: 0, count: 16))
        board.candidates[0] = CandidateSet([1, 2])
        board.candidates[1] = CandidateSet([1, 2])
        board.candidates[2] = CandidateSet([1, 2, 3])
        board.candidates[3] = CandidateSet([1, 2, 3, 4])
        let step = MathdokuSolver.step(.nakedPair, on: board)
        #expect(Set(step?.eliminations ?? []) == [CellDigit(cell: 2, digit: 1), CellDigit(cell: 2, digit: 2),
                                                   CellDigit(cell: 3, digit: 1), CellDigit(cell: 3, digit: 2)])
    }

    @Test func steppingThroughNeverRemovesTheAnswer() {
        let p = MathdokuFixtures.really14
        var board = MathdokuBoard(puzzle: p)
        while let step = MathdokuSolver.nextStep(on: board) {
            for e in step.eliminations { #expect(p.solution[e.cell] != e.digit, "\(step.technique) removed the answer") }
            for pl in step.placements { #expect(p.solution[pl.cell] == pl.digit) }
            board.apply(step)
        }
        #expect(board.values == p.solution)
    }
}
