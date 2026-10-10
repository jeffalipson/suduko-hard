import BackgroundTasks
import Foundation
import Observation
import SudokuCore
import SudokuGame

@Observable @MainActor
final class AppModel {
    nonisolated static let refillTaskID = "com.jeffreylipson.hardsudoku.refill"
    /// The live model, for the background-task handler.
    static weak var shared: AppModel?

    var settings: GameSettings { didSet { save() } }
    private(set) var queues: PuzzleQueues
    private(set) var games: [String: GameSession]
    let library: PuzzleLibrary
    private var rng = SystemRandomNumberGenerator()
    private var refilling = false

    init() {
        let state = Persistence.load()
        settings = state.settings
        queues = state.queues
        games = state.games
        library = PuzzleLibrary.load(from: Bundle.main.resourceURL!)
        // Nothing should ever wait: top every queue up from the library right away.
        queues.fillAllFromLibrary(library, using: &rng)
        save()
        AppModel.shared = self
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refillTaskID, using: nil) { task in
            Task { @MainActor in
                await AppModel.shared?.refillLoop()
                task.setTaskCompleted(success: true)
            }
        }
    }

    /// Asks iOS for generation time while the phone charges (overnight top-ups).
    func scheduleBackgroundRefill() {
        let request = BGProcessingTaskRequest(identifier: Self.refillTaskID)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(request)
    }

    func resumable(_ key: QueueKey) -> GameSession? { games[key.name] }

    /// Starts a fresh game, abandoning any unfinished one for this key.
    func startNew(_ key: QueueKey) -> GameSession? {
        if queues.count(key) == 0 { queues.refillFromLibrary(key, library: library, using: &rng) }
        guard let puzzle = queues.pop(key) else { return nil }
        let session = GameSession(puzzle: puzzle)
        games[key.name] = session
        save()
        Task { await refillLoop() }
        return session
    }

    func update(_ session: GameSession, for key: QueueKey) {
        games[key.name] = session
        save()
    }

    func finish(_ session: GameSession, for key: QueueKey) {
        games[key.name] = nil
        save()
    }

    func save() {
        Persistence.save(SavedState(settings: settings, queues: queues, games: games))
    }

    /// Tops queues up with freshly generated puzzles (falling back to the library) off the main actor.
    func refillLoop() async {
        guard !refilling else { return }
        refilling = true
        defer { refilling = false }
        for key in QueueKey.all where queues.deficit(key) > 0 {
            let generated = await Task.detached(priority: .background) { () -> Puzzle? in
                var rng = SystemRandomNumberGenerator()
                let deadline = ContinuousClock.now + .seconds(60)
                switch key.mode {
                case .classic: return ClassicGenerator().generate(tier: key.tier, using: &rng, deadline: deadline)
                case .killer: return KillerGenerator().generate(tier: key.tier, using: &rng, deadline: deadline)
                }
            }.value
            if let generated {
                queues.push(generated, for: key, using: &rng)
            } else {
                queues.refillFromLibrary(key, library: library, using: &rng)
            }
            save()
        }
    }
}
