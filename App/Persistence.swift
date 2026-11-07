import Foundation
import SudokuCore
import SudokuGame

/// Everything the app keeps between launches, saved as one JSON file.
struct SavedState: Codable {
    var version = 1
    var settings = GameSettings()
    var queues = PuzzleQueues()
    var games: [String: GameSession] = [:]
    /// Mathdoku games in progress and ready puzzles, keyed by tier name.
    var mathGames: [String: MathdokuSession] = [:]
    var mathQueues: [String: [MathdokuPuzzle]] = [:]

    init(settings: GameSettings = GameSettings(), queues: PuzzleQueues = PuzzleQueues(), games: [String: GameSession] = [:],
         mathGames: [String: MathdokuSession] = [:], mathQueues: [String: [MathdokuPuzzle]] = [:]) {
        self.settings = settings
        self.queues = queues
        self.games = games
        self.mathGames = mathGames
        self.mathQueues = mathQueues
    }

    private enum CodingKeys: String, CodingKey { case version, settings, queues, games, mathGames, mathQueues }

    /// Each section decodes on its own (and each game separately), so one bad part never loses the rest.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        settings = (try? c.decode(GameSettings.self, forKey: .settings)) ?? GameSettings()
        queues = (try? c.decode(PuzzleQueues.self, forKey: .queues)) ?? PuzzleQueues()
        let raw = (try? c.decode([String: Lenient<GameSession>].self, forKey: .games)) ?? [:]
        games = raw.compactMapValues(\.value)
        let math = (try? c.decode([String: Lenient<MathdokuSession>].self, forKey: .mathGames)) ?? [:]
        mathGames = math.compactMapValues(\.value)
        mathQueues = (try? c.decode([String: [MathdokuPuzzle]].self, forKey: .mathQueues)) ?? [:]
    }
}

/// Decodes to nil instead of failing.
struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: any Decoder) throws { value = try? T(from: decoder) }
}

enum Persistence {
    static var url: URL {
        let dir = AppModel.isUITest
            ? FileManager.default.temporaryDirectory.appendingPathComponent("HardSudokuUITest")
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    static func load() -> SavedState {
        guard let data = try? Data(contentsOf: url) else { return SavedState() }
        if let state = try? JSONDecoder().decode(SavedState.self, from: data) { return state }
        // Not even a JSON object: keep a copy for diagnosis instead of overwriting it.
        let aside = url.deletingLastPathComponent().appendingPathComponent("state.corrupt.json")
        try? FileManager.default.removeItem(at: aside)
        try? FileManager.default.moveItem(at: url, to: aside)
        return SavedState()
    }

    static func save(_ state: SavedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
