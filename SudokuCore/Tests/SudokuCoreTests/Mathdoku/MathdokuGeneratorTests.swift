import Testing
import SudokuCore

@Suite struct MathdokuGeneratorTests {
    @Test(arguments: [Tier.easy, .medium, .hard])
    func generatesTheTiersGridAndLevel(tier: Tier) throws {
        var rng = SplitMix64(seed: 42)
        let p = try #require(MathdokuGenerator().generate(tier: tier, using: &rng, deadline: .now + .seconds(60)))
        let cfg = MathdokuGenerator.config(tier)
        #expect(p.n == cfg.n)
        #expect(p.tier == tier)
        // A Latin square that every cage agrees with.
        let b = MathdokuBoard(n: p.n, cages: p.cages, values: p.solution)
        #expect(b.isConsistent)
        #expect(p.cages.allSatisfy { $0.satisfies($0.cells.map { p.solution[$0] }) })
        #expect(Set(p.cages.flatMap(\.cells)).count == p.cellCount)
        // − and ÷ only on two-cell cages.
        #expect(p.cages.allSatisfy { ![.subtract, .divide].contains($0.op) || $0.cells.count == 2 })
        // The grader solves it at the tier's level, not below.
        #expect(MathdokuGrader.grade(p).level == cfg.level)
        #expect(MathdokuGrader.grade(p, maxLevel: cfg.level - 1).solution == nil || cfg.level == 1)
    }

    @Test func nightmareHidesEveryOperation() throws {
        var rng = SplitMix64(seed: 7)
        let p = try #require(MathdokuGenerator().generate(tier: .nightmare, using: &rng, deadline: .now + .seconds(120)))
        #expect(p.hidesOperations)
        #expect(p.cages.allSatisfy { $0.op == .hidden || $0.cells.count == 1 })
        #expect(MathdokuGrader.grade(p).solution == p.solution)
    }

    @Test func cagesAreConnected() throws {
        var rng = SplitMix64(seed: 3)
        let p = try #require(MathdokuGenerator().generate(tier: .medium, using: &rng, deadline: .now + .seconds(60)))
        for cage in p.cages {
            var seen: Set<Int> = [cage.cells[0]]
            var stack = [cage.cells[0]]
            while let c = stack.popLast() {
                for nb in [c - p.n, c + p.n, c % p.n > 0 ? c - 1 : -1, c % p.n < p.n - 1 ? c + 1 : -1]
                where cage.cells.contains(nb) && !seen.contains(nb) {
                    seen.insert(nb)
                    stack.append(nb)
                }
            }
            #expect(seen.count == cage.cells.count)
        }
    }
}
