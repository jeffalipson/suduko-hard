import Testing
import SudokuCore
@testable import SudokuGame

/// Killer hints for a player who pencils only part of the board, one box at a time.
@Suite struct KillerHintPartialMarksTests {
    let settings = GameSettings()

    /// Pencils every empty cell of a box with its cage-trimmed candidates (a careful player's marks).
    func pencil(_ cells: [Int], in g: inout GameSession) {
        let board = HintEngine.playerBoard(g)
        g.inputMode = .candidate
        for c in cells where g.entries[c] == 0 && g.notes[c].isEmpty {
            g.selected = c
            let cage = g.puzzle.cages.first { $0.cells.contains(c) }
            for d in board.candidates[c].intersection(cage?.possibleDigits ?? .all).digits { g.input(d, settings: settings) }
        }
        g.inputMode = .normal
    }

    @Test(arguments: [Tier.easy, .medium, .hard], [1, 2])
    func hintsStayInsideWhatThePlayerHasPencilledAndAgreeWithTheAnswer(tier: Tier, seed: Int) throws {
        var rng = SplitMix64(seed: UInt64(seed * 31 + tier.rawValue))
        let puzzle = try #require(KillerGenerator().generate(tier: tier, using: &rng))
        var g = GameSession(puzzle: puzzle)
        var lastAsk: HintDiagnosis?
        var recent: [String] = []
        for round in 0..<600 {
            pencil(Geometry.boxes[round % 9], in: &g)
            let d = HintEngine.diagnose(g)
            let shown = g.displayedNotes()
            recent = Array((recent + ["\(d)".prefix(90).description]).suffix(6))
            switch d {
            case .step(let s):
                lastAsk = nil
                #expect(s.placements.allSatisfy { puzzle.solution[$0.cell] == $0.digit }, "\(s.technique) places a wrong digit")
                #expect(!s.eliminations.contains { puzzle.solution[$0.cell] == $0.digit }, "\(s.technique) removes an answer")
                if !HintEngine.singles.contains(s.technique) {
                    let pattern = s.patternCells + s.patternCandidates.map(\.cell)
                    #expect(!pattern.contains { g.entries[$0] == 0 && shown[$0].isEmpty }, "\(s.technique) uses un-pencilled cells")
                }
                g.showMe(s)
            case .incomplete(let r):
                #expect(lastAsk != d, "asked for \(r) twice")
                lastAsk = d
                pencil(r.cells, in: &g)
            case .incompleteCage(let cage):
                #expect(lastAsk != d, "asked for the \(cage.sum) cage twice")
                lastAsk = d
                pencil(cage.cells, in: &g)
            case .solved:
                return
            case .mistake, .beyond:
                Issue.record("unexpected \(d)")
                return
            }
        }
        Issue.record("did not finish: \(recent.joined(separator: "\n"))")
    }

    @Test func removingTheRightMarkByHandIsPointedOutAndCanBePutBack() throws {
        var rng = SplitMix64(seed: 7)
        let puzzle = try #require(KillerGenerator().generate(tier: .hard, using: &rng))
        var g = GameSession(puzzle: puzzle)
        g.fillAllCandidates()
        let c = try #require((0..<81).first { g.entries[$0] == 0 && g.notes[$0].count > 2 })
        g.inputMode = .candidate
        g.selected = c
        g.input(puzzle.solution[c], settings: settings)       // cross out the answer
        let d = HintEngine.diagnose(g)
        #expect(d == .mistake(cell: c, kind: .marksMissAnswer))
        #expect(HintText.message(d, level: 4, answer: puzzle.solution[c]) == "\(HintText.cell(c)) can still be \(puzzle.solution[c]).")
        g.restoreAnswerMark(c)
        #expect(g.notes[c].contains(puzzle.solution[c]))
        #expect(!HintEngine.diagnose(g).isMistake)
    }
}
