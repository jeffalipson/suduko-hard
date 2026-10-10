import Testing
import SudokuCore

@Suite struct ClassicGeneratorTests {
    @Test(arguments: [Tier.easy, .medium, .hard, .expert, .fiendish])
    func generatesRequestedTier(tier: Tier) throws {
        var rng = SplitMix64(seed: 42)
        let p = try #require(ClassicGenerator().generate(tier: tier, using: &rng))
        #expect(p.mode == .classic)
        #expect(p.grade.tier == tier)
        #expect(p.cages.isEmpty)
        #expect(isValidSolution(p.solution))
        #expect(BruteForceSolver.countSolutions(p.givens) == 1)
        #expect(Grader.grade(p.givens)?.grade == p.grade)
        for c in 0..<81 {
            if p.givens[c] != 0 { #expect(p.givens[c] == p.solution[c]) }
            #expect((p.givens[c] == 0) == (p.givens[80 - c] == 0), "not symmetric at \(c)")
        }
    }

    @Test(arguments: [Tier.diabolical, .nightmare])
    func generatesChainTiers(tier: Tier) throws {
        var rng = SplitMix64(seed: 3)
        let p = try #require(ClassicGenerator().generate(tier: tier, using: &rng))
        #expect(p.grade.tier == tier)
        #expect(BruteForceSolver.countSolutions(p.givens) == 1)
        #expect(Grader.grade(p.givens)?.grade == p.grade)
    }

    @Test func expiredDeadlineReturnsNil() {
        var rng = SplitMix64(seed: 1)
        let past = ContinuousClock.now - .seconds(1)
        #expect(ClassicGenerator().generate(tier: .easy, using: &rng, deadline: past) == nil)
    }

    @Test func sameSeedSamePuzzle() {
        var a = SplitMix64(seed: 9)
        var b = SplitMix64(seed: 9)
        #expect(ClassicGenerator().generate(tier: .medium, using: &a) == ClassicGenerator().generate(tier: .medium, using: &b))
    }
}
