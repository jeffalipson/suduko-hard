import Testing
import SudokuCore

@Suite struct GridTransformTests {
    func samplePuzzle(cages: [Cage] = []) -> Puzzle {
        Puzzle(
            id: "p", mode: cages.isEmpty ? .classic : .killer,
            givens: values(wikiPuzzle), cages: cages, solution: values(wikiSolution),
            grade: Grade(tier: .easy, score: 1), techniquesRequired: [.nakedSingle]
        )
    }

    @Test func identityChangesNothing() {
        #expect(GridTransform.identity.apply(to: samplePuzzle()) == samplePuzzle())
    }

    @Test func transposeMovesCells() {
        let t = GridTransform(digitMap: Array(0...9), rowOrder: Array(0..<9), colOrder: Array(0..<9), transpose: true)
        #expect(t.newCell(for: 1) == 9)
        #expect(t.newCell(for: 0) == 0)
    }

    @Test(arguments: 1...20)
    func randomTransformsPreserveValidityAndUniqueness(seed: Int) {
        var rng = SplitMix64(seed: UInt64(seed))
        let t = GridTransform.random(using: &rng)
        let p = t.apply(to: samplePuzzle())
        #expect(isValidSolution(p.solution))
        #expect(BruteForceSolver.countSolutions(p.givens) == 1)
        #expect(BruteForceSolver.solve(p.givens) == p.solution)
        for c in 0..<81 where p.givens[c] != 0 { #expect(p.givens[c] == p.solution[c]) }
        #expect(Grader.grade(p.givens)?.grade.tier == .easy)
    }

    @Test func randomTransformsDiffer() {
        var rng = SplitMix64(seed: 7)
        let a = GridTransform.random(using: &rng)
        let b = GridTransform.random(using: &rng)
        #expect(a != b)
    }

    @Test func killerPuzzlesKeepDigitsAndCageSums() {
        // Cage of row-0 cells 0 and 1 (digits 5 and 3 in the solution).
        let cage = Cage(cells: [0, 1], sum: 8)
        var rng = SplitMix64(seed: 3)
        let puzzle = samplePuzzle(cages: [cage])
        let t = GridTransform.random(for: puzzle, using: &rng)
        #expect(t.digitMap == Array(0...9))
        let p = t.apply(to: puzzle)
        #expect(p.cages.count == 1)
        #expect(p.cages[0].sum == 8)
        #expect(p.cages[0].cells == [t.newCell(for: 0), t.newCell(for: 1)].sorted())
        #expect(p.cages[0].cells.map { p.solution[$0] }.reduce(0, +) == 8)
    }

    @Test(arguments: [Tier.medium, .hard])
    func transformsPreserveTierOfGeneratedPuzzles(tier: Tier) throws {
        var rng = SplitMix64(seed: 11)
        let puzzle = try #require(ClassicGenerator().generate(tier: tier, using: &rng))
        for _ in 0..<10 {
            let p = GridTransform.random(for: puzzle, using: &rng).apply(to: puzzle)
            #expect(Grader.grade(p.givens)?.grade.tier == tier)
        }
    }
}
