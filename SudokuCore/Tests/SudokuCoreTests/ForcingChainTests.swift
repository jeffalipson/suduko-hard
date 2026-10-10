import Testing
import SudokuCore

@Suite struct ForcingChainTests {
    @Test func contradictionDetection() {
        #expect(!emptyBoard().isContradictory)
        var noCandidates = emptyBoard()
        noCandidates.candidates[0] = .empty
        #expect(noCandidates.isContradictory)
        var missingDigit = emptyBoard()
        for c in Geometry.rows[3] { missingDigit.eliminate(6, at: c) }
        #expect(missingDigit.isContradictory)
    }

    @Test func forcingChainsCrackInkalaWhereFiendishGetsStuck() throws {
        let fiendish = LogicalSolver(techniques: TechniqueCatalog.classic.filter { $0.id.tier <= .fiendish })
        let stuck = fiendish.solve(Board(values: values(inkalaPuzzle))).board
        let solution = try #require(BruteForceSolver.solve(values(inkalaPuzzle)))
        let steps = [ForcingChain.cell, .unit, .digit, .nested].compactMap { $0.find(in: stuck) }
        #expect(!steps.isEmpty)
        for step in steps { #expect(isSound(step, solution: solution), "\(step.technique)") }
    }

    @Test func nothingWhenEveryBranchContradicts() {
        var b = emptyBoard()
        for d in 1...9 { for c in Geometry.rows[0] { b.eliminate(d, at: c) } }
        for forcing in [ForcingChain.cell, .unit, .digit, .nested] { #expect(forcing.find(in: b) == nil) }
    }

    @Test func sound() {
        for forcing in [ForcingChain.cell, .unit, .digit, .nested] {
            #expect(soundnessViolations(of: forcing, seeds: 1...4).isEmpty, "\(forcing.id)")
        }
    }
}
