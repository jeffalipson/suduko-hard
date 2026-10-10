import Foundation
import Testing
import SudokuCore
import SudokuGame

func libraryPuzzle(_ id: String, mode: Mode = .classic) -> Puzzle {
    Puzzle(id: id, mode: mode, givens: wikiGivens, cages: mode == .killer ? killerPuzzle().cages : [],
           solution: wikiAnswer, grade: Grade(tier: .easy, score: 1), techniquesRequired: [])
}

@Suite struct QueueTests {
    let key = QueueKey(mode: .classic, tier: .easy)

    @Test func fourteenKeys() {
        #expect(QueueKey.all.count == 14)
        #expect(key.name == "classic-easy")
    }

    @Test func refillsToThreeWithoutRepeatsThenReshuffles() {
        let lib = PuzzleLibrary(puzzles: [key: (1...4).map { libraryPuzzle("p\($0)") }])
        var q = PuzzleQueues()
        var rng = SplitMix64(seed: 1)
        q.refillFromLibrary(key, library: lib, using: &rng)
        #expect(q.count(key) == 3)
        var seen: [String] = []
        for _ in 0..<3 { seen.append(q.pop(key)!.id) }
        q.refillFromLibrary(key, library: lib, using: &rng)
        seen.append(q.pop(key)!.id)
        #expect(Set(seen).count == 4)   // all four before any repeat
        #expect(q.count(key) == 2)      // reshuffled library keeps supplying
    }

    @Test func queuedPuzzlesAreTransformedButStillValid() {
        let lib = PuzzleLibrary(puzzles: [key: [libraryPuzzle("a")]])
        var q = PuzzleQueues()
        var rng = SplitMix64(seed: 2)
        q.refillFromLibrary(key, library: lib, using: &rng)
        let p = q.pop(key)!
        #expect(p.id == "a")
        #expect(BruteForceSolver.solve(p.givens) == p.solution)
    }

    @Test func killerTransformsKeepCageSums() {
        let k = QueueKey(mode: .killer, tier: .easy)
        var q = PuzzleQueues()
        var rng = SplitMix64(seed: 3)
        q.push(libraryPuzzle("k", mode: .killer), for: k, using: &rng)
        let p = q.pop(k)!
        for cage in p.cages { #expect(cage.cells.map { p.solution[$0] }.reduce(0, +) == cage.sum) }
    }

    @Test func emptyLibraryLeavesQueueEmpty() {
        var q = PuzzleQueues()
        var rng = SplitMix64(seed: 4)
        q.refillFromLibrary(key, library: PuzzleLibrary(puzzles: [:]), using: &rng)
        #expect(q.pop(key) == nil)
        #expect(q.deficit(key) == 3)
    }

    @Test func loadsFilesAndRoundTripsState() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode([libraryPuzzle("x")]).write(to: dir.appendingPathComponent("classic-easy.json"))
        let lib = PuzzleLibrary.load(from: dir)
        #expect(lib.puzzles[key]?.map(\.id) == ["x"])
        var q = PuzzleQueues()
        var rng = SplitMix64(seed: 5)
        q.fillAllFromLibrary(lib, using: &rng)
        let back = try JSONDecoder().decode(PuzzleQueues.self, from: JSONEncoder().encode(q))
        #expect(back == q)
    }
}
