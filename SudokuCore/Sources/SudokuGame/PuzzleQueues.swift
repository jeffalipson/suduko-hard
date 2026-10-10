import SudokuCore

/// Ready-to-play puzzles per mode × tier, kept topped up to `target`.
public struct PuzzleQueues: Codable, Equatable, Sendable {
    public static let target = 3

    var ready: [String: [Puzzle]] = [:]
    /// Shuffled library indices per key and how far into them we are.
    var order: [String: [Int]] = [:]
    var cursor: [String: Int] = [:]

    public init() {}

    public func count(_ key: QueueKey) -> Int { ready[key.name, default: []].count }
    public func deficit(_ key: QueueKey) -> Int { max(0, Self.target - count(key)) }

    public mutating func pop(_ key: QueueKey) -> Puzzle? {
        guard !ready[key.name, default: []].isEmpty else { return nil }
        return ready[key.name]!.removeFirst()
    }

    /// Adds a puzzle after giving it a fresh random look.
    public mutating func push<R: RandomNumberGenerator>(_ puzzle: Puzzle, for key: QueueKey, using rng: inout R) {
        let transformed = GridTransform.random(for: puzzle, using: &rng).apply(to: puzzle)
        ready[key.name, default: []].append(transformed)
    }

    /// Tops `key` up from the library in this install's shuffled order, reshuffling when exhausted.
    public mutating func refillFromLibrary<R: RandomNumberGenerator>(_ key: QueueKey, library: PuzzleLibrary, using rng: inout R) {
        refillFromLibrary(key, library: library, upTo: Self.target, using: &rng)
    }

    /// Launch top-up: give every empty queue one library puzzle so nothing waits,
    /// leaving the rest of each queue for freshly generated puzzles.
    public mutating func ensureNotEmpty<R: RandomNumberGenerator>(library: PuzzleLibrary, using rng: inout R) {
        for key in QueueKey.all where count(key) == 0 { refillFromLibrary(key, library: library, upTo: 1, using: &rng) }
    }

    mutating func refillFromLibrary<R: RandomNumberGenerator>(_ key: QueueKey, library: PuzzleLibrary, upTo limit: Int, using rng: inout R) {
        let pool = library.puzzles[key] ?? []
        guard !pool.isEmpty else { return }
        while count(key) < limit {
            var indices = order[key.name] ?? []
            var at = cursor[key.name] ?? 0
            if indices.count != pool.count || at >= indices.count {
                let last = at > 0 && at <= indices.count ? indices[at - 1] : nil
                indices = Array(pool.indices).shuffled(using: &rng)
                at = 0
                // Never deal the same puzzle twice in a row across a reshuffle.
                if indices.count > 1, indices[0] == last { indices.swapAt(0, 1) }
            }
            push(pool[indices[at]], for: key, using: &rng)
            order[key.name] = indices
            cursor[key.name] = at + 1
        }
    }

    public mutating func fillAllFromLibrary<R: RandomNumberGenerator>(_ library: PuzzleLibrary, using rng: inout R) {
        for key in QueueKey.all { refillFromLibrary(key, library: library, using: &rng) }
    }
}
