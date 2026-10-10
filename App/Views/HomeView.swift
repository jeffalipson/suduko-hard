import SwiftUI
import SudokuCore
import SudokuGame

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var mode: Mode = .classic
    @State private var playing: QueueKey?
    @State private var showSettings = false
    @State private var generating: QueueKey?

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
                                Button("New Game", systemImage: "arrow.counterclockwise") { startNew(key) }
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
                    Button("Stats", systemImage: "chart.bar") {}
                        .disabled(true)   // Plan 7
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(item: $playing) { key in GameView(key: key) }
            .onAppear(perform: openFromLaunchArguments)
            .overlay {
                if let key = generating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Generating a \(key.mode.rawValue) \(key.tier.name) puzzle…").font(.subheadline)
                        Text("Hard tiers can take a minute or two.").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        guard let i = args.firstIndex(of: "-open"), i + 1 < args.count,
              let key = QueueKey.all.first(where: { $0.name == args[i + 1] }) else { return }
        mode = key.mode
        open(key)
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
        Task {
            let ok = await model.generateAndStart(key)
            generating = nil
            if ok { playing = key }
        }
    }

    private func startNew(_ key: QueueKey) {
        guard model.startNew(key) != nil else { generate(key); return }
        playing = key
    }
}
