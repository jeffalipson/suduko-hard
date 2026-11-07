import Testing
import SudokuCore
import SudokuGame

@Suite struct MistakeConsistencyTests {
    let s = GameSettings()

    @Test func pencilMarksMissingTheAnswerAreFlaggedByHintAndCheckAlike() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2            // answer 4
        g.inputMode = .candidate
        g.input(1, settings: s)
        #expect(HintEngine.diagnose(g) == .mistake(cell: 2, kind: .marksMissAnswer))
        g.checkPuzzle()
        #expect(g.flaggedWrong == [2])
        // Putting the answer back clears both.
        g.restoreAnswerMark(2)
        #expect(g.notes[2] == CandidateSet([1, 4]))
        #expect(g.flaggedWrong.isEmpty)
        #expect(!HintEngine.diagnose(g).isMistake)
        g.undo()
        #expect(g.notes[2] == CandidateSet([1]))
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
