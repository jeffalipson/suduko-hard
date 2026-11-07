import Testing
import SudokuCore
import SudokuGame

@Suite struct MistakeConsistencyTests {
    let s = GameSettings()

    @Test func partialPencilMarksAreNotMistakes() {
        // Snyder-style marks: a lone candidate that isn't the cell's answer.
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2            // answer 4
        g.inputMode = .candidate
        g.input(1, settings: s)
        #expect(!HintEngine.diagnose(g).isMistake)
        g.checkPuzzle()
        #expect(g.flaggedWrong.isEmpty)
        // The ignored marks don't feed the hint: cell 2 keeps its real candidates.
        #expect(HintEngine.playerBoard(g).candidates[2].contains(4))
    }

    @Test func answerCrossedOutInAutoPencilIsFlaggedByHintAndCheckAlike() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setAutoCandidates(true)
        g.selected = 2            // answer 4
        g.inputMode = .candidate
        g.input(4, settings: s)   // cross it out
        #expect(HintEngine.diagnose(g) == .mistake(cell: 2, kind: .removedAnswer))
        g.checkPuzzle()
        #expect(g.flaggedWrong == [2])
        // Putting it back clears both, and is undoable.
        g.restoreAnswerMark(2)
        #expect(g.displayedNotes(2).contains(4))
        #expect(g.flaggedWrong.isEmpty)
        #expect(!HintEngine.diagnose(g).isMistake)
        g.undo()
        #expect(!g.displayedNotes(2).contains(4))
    }

    @Test func emptyCellsAreNotMistakes() {
        let g = GameSession(puzzle: classicPuzzle())
        #expect(!HintEngine.diagnose(g).isMistake)
    }

    @Test func removingTheAnswerInAutoModeIsAMistakeThatCheckFinds() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setAutoCandidates(true)
        g.selected = 2
        g.inputMode = .candidate
        g.input(4, settings: s)   // remove the answer
        #expect(HintEngine.diagnose(g).isMistake)
        g.checkPuzzle()
        #expect(g.flaggedWrong == [2])
        g.selected = 2
        g.checkCell()
        #expect(g.flaggedWrong == [2])
    }

    @Test func hintMistakeAlwaysMeansCheckFindsSomething() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(9, settings: s)   // wrong digit
        #expect(HintEngine.diagnose(g).isMistake)
        g.checkPuzzle()
        #expect(!g.flaggedWrong.isEmpty)
    }
}
