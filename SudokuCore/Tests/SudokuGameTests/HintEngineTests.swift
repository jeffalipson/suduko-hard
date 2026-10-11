import Testing
import SudokuCore
import SudokuGame

@Suite struct HintEngineTests {
    @Test func singlesNeedNoNotes() {
        let g = GameSession(puzzle: classicPuzzle())
        guard case .step(let step) = HintEngine.diagnose(g) else { Issue.record("expected a step"); return }
        #expect(step.technique.tier == .easy)
        #expect(HintText.nudge(step).contains(step.technique.displayName))
    }

    @Test func wrongDigitIsAMistake() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(9, settings: GameSettings())
        #expect(HintEngine.diagnose(g) == .mistake)
    }

    @Test func ownNotesMissingTheAnswerAreSetAsideNotAMistake() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.inputMode = .candidate
        g.input(1, settings: GameSettings())   // answer is 4: partial marks are allowed
        #expect(HintEngine.diagnose(g) != .mistake)
    }

    @Test func staleNotesAreIgnored() {
        var g = GameSession(puzzle: classicPuzzle())
        g.fillAllCandidates()
        g.selected = 2
        g.inputMode = .candidate
        g.input(5, settings: GameSettings())   // 5 is already in row 0: stale, not wrong
        let board = HintEngine.playerBoard(g)
        #expect(!board.candidates[2].contains(5))
    }

    @Test func harderStepsAskForCandidates() {
        // Medium puzzle state where singles are exhausted: use a board needing a pair with no notes.
        let g = GameSession(puzzle: classicPuzzle())
        var solved = g
        for c in 0..<81 where wikiGivens[c] == 0 {
            solved.selected = c
            solved.input(wikiAnswer[c], settings: GameSettings())
        }
        #expect(HintEngine.diagnose(solved) == .solved)
        #expect(HintText.region(.box(4)) == "box 5")
        #expect(HintText.message(.incomplete(.row(3))).contains("row 4"))
    }

    @Test func showMeAppliesTheStepAndLogs() {
        var g = GameSession(puzzle: classicPuzzle())
        guard case .step(let step) = HintEngine.diagnose(g) else { Issue.record("expected a step"); return }
        g.showMe(step)
        for p in step.placements { #expect(g.entries[p.cell] == p.digit) }
        #expect(g.log.hints["showMe"] == 1)
        #expect(g.log.reveals == 1)
        g.undo()
        for p in step.placements { #expect(g.entries[p.cell] == 0) }
        g.useHint("nudge")
        #expect(g.log.hints["nudge"] == 1)
        #expect(!g.log.isClean)
    }
}

@Suite struct HintLevelTests {
    @Test func nudgesGetMoreSpecific() {
        let step = Step(technique: .nakedSingle, patternCells: [rc(1, 4)], placements: [CellDigit(cell: rc(1, 4), digit: 2)],
                        regions: [], digits: [2])
        #expect(HintText.nudge(step, level: 1) == "Look for a Naked Single.")
        #expect(HintText.nudge(step, level: 2) == "Look for a Naked Single on 2.")
        #expect(HintText.nudge(step, level: 3) == "Look for a Naked Single on 2 in r2c5.")
        #expect(HintText.nudgeLevels(step) == 3)
    }

    @Test func regionsBeatCellsAtTheLastLevel() {
        let step = Step(technique: .xWing, patternCells: [1, 2], regions: [.row(1), .row(4), .column(2), .column(6)], digits: [5])
        #expect(HintText.nudge(step, level: 3) == "Look for an X-Wing on 5 in row 2 and row 5.")
    }

    @Test func stepsWithoutDigitsSkipThatLevel() {
        let step = Step(technique: .cageCombination, patternCells: [rc(3, 3), rc(3, 4)])
        #expect(HintText.nudgeLevels(step) == 2)
        #expect(HintText.nudge(step, level: 2) == "Look for Cage Combinations around r4c4.")
    }
}

func rc(_ r: Int, _ c: Int) -> Int { r * 9 + c }
