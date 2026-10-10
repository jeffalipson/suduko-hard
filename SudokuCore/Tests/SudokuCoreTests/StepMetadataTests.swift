import Foundation
import Testing
import SudokuCore

@Suite struct StepMetadataTests {
    @Test func stepsRoundTripAsJSON() throws {
        let step = Step(technique: .xWing, patternCells: [1], eliminations: [CellDigit(cell: 2, digit: 3)],
                        regions: [.row(0)], digits: [3], groups: [[CellDigit(cell: 1, digit: 3)]])
        #expect(try JSONDecoder().decode(Step.self, from: JSONEncoder().encode(step)) == step)
    }

    @Test func coloringReportsBothColours() throws {
        let b = board(digit: 1, onlyIn: [rc(0, 0), rc(1, 2), rc(5, 2), rc(5, 6), rc(0, 6), rc(0, 3), rc(8, 6)])
        let step = try #require(SimpleColoring().find(in: b))
        #expect(step.groups.count == 2)
        #expect(Set(step.groups[0].map(\.cell)) == [rc(0, 0), rc(5, 2)])
    }

    @Test func finnedFishMarksFins() throws {
        let b = board(digit: 2, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(4, 7), rc(3, 6)])
        let step = try #require(FinnedFish(size: 2).find(in: b))
        #expect(step.groups == [[CellDigit(cell: rc(4, 7), digit: 2)]])
    }

    @Test func uniqueRectangleTypesNameTheirExtras() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([1, 2])
        b.candidates[rc(1, 0)] = CandidateSet([1, 2])
        b.candidates[rc(0, 3)] = CandidateSet([1, 2, 3])
        b.candidates[rc(1, 3)] = CandidateSet([1, 2, 4])
        b.candidates[rc(5, 3)] = CandidateSet([3, 4])
        let t3 = try #require(UniqueRectangle(type: 3).find(in: b))
        #expect(t3.groups == [[CellDigit(cell: rc(5, 3), digit: 3), CellDigit(cell: rc(5, 3), digit: 4)]])
        #expect(t3.regions.contains(.column(3)))
    }
}
