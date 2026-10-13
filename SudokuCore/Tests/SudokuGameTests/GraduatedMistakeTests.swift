import Testing
import SudokuCore
import SudokuGame

@Suite struct GraduatedMistakeTests {
    let s = GameSettings()

    @Test func wrongDigitNarrowsDownByLevel() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = rc(4, 4)                      // answer 5
        g.input(9, settings: s)
        let d = HintEngine.diagnose(g)
        #expect(d == .mistake(cell: rc(4, 4), kind: .wrongDigit))
        #expect(HintText.levels(for: d) == 3)
        #expect(HintText.message(d, level: 1) == "One of the digits on the board is wrong.")
        #expect(HintText.message(d, level: 2) == "One of the digits on the board is wrong. It's in box 5.")
        #expect(HintText.message(d, level: 3) == "One of the digits on the board is wrong. It's r5c5.")
    }

    @Test func removedAnswerIsNamedAsSuch() {
        var g = GameSession(puzzle: classicPuzzle())
        g.setAutoCandidates(true)
        g.selected = 2
        g.inputMode = .candidate
        g.input(4, settings: s)                    // cross out the answer
        let d = HintEngine.diagnose(g)
        #expect(d == .mistake(cell: 2, kind: .removedAnswer))
        #expect(HintText.message(d, level: 1) == "One of your crossed-out candidates was the right digit.")
    }

    @Test func pointingOutTheCellCountsAsACheck() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = rc(4, 4)
        g.input(9, settings: s)
        g.pointOutMistake(rc(4, 4))
        #expect(g.flaggedWrong == [rc(4, 4)])
        #expect(g.log.checks == 1)
    }

    @Test func incompleteCandidatesOfferAutoMode() {
        let d = HintDiagnosis.incomplete(.row(3))
        #expect(HintText.message(d, level: 1) == "This hint needs candidates in row 4. Fill them in, or turn on Auto Pencil.")
        #expect(HintText.offersAutoCandidates(d))
        #expect(!HintText.offersAutoCandidates(.solved))
    }
}
