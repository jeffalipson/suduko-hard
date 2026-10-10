import Testing
import SudokuCore

@Suite struct CageTechniqueTests {
    func board(_ cages: [Cage], placing placed: [Int: Int] = [:]) -> Board {
        var v = Array(repeating: 0, count: 81)
        for (c, d) in placed { v[c] = d }
        return Board(values: v, cages: cages)
    }

    @Test func cageCompletion() throws {
        let b = board([Cage(cells: [0, 1], sum: 8)], placing: [0: 5])
        let step = try #require(CageCompletion().find(in: b))
        #expect(step.technique == .cageCompletion)
        #expect(step.placements == [CellDigit(cell: 1, digit: 3)])
    }

    @Test func uniqueCageCombination() throws {
        let b = board([Cage(cells: [0, 1], sum: 3)])
        let step = try #require(UniqueCageCombination().find(in: b))
        #expect(step.technique == .uniqueCageCombination)
        #expect(Set(step.eliminations) == Set([0, 1].flatMap { c in (3...9).map { CellDigit(cell: c, digit: $0) } }))
    }

    @Test func cageCombinationUsesCandidates() throws {
        var b = board([Cage(cells: [0, 9], sum: 10)])
        b.candidates[0] = CandidateSet([1, 2])
        #expect(UniqueCageCombination().find(in: b) == nil)
        let step = try #require(CageCombination().find(in: b))
        #expect(step.technique == .cageCombination)
        #expect(Set(step.eliminations) == Set((1...7).map { CellDigit(cell: 9, digit: $0) }))
    }

    @Test func cageLockedDigit() throws {
        let b = board([Cage(cells: [0, 1], sum: 3)])
        let step = try #require(CageLockedDigit().find(in: b))
        #expect(step.technique == .cageLockedDigit)
        #expect(step.digits == [1])
        #expect(step.eliminations.count == 13)   // rest of row 0 (7) + rest of box 0 (6)
        #expect(step.eliminations.allSatisfy { $0.digit == 1 })
    }

    @Test func classicBoardsHaveNoCageSteps() {
        for t in [CageCompletion(), UniqueCageCombination(), CageCombination(), CageLockedDigit()] as [any Technique] {
            #expect(t.find(in: emptyBoard()) == nil)
        }
    }

    @Test func killerOnlyIDs() {
        #expect(TechniqueID.innieOutie2.isKillerOnly)
        #expect(!TechniqueID.xWing.isKillerOnly)
        #expect(TechniqueID.cageCombination.tier == .medium)
        #expect(TechniqueID.innieOutieMulti.tier == .fiendish)
    }

    @Test func sound() {
        for t in [CageCompletion(), UniqueCageCombination(), CageCombination(), CageLockedDigit()] as [any Technique] {
            #expect(killerSoundnessViolations(of: t, seeds: 1...25).isEmpty, "\(t.id)")
        }
    }
}
