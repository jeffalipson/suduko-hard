import SwiftUI
import SudokuCore
import SudokuGame

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var mode: Mode = .classic
    @State private var playing: QueueKey?
    @State private var showSettings = false
    @State private var showStats = false
    @State private var debugLesson: TechniqueID?
    @State private var confirmNew: QueueKey?
    @State private var generating: QueueKey?
    @State private var generationTask: Task<Void, Never>?
    @State private var generationFailed = false

    var body: some View {
        NavigationStack {
            List {
                Picker("Mode", selection: $mode) {
                    Text("Classic").tag(Mode.classic)
                    Text("Killer").tag(Mode.killer)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("modePicker")

                ForEach(Tier.allCases, id: \.self) { tier in
                    let key = QueueKey(mode: mode, tier: tier)
                    Button { open(key) } label: { row(key) }
                        .tint(.primary)
                        .accessibilityIdentifier("tier-\(tier.name)")
                        .contextMenu {
                            if model.resumable(key) != nil {
                                Button("New Game", systemImage: "arrow.counterclockwise") { confirmNew = key }
                            }
                        }
                }
            }
            .navigationTitle("Hard Sudoku")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                        .accessibilityIdentifier("settingsButton")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stats", systemImage: "chart.bar") { showStats = true }
                        .accessibilityIdentifier("statsButton")
                }
            }
            .confirmationDialog("Start a new game?", isPresented: Binding(get: { confirmNew != nil }, set: { if !$0 { confirmNew = nil } }),
                                titleVisibility: .visible, presenting: confirmNew) { key in
                Button("New Game", role: .destructive) { startNew(key) }
            } message: { _ in
                Text("Your game in progress will count as abandoned in your stats.")
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(item: $debugLesson) { id in
                LessonView(technique: id, example: model.lessons[id]) {}
            }
            .navigationDestination(item: $playing) { key in GameView(key: key) }
            .onAppear(perform: openFromLaunchArguments)
            .alert("Couldn't make a puzzle in time", isPresented: $generationFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Background generation keeps trying. Check back in a few minutes.")
            }
            .overlay {
                if let key = generating {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()   // blocks taps on other rows
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Generating a \(key.mode.rawValue) \(key.tier.name) puzzle…").font(.subheadline)
                            Text("Hard tiers can take a minute or two.").font(.caption).foregroundStyle(.secondary)
                            Button("Cancel") { generationTask?.cancel(); generating = nil }
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private func row(_ key: QueueKey) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(key.tier.name.capitalized).font(.headline).foregroundStyle(.primary)
                if let game = model.resumable(key) {
                    Text("Resume · \(GameView.clock(game.elapsed))").font(.subheadline).foregroundStyle(Theme.accent)
                } else {
                    Text("New game").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    /// `-open killer-hard` jumps straight into a game (used for screenshots and UI tests).
    private func openFromLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-stats") { showStats = true }
        if let i = args.firstIndex(of: "-lesson"), i + 1 < args.count { debugLesson = TechniqueID(rawValue: args[i + 1]) }
        guard let i = args.firstIndex(of: "-open"), i + 1 < args.count,
              let key = QueueKey.all.first(where: { $0.name == args[i + 1] }) else { return }
        mode = key.mode
        if args.contains("-new") { startNew(key) } else { open(key) }
    }

    private func open(_ key: QueueKey) {
        if model.resumable(key) == nil, model.startNew(key) == nil {
            generate(key)
            return
        }
        playing = key
    }

    private func generate(_ key: QueueKey) {
        guard generating == nil else { return }
        generating = key
        generationTask = Task {
            let ok = await model.generateAndStart(key)
            guard !Task.isCancelled else { return }
            generating = nil
            if ok { playing = key } else { generationFailed = true }
        }
    }

    private func startNew(_ key: QueueKey) {
        guard model.startNew(key) != nil else { generate(key); return }
        playing = key
    }
}
