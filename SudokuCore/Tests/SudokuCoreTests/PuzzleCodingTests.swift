import Foundation
import Testing
import SudokuCore

@Suite struct PuzzleCodingTests {
    let puzzle = Puzzle(
        id: "abc",
        mode: .classic,
        givens: values(wikiPuzzle),
        cages: [],
        solution: values(wikiSolution),
        grade: Grade(tier: .easy, score: 120),
        techniquesRequired: [.nakedSingle, .hiddenSingle]
    )

    @Test func roundTrips() throws {
        let data = try JSONEncoder().encode(puzzle)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"givens\":\"\(wikiPuzzle)\""))
        #expect(!json.contains("cages"))
        #expect(try JSONDecoder().decode(Puzzle.self, from: data) == puzzle)
    }

    @Test func roundTripsCages() throws {
        var killer = puzzle
        killer.mode = .killer
        killer.cages = [Cage(cells: [0, 1], sum: 8)]
        let data = try JSONEncoder().encode(killer)
        #expect(try JSONDecoder().decode(Puzzle.self, from: data) == killer)
    }

    @Test func corruptGivensThrow() {
        let json = """
        {"id":"x","mode":"classic","givens":"123","solution":"\(wikiSolution)",
         "grade":{"tier":0,"score":1},"techniquesRequired":[]}
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Puzzle.self, from: Data(json.utf8))
        }
    }
}
