import Foundation
import SudokuGame

/// Everything the app keeps between launches, saved as one JSON file.
struct SavedState: Codable {
    var settings = GameSettings()
    var queues = PuzzleQueues()
    var games: [String: GameSession] = [:]
}

enum Persistence {
    static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    static func load() -> SavedState {
        guard let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(SavedState.self, from: data) else {
            return SavedState()
        }
        return state
    }

    static func save(_ state: SavedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
