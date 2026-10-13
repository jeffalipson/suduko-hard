import BackgroundTasks
import Foundation
import Observation
import SudokuCore
import SwiftData
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
    let container: ModelContainer = AppModel.makeContainer()

    /// UI tests run with `-uitest`: an in-memory stats store and a scratch state file.
    nonisolated static var isUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        false
        #endif
    }

    /// The stats store. A store that won't open (corrupt, or a failed migration) is deleted and
    /// recreated rather than crashing the app; as a last resort stats live in memory.
    static func makeContainer() -> ModelContainer {
        if isUITest, let memory = try? ModelContainer(for: GameRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)) {
            return memory
        }
        if let container = try? ModelContainer(for: GameRecord.self) { return container }
        let store = ModelConfiguration().url
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: store.path + suffix))
        }
        if let container = try? ModelContainer(for: GameRecord.self) { return container }
        return try! ModelContainer(for: GameRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
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
        // Killer puzzles reshuffled by an older version could have cages split into pieces.
        let broken: (Puzzle) -> Bool = { $0.cages.contains { !$0.isConnected } }
        queues.purge(where: broken)
        games = games.filter { !broken($0.value.puzzle) }
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
        // Replacing an unfinished game abandons it.
        if let old = games[key.name], !old.isComplete { record(old, won: false) }
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
        record(session, won: true)
        games[key.name] = nil
        save()
    }

    /// Stores a finished or abandoned game for stats.
    private func record(_ session: GameSession, won: Bool) {
        container.mainContext.insert(GameRecord(GameRecordData(session: session, won: won, endDate: .now)))
        try? container.mainContext.save()
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
                // Tiers too slow to generate on a phone come only from the bundled library.
                let budget = AppModel.onDeviceBudget(key)
                if let budget, let generated = await Task.detached(priority: .background, operation: { AppModel.generate(key, seconds: budget) }).value {
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

    /// Seconds to spend generating one puzzle on the device, or nil for tiers that take minutes
    /// even on a Mac (Killer Diabolical/Nightmare) and so come only from the library.
    nonisolated static func onDeviceBudget(_ key: QueueKey) -> Double? {
        key.mode == .killer && key.tier >= .diabolical ? nil : 60
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
        guard AppModel.onDeviceBudget(key) != nil else { return false }
        guard let puzzle = await Task.detached(priority: .userInitiated, operation: { AppModel.generate(key, seconds: 900) }).value else {
            return false
        }
        queues.push(puzzle, for: key, using: &rng)
        // Cancelled while generating: keep the puzzle queued, but don't replace (and abandon) the current game.
        guard !Task.isCancelled else { return false }
        return startNew(key) != nil
    }
}
