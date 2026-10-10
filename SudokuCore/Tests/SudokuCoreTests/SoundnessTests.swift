import Testing
import SudokuCore

@Suite struct SoundnessTests {
    @Test func everyCatalogTechniqueIsSound() {
        for technique in TechniqueCatalog.classic {
            #expect(soundnessViolations(of: technique, seeds: 1...20).isEmpty, "\(technique.id)")
        }
    }

    @Test func newTechniqueIDsHaveExpectedTiers() {
        #expect(TechniqueID.xWing.tier == .expert)
        #expect(TechniqueID.uniqueRectangle1.tier == .expert)
        #expect(TechniqueID.jellyfish.tier == .fiendish)
        #expect(TechniqueID.uniqueRectangle3.tier == .fiendish)
        #expect(TechniqueID.finnedSwordfish.displayName == "Finned Swordfish")
    }
}
