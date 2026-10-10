import Foundation
import SudokuCore

public struct QueueKey: Hashable, Codable, Sendable {
    public let mode: Mode
    public let tier: Tier

    public init(mode: Mode, tier: Tier) {
        self.mode = mode
        self.tier = tier
    }

    /// File and dictionary name, e.g. "killer-nightmare".
    public var name: String { "\(mode.rawValue)-\(tier.name)" }

    public static let all: [QueueKey] = Mode.allCases.flatMap { m in Tier.allCases.map { QueueKey(mode: m, tier: $0) } }
}

/// The bundled, pre-generated puzzles.
public struct PuzzleLibrary: Sendable {
    public let puzzles: [QueueKey: [Puzzle]]

    public init(puzzles: [QueueKey: [Puzzle]]) {
        self.puzzles = puzzles
    }

    /// Reads `<key.name>.json` for every key in `directory`; missing or unreadable files count as empty.
    public static func load(from directory: URL) -> PuzzleLibrary {
        var out: [QueueKey: [Puzzle]] = [:]
        for key in QueueKey.all {
            let url = directory.appendingPathComponent("\(key.name).json")
            if let data = try? Data(contentsOf: url), let list = try? JSONDecoder().decode([Puzzle].self, from: data) {
                out[key] = list
            }
        }
        return PuzzleLibrary(puzzles: out)
    }
}
