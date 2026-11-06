import Foundation
import Testing
import SudokuCore
import SudokuGame

@Suite struct MathdokuSessionTests {
    let s = GameSettings()
    let p = MathdokuPuzzle.sample4      // 4×4; cells 13 and 15 are givens

    @Test func givensArePlacedAndLocked() {
        var g = MathdokuSession(puzzle: p)
        #expect(g.entries[15] == 4 && g.entries[13] == 2)
        g.selected = 15
        g.input(1, settings: s)
        #expect(g.entries[15] == 4)
    }

    @Test func placingTogglingAndDigitsOutOfRange() {
        var g = MathdokuSession(puzzle: p)
        g.selected = 0
        g.input(2, settings: s)
        #expect(g.entries[0] == 2)
        g.input(2, settings: s)
        #expect(g.entries[0] == 0)
        g.input(5, settings: s)          // only 1–4 in a 4×4
        #expect(g.entries[0] == 0)
    }

    @Test func autoRemoveClearsRowAndColumnButNotTheRestOfTheCage() {
        var g = MathdokuSession(puzzle: p)
        var settings = GameSettings()
        settings.autoRemoveCandidates = true
        g.inputMode = .candidate
        for cell in [1, 3, 5, 8] { g.selected = cell; g.input(2, settings: settings) }
        g.inputMode = .normal
        g.selected = 0
        g.input(2, settings: settings)
        #expect(!g.notes[1].contains(2))   // same row
        #expect(!g.notes[8].contains(2))   // same column
        #expect(g.notes[5].contains(2))    // r2c2: neither row 1 nor column 1
    }

    @Test func undoRedo() {
        var g = MathdokuSession(puzzle: p)
        g.selected = 2
        g.input(4, settings: s)
        g.undo()
        #expect(g.entries[2] == 0)
        g.redo()
        #expect(g.entries[2] == 4)
    }

    @Test func autoPencilUsesLinesAndCageArithmetic() {
        var g = MathdokuSession(puzzle: p)
        g.setAutoCandidates(true)
        // Cell 7 is in the 2÷ cage {7, 11}: only 1, 2 and 4 make 2÷ in a 4×4.
        #expect(!g.displayedNotes(7).contains(3))
        // Cell 3 shares column 3 with the given 4 at cell 15.
        #expect(!g.displayedNotes(3).contains(4))
    }

    @Test func checkAndReveal() {
        var g = MathdokuSession(puzzle: p)
        g.selected = 0
        g.input(1, settings: s)          // wrong (answer 2)
        g.checkPuzzle()
        #expect(g.flaggedWrong == [0])
        g.revealCell(settings: s)
        #expect(g.entries[0] == 2)
        #expect(g.flaggedWrong.isEmpty)
        #expect(g.log.reveals == 1)
    }

    @Test func coloursAndMovement() {
        var g = MathdokuSession(puzzle: p)
        g.setColor(4, at: 6)
        #expect(g.color(of: 6) == 4)
        g.undo()
        #expect(g.color(of: 6) == 0)
        g.selected = 3
        g.moveSelection(rows: 0, columns: 1)
        #expect(g.selected == 3)         // right edge of a 4×4
        g.moveSelection(rows: 1, columns: 0)
        #expect(g.selected == 7)
    }

    @Test func solvingByHintsReachesTheAnswer() {
        var g = MathdokuSession(puzzle: p)
        g.setAutoCandidates(true)
        var guardCount = 0
        while case .step(let step) = MathdokuHintEngine.diagnose(g), guardCount < 100 {
            g.showMe(step)
            guardCount += 1
        }
        #expect(g.isComplete)
    }

    @Test func hintsPointOutMistakesFirst() {
        var g = MathdokuSession(puzzle: p)
        g.selected = 5
        g.input(1, settings: s)          // answer is 4
        let d = MathdokuHintEngine.diagnose(g)
        #expect(d == .mistake(cell: 5, kind: .wrongDigit))
        #expect(MathHintText.message(d, level: 3, puzzle: p) == "One of the digits on the board is wrong. It's r2c2.")
    }

    @Test func hintTextNamesCages() {
        let step = MathStep(technique: .cageArithmetic, cells: [0, 1, 4], digits: [4], regions: [.cage(0)])
        let text = MathHintText.message(.step(step), level: 3, puzzle: p)
        #expect(text == "Try Cage Arithmetic with 4 in the 6+ cage.")
        #expect(MathHintText.message(.step(step), level: 1, puzzle: p) == "Try Cage Arithmetic.")
    }

    @Test func savesAndLoads() throws {
        var g = MathdokuSession(puzzle: p)
        g.selected = 0
        g.input(2, settings: s)
        g.setColor(1, at: 0)
        let back = try JSONDecoder().decode(MathdokuSession.self, from: JSONEncoder().encode(g))
        #expect(back == g)
    }

    @Test func voiceOverReadsTheCage() {
        let g = MathdokuSession(puzzle: p)
        #expect(g.spokenDescription(of: 0) == "Row 1, column 1. Empty. Cage 6+, 3 cells.")
    }

    @Test func everyTechniqueHasLessonText() {
        for t in MathTechnique.allCases {
            #expect(!MathLessonText.summary(t).isEmpty)
            #expect(!MathLessonText.body(t).isEmpty)
        }
    }
}
