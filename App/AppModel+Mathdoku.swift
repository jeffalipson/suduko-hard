import Foundation
import SudokuCore
import SudokuGame

extension AppModel {
    /// How many ready Mathdoku puzzles to keep per tier.
    static let mathQueueTarget = 2

    static func loadMathLibrary() -> [Tier: [MathdokuPuzzle]] {
        var out: [Tier: [MathdokuPuzzle]] = [:]
        for tier in Tier.allCases {
            guard let url = Bundle.main.url(forResource: "mathdoku-\(tier.name)", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let list = try? JSONDecoder().decode([MathdokuPuzzle].self, from: data) else { continue }
            out[tier] = list
        }
        return out
    }

    func resumableMath(_ tier: Tier) -> MathdokuSession? { mathGames[tier.name] }

    /// Starts a fresh Mathdoku, abandoning any unfinished one for this tier. Takes a queued puzzle,
    /// or a library one in a random orientation.
    func startNewMath(_ tier: Tier) -> MathdokuSession? {
        var queue = mathQueues[tier.name] ?? []
        let puzzle = queue.isEmpty
            ? mathLibrary[tier]?.randomElement().map { $0.transformed(Int.random(in: 0..<8)) }
            : queue.removeFirst()
        mathQueues[tier.name] = queue
        guard let puzzle else { return nil }
        if let old = mathGames[tier.name], !old.isComplete { recordMath(old, won: false) }
        let session = MathdokuSession(puzzle: puzzle)
        mathGames[tier.name] = session
        save()
        Task { await refillMath() }
        return session
    }

    func updateMath(_ session: MathdokuSession, for tier: Tier) {
        guard !session.isComplete else { return }
        mathGames[tier.name] = session
        save()
    }

    func finishMath(_ session: MathdokuSession, for tier: Tier) {
        recordMath(session, won: true)
        mathGames[tier.name] = nil
        save()
    }

    private func recordMath(_ session: MathdokuSession, won: Bool) {
        container.mainContext.insert(GameRecord(mathdoku: session, won: won, endDate: .now))
        try? container.mainContext.save()
    }

    /// Tops each tier's queue up with puzzles generated on the device (a few seconds each, off the main actor).
    func refillMath() async {
        guard !mathRefilling, !AppModel.isUITest else { return }
        mathRefilling = true
        defer { mathRefilling = false }
        for tier in Tier.allCases {
            while (mathQueues[tier.name]?.count ?? 0) < Self.mathQueueTarget {
                let puzzle = await Task.detached(priority: .background) { () -> MathdokuPuzzle? in
                    var rng = SystemRandomNumberGenerator()
                    return MathdokuGenerator().generate(tier: tier, using: &rng, deadline: .now + .seconds(60))
                }.value
                guard let puzzle else { break }
                mathQueues[tier.name, default: []].append(puzzle)
                save()
            }
        }
    }
}
