import Testing
import SudokuCore
import SudokuGame

@Suite struct LessonTextTests {
    @Test func everyTechniqueHasAnExplanation() {
        for id in TechniqueID.allCases {
            #expect(LessonText.explanation(for: id).count > 60, "\(id)")
        }
    }
}
