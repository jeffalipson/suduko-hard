import Testing
import SudokuCore
import SudokuGame

@Suite struct ShareTests {
    @Test func countsTechniquesBeyondSinglesHardestFirst() throws {
        var rng = SplitMix64(seed: 3)
        let puzzle = try #require(ClassicGenerator().generate(tier: .expert, using: &rng))
        let counts = SolveSummary.techniqueCounts(puzzle)
        #expect(!counts.isEmpty)
        #expect(counts.allSatisfy { $0.technique.tier > .easy && $0.count > 0 })
        #expect(counts.map(\.technique.tier) == counts.map(\.technique.tier).sorted(by: >))
    }

    @Test func shareTextReadsNaturally() {
        var g = GameSession(puzzle: classicPuzzle())
        g.tick(1421)
        let text = SolveSummary.shareText(session: g, counts: [(.xWing, 1), (.nakedPair, 2)])
        #expect(text.contains("I solved an Easy Classic Sudoku in 23:41."))
        #expect(text.contains("It took 1 X-Wing, 2 Naked Pairs and plenty of singles."))
        #expect(text.contains("Clean solve"))
        let plain = SolveSummary.shareText(session: g, counts: [])
        #expect(plain.contains("It took only singles."))
    }

    @Test func pluralsForAwkwardNames() {
        #expect(SolveSummary.phrase(.boxLineReduction, 2) == "2 Box/Line Reductions")
        #expect(SolveSummary.phrase(.uniqueRectangle2, 3) == "3 Unique Rectangles (Type 2)")
        #expect(SolveSummary.phrase(.innieOutie1, 2) == "2 uses of the 45 Rule (One House)")
        #expect(SolveSummary.phrase(.aic, 1) == "1 Alternating Inference Chain")
    }
}

@Suite struct ExplainTests {
    @Test func chainExplanationWalksEveryLink() throws {
        var b = emptyKillerFreeBoard()
        b.candidates[0] = CandidateSet([4, 8])
        b.candidates[48] = CandidateSet([4, 8])
        for row in 0..<9 where row != 2 && row != 5 { b.eliminate(4, at: row * 9 + 1) }
        let step = try #require(AlternatingChain.aic.find(in: b))
        let frames = StepExplainer.frames(for: step, on: b)
        #expect(frames.count == step.patternCandidates.count + 2)
        #expect(frames[0].falsehoods == [step.patternCandidates[0]])
        #expect(frames[1].truths.contains(step.patternCandidates[1]))
        #expect(frames.contains { $0.text.contains("can only go in") || $0.text.contains("only two candidates") })
        #expect(frames.last!.falsehoods.contains(step.eliminations[0]))
    }

    @Test func forcingChainExplanationCoversEveryBranch() throws {
        let inkala = Board.parse("800000000003600000070090200050007000000045700000100030001000068008500010090000400")!
        let fiendish = LogicalSolver(techniques: TechniqueCatalog.classic.filter { $0.id.tier <= .fiendish })
        let stuck = fiendish.solve(Board(values: inkala)).board
        let step = try #require([ForcingChain.cell, .unit, .digit, .nested].lazy.compactMap { $0.find(in: stuck) }.first)
        let frames = StepExplainer.frames(for: step, on: stuck)
        let branches = step.technique == .digitForcingChain && step.patternCandidates.count == 1 ? 2 : step.patternCandidates.count
        #expect(frames.count == branches + 1)
        #expect(frames.last!.text.contains("Every possibility"))
    }

    @Test func everyTechniqueGetsAtLeastTwoFrames() {
        let step = Step(technique: .skyscraper, patternCells: [1, 2], patternCandidates: [CellDigit(cell: 1, digit: 4)],
                        eliminations: [CellDigit(cell: 5, digit: 4)], digits: [4])
        let frames = StepExplainer.frames(for: step, on: emptyKillerFreeBoard())
        #expect(frames.count >= 2)
        #expect(frames.last!.falsehoods == step.eliminations)
    }

    func emptyKillerFreeBoard() -> Board { Board(values: Array(repeating: 0, count: 81)) }
}
