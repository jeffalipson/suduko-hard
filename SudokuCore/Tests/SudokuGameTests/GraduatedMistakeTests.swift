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
        #expect(HintText.levels(for: d) == 4)
        #expect(HintText.message(d, level: 1) == "You crossed out a candidate that's the right digit.")
        #expect(HintText.message(d, level: 3) == "You crossed out a candidate that's the right digit. It's r1c3.")
        #expect(HintText.message(d, level: 4, answer: 4) == "r1c3 can still be 4.")
        #expect(HintText.fixLabel(d, level: 3) == nil)
        #expect(HintText.fixLabel(d, level: 4) == "Put it back")
        g.restoreAnswerMark(2)
        #expect(g.displayedNotes(2).contains(4))
        #expect(!HintEngine.diagnose(g).isMistake)
    }

    @Test func wrongDigitOffersToEraseOnceNamed() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = rc(4, 4)
        g.input(9, settings: s)
        let d = HintEngine.diagnose(g)
        #expect(HintText.fixLabel(d, level: 2) == nil)
        #expect(HintText.fixLabel(d, level: 3) == "Erase it")
        g.eraseMistake(rc(4, 4))
        #expect(g.entries[rc(4, 4)] == 0)
        #expect(!HintEngine.diagnose(g).isMistake)
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
        #expect(HintText.message(d, level: 1) == "The next step needs every candidate pencilled in row 4. Fill them in, or turn on Auto Pencil.")
        #expect(HintText.offersAutoCandidates(d))
        #expect(!HintText.offersAutoCandidates(.solved))
        let cage = Cage(cells: [21, 12, 13], sum: 15)
        #expect(HintText.message(.incompleteCage(cage)) == "The next step needs every candidate pencilled in the 15 cage at r2c4. Fill them in, or turn on Auto Pencil.")
        #expect(HintText.offersAutoCandidates(.incompleteCage(cage)))
    }

    @Test func nudgeOpeningsReadNaturally() {
        #expect(HintText.nudge(Step(technique: .uniqueCageCombination), level: 1) == "Look for a Unique Cage Combination.")
        #expect(HintText.nudge(Step(technique: .pointing), level: 1) == "Look for Pointing.")
        #expect(HintText.nudge(Step(technique: .innieOutie1), level: 1) == "Use the 45 Rule (One House).")
        #expect(HintText.nudge(Step(technique: .xWing), level: 1) == "Look for an X-Wing.")
    }

    @Test func cageStepsNameTheirCageButHouseStepsDoNot() {
        let cage = Cage(cells: [3, 4], sum: 7)
        let combo = Step(technique: .cageCombination, patternCells: [3, 4])
        #expect(HintText.nudge(combo, level: 2, cages: [cage]) == "Look for Cage Combinations in the 7 cage at r1c4.")
        let pair = Step(technique: .nakedPair, patternCells: [3, 4], regions: [.row(0)], digits: [1, 6])
        #expect(HintText.nudge(pair, level: 3, cages: [cage]) == "Look for a Naked Pair on 1/6 in row 1.")
        let locked = Step(technique: .cageLockedDigit, patternCells: [3, 4], regions: [.row(0)], digits: [2])
        #expect(HintText.nudge(locked, level: 3, cages: [cage]) == "Look for a Cage-Locked Digit on 2 in the 7 cage at r1c4, along row 1.")
    }
}
