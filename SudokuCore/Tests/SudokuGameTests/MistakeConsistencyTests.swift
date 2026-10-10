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
        #expect(HintEngine.diagnose(g) != .mistake)
        g.checkPuzzle()
        #expect(g.flaggedWrong.isEmpty)
        // The ignored marks don't feed the hint: cell 2 keeps its real candidates.
        #expect(HintEngine.playerBoard(g).candidates[2].contains(4))
    }

    @Test func removingTheAnswerInAutoModeIsAMistakeThatCheckFinds() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setAutoCandidates(true)
        g.selected = 2
        g.inputMode = .candidate
        g.input(4, settings: s)   // remove the answer
        #expect(HintEngine.diagnose(g) == .mistake)
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
        #expect(HintEngine.diagnose(g) == .mistake)
        g.checkPuzzle()
        #expect(!g.flaggedWrong.isEmpty)
    }
}
