import Foundation
import Testing
import SudokuCore
import SudokuGame

@Suite struct PolishGameTests {
    @Test func reshuffleNeverRepeatsBackToBack() {
        let key = QueueKey(mode: .classic, tier: .easy)
        let lib = PuzzleLibrary(puzzles: [key: (1...3).map { libraryPuzzle("p\($0)") }])
        for seed in 1...40 {
            var q = PuzzleQueues()
            var rng = SplitMix64(seed: UInt64(seed))
            var ids: [String] = []
            for _ in 0..<4 {
                q.refillFromLibrary(key, library: lib, using: &rng)
                while let p = q.pop(key) { ids.append(p.id) }
            }
            for (a, b) in zip(ids, ids.dropFirst()) { #expect(a != b, "seed \(seed): \(ids)") }
        }
    }

    @Test func sessionsRecordTheirStartTime() {
        let before = Date()
        let g = GameSession(puzzle: classicPuzzle())
        #expect(g.startedAt.map { $0 >= before } == true)
        let r = GameRecordData(session: g, won: false, endDate: before.addingTimeInterval(500))
        #expect(r.startDate == g.startedAt)
    }

    @Test func oldSavesWithoutStartTimeStillDecode() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GameSession(puzzle: classicPuzzle()))) as! [String: Any]
        json["startedAt"] = nil
        let g = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(g.startedAt == nil)
    }
}
