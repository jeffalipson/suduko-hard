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
    let lessons: [TechniqueID: LessonExample] = {
        guard let url = Bundle.main.url(forResource: "lessons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([LessonExample].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.technique, $0) }, uniquingKeysWith: { a, _ in a })
    }()
    private var rng = SystemRandomNumberGenerator()
    private var refilling = false
    /// Set by the background task's expiration handler to stop between keys.
    private var cancelRefill = false

    init() {
        let state = Persistence.load()
        settings = state.settings
        queues = state.queues
        games = state.games
        library = PuzzleLibrary.load(from: Bundle.main.resourceURL!)
        // Nothing should wait: give empty queues one library puzzle; generation fills the rest.
        queues.ensureNotEmpty(library: library, using: &rng)
        save()
        AppModel.shared = self
        // The handler runs on the main queue, matching the closure's main-actor isolation.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refillTaskID, using: .main) { task in
            MainActor.assumeIsolated { AppModel.shared?.runBackgroundRefill(task) }
        }
    }

    private func runBackgroundRefill(_ task: BGTask) {
        cancelRefill = false
        task.expirationHandler = {
            Task { @MainActor in AppModel.shared?.cancelRefill = true }
        }
        Task {
            await refillLoop()
            task.setTaskCompleted(success: !cancelRefill)
            scheduleBackgroundRefill()
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

    /// Saves an in-progress game. Finished games are never written back.
    func update(_ session: GameSession, for key: QueueKey) {
        guard !session.isComplete else { return }
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

    /// Tops queues up with freshly generated puzzles (falling back to the library), generating off
    /// the main actor. Repeats passes until every queue is full, a pass adds nothing, or the
    /// background task expires.
    func refillLoop() async {
        guard !refilling else { return }
        refilling = true
        defer { refilling = false }
        var progressed = true
        while progressed && !cancelRefill {
            progressed = false
            for key in QueueKey.all where queues.deficit(key) > 0 && !cancelRefill {
                let before = queues.count(key)
                if let generated = await Task.detached(priority: .background, operation: { AppModel.generate(key, seconds: 60) }).value {
                    queues.push(generated, for: key, using: &rng)
                } else {
                    queues.refillFromLibrary(key, library: library, using: &rng)
                }
                if queues.count(key) > before {
                    progressed = true
                    save()
                }
            }
        }
    }

    nonisolated static func generate(_ key: QueueKey, seconds: Double) -> Puzzle? {
        var rng = SystemRandomNumberGenerator()
        let deadline = ContinuousClock.now + .seconds(seconds)
        switch key.mode {
        case .classic: return ClassicGenerator().generate(tier: key.tier, using: &rng, deadline: deadline)
        case .killer: return KillerGenerator().generate(tier: key.tier, using: &rng, deadline: deadline)
        }
    }

    /// For a tier with nothing queued and nothing in the library: generate one now and start it.
    func generateAndStart(_ key: QueueKey) async -> Bool {
        guard let puzzle = await Task.detached(priority: .userInitiated, operation: { AppModel.generate(key, seconds: 900) }).value else {
            return false
        }
        queues.push(puzzle, for: key, using: &rng)
        return startNew(key) != nil
    }
}
