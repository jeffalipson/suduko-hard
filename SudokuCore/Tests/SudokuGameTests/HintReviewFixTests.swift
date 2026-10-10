import Foundation
import Testing
import SudokuCore
import SudokuGame

@Suite struct HintReviewFixTests {
    /// A player who only pencils in the region the hint names must never be sent back to the same region.
    @Test(arguments: 1...6)
    func incompleteRegionsAreSatisfiable(seed: Int) throws {
        var rng = SplitMix64(seed: UInt64(seed))
        let puzzle = try #require(ClassicGenerator().generate(tier: .hard, using: &rng))
        var g = GameSession(puzzle: puzzle)
        var last: Region?
        for _ in 0..<200 {
            switch HintEngine.diagnose(g) {
            case .incomplete(let region):
                #expect(region != last, "asked for \(region) twice")
                last = region
                let board = HintEngine.playerBoard(g)
                g.inputMode = .candidate
                for c in region.cells where g.entries[c] == 0 && g.notes[c].isEmpty {
                    g.selected = c
                    for d in board.candidates[c].digits { g.input(d, settings: GameSettings()) }
                }
            case .step(let step):
                last = nil
                g.showMe(step)
            case .solved:
                return
            case .mistake, .beyond:
                Issue.record("unexpected diagnosis")
                return
            }
        }
        Issue.record("did not finish")
    }

    @Test func killerStaleCageMateNotesAreIgnored() {
        let cages = [Cage(cells: [0, 40], sum: wikiAnswer[0] + wikiAnswer[40])]
        let puzzle = Puzzle(id: "k", mode: .killer, givens: wikiGivens, cages: cages, solution: wikiAnswer,
                            grade: Grade(tier: .easy, score: 1), techniquesRequired: [])
        var g = GameSession(puzzle: puzzle)
        g.selected = 40
        g.inputMode = .candidate
        g.input(wikiAnswer[40], settings: GameSettings())
        g.input(5, settings: GameSettings())   // 5 is given in cell 0, its cage mate: stale
        #expect(!HintEngine.playerBoard(g).candidates[40].contains(5))
    }

    @Test func bundledLessonsReproduceTheirSteps() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Lessons/lessons.json")
        let lessons = try JSONDecoder().decode([LessonExample].self, from: Data(contentsOf: url))
        #expect(Set(lessons.map(\.technique)) == Set(TechniqueID.allCases))
        for lesson in lessons {
            #expect(LessonFinder.technique(for: lesson.technique)?.find(in: lesson.board) == lesson.step, "\(lesson.technique)")
        }
    }

    @Test func lessonsPreferStatesWhereTheTechniqueIsNext() throws {
        let lesson = try #require(LessonFinder.find(.xWing, seeds: 1..<300))
        let solver = LogicalSolver.classic
        #expect(solver.nextStep(on: lesson.board)?.technique == .xWing)
    }

    @Test func nudgeUsesAnBeforeXAndVowels() {
        #expect(HintText.nudge(Step(technique: .xWing, regions: [.row(0)], digits: [7])).hasPrefix("Look for an X-Wing"))
        #expect(HintText.nudge(Step(technique: .nakedPair, regions: [.row(0)])).hasPrefix("Look for a Naked Pair"))
    }
}
