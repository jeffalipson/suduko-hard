import Foundation
import Testing
import SudokuCore

@Suite struct LessonTests {
    @Test(arguments: [TechniqueID.nakedPair, .xWing, .xyWing, .cageCombination])
    func findsAnExampleWhoseStepIsReproducible(id: TechniqueID) throws {
        let lesson = try #require(LessonFinder.find(id, seeds: 1..<200))
        #expect(lesson.technique == id)
        let again = LessonFinder.technique(for: id)?.find(in: lesson.board)
        #expect(again == lesson.step)
        let back = try JSONDecoder().decode(LessonExample.self, from: JSONEncoder().encode(lesson))
        #expect(back == lesson)
    }
}

@Suite struct LessonFromPuzzlesTests {
    @Test func findsTechniqueAsNextStepInRealPuzzles() throws {
        var rng = SplitMix64(seed: 3)
        let puzzle = try #require(ClassicGenerator().generate(tier: .hard, using: &rng))
        let id = try #require(puzzle.techniquesRequired.last)
        let lesson = try #require(LessonFinder.find(id, in: [puzzle]))
        #expect(LogicalSolver.classic.nextStep(on: lesson.board)?.technique == id)
    }
}
