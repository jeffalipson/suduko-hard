import Testing
import SudokuCore

@Suite struct ChainTests {
    @Test func xCycleFindsSkyscraperAsAChain() throws {
        let b = board(digit: 4, onlyIn: [rc(1, 0), rc(1, 4), rc(6, 0), rc(6, 5), rc(0, 5), rc(2, 5)])
        let step = try #require(AlternatingChain.xCycle.find(in: b))
        #expect(step.technique == .xCycle)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 5), digit: 4), CellDigit(cell: rc(2, 5), digit: 4)])
        #expect(step.patternCandidates.count == 4)
        #expect(step.digits == [4])
    }

    @Test func xyChainFindsXYWingAsAChain() throws {
        var b = emptyBoard()
        b.candidates[rc(4, 4)] = CandidateSet([1, 2])
        b.candidates[rc(4, 0)] = CandidateSet([1, 3])
        b.candidates[rc(0, 4)] = CandidateSet([2, 3])
        #expect(AlternatingChain.xCycle.find(in: b) == nil)
        let step = try #require(AlternatingChain.xyChain.find(in: b))
        #expect(step.technique == .xyChain)
        #expect(step.eliminations == [CellDigit(cell: rc(0, 0), digit: 3)])
        #expect(step.patternCandidates.count == 6)
    }

    @Test func aicFindsWWingAsAChain() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([4, 8])
        b.candidates[rc(5, 3)] = CandidateSet([4, 8])
        for row in 0..<9 where row != 2 && row != 5 { b.eliminate(4, at: rc(row, 1)) }
        let step = try #require(AlternatingChain.aic.find(in: b))
        #expect(step.technique == .aic)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 3), digit: 8), CellDigit(cell: rc(5, 0), digit: 8)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(AlternatingChain.xCycle.find(in: emptyBoard()) == nil)
        #expect(AlternatingChain.aic.find(in: emptyBoard()) == nil)
    }

    @Test func newIDsAreDiabolicalOrNightmare() {
        #expect(TechniqueID.aic.tier == .diabolical)
        #expect(TechniqueID.sueDeCoq.tier == .diabolical)
        #expect(TechniqueID.nestedForcingChain.tier == .nightmare)
        #expect(TechniqueID.xCycle.displayName == "X-Cycle")
    }

    @Test func sound() {
        #expect(soundnessViolations(of: AlternatingChain.xCycle, seeds: 1...20).isEmpty)
        #expect(soundnessViolations(of: AlternatingChain.xyChain, seeds: 1...20).isEmpty)
        #expect(soundnessViolations(of: AlternatingChain.aic, seeds: 1...20).isEmpty)
    }
}
