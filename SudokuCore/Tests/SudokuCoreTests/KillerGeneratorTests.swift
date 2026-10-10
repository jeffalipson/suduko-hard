import Testing
import SudokuCore

@Suite struct KillerGeneratorTests {
    @Test(arguments: [Tier.easy, .medium, .hard, .expert, .fiendish])
    func generatesRequestedTier(tier: Tier) throws {
        var rng = SplitMix64(seed: 5)
        let p = try #require(KillerGenerator().generate(tier: tier, using: &rng))
        let rules = KillerRules.forTier(tier)
        #expect(p.mode == .killer)
        #expect(p.grade.tier == tier)
        #expect(p.cages.flatMap(\.cells).sorted() == Array(0..<81))
        for cage in p.cages {
            #expect(cage.cells.map { p.solution[$0] }.reduce(0, +) == cage.sum)
            #expect(cage.cells.count <= rules.cageSizes.upperBound)
        }
        let revealed = (0..<81).filter { c in p.givens[c] != 0 || p.cages.contains { $0.cells == [c] } }.count
        #expect(rules.givens.contains(revealed))
        #expect(BruteForceSolver.countSolutions(p.givens, cages: p.cages) == 1)
        #expect(Grader.grade(p.givens, cages: p.cages, solver: .killer)?.grade == p.grade)
    }

    @Test func rulesFollowTheSpec() {
        #expect(KillerRules.forTier(.easy).givens == 6...12)
        #expect(KillerRules.forTier(.expert).givens == 0...0)
        #expect(KillerRules.forTier(.nightmare).cageSizes == 3...8)
    }
}

@Suite struct KillerMergeTests {
    @Test func expiredDeadlineStopsAZeroGivenAttempt() {
        var rng = SplitMix64(seed: 1)
        let start = ContinuousClock.now
        #expect(KillerGenerator().generate(tier: .nightmare, using: &rng, deadline: start + .milliseconds(1)) == nil)
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test func zeroGivenPuzzlesHaveNoGivens() throws {
        var rng = SplitMix64(seed: 2)
        let p = try #require(KillerGenerator().generate(tier: .expert, using: &rng))
        #expect(p.givens.allSatisfy { $0 == 0 })
        #expect(KillerRules.forTier(.expert).admits(p.cages))
        #expect(!p.cages.contains { $0.cells.count == 1 })
    }
}
