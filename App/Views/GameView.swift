import SwiftUI
import SudokuCore
import SudokuGame

struct GameView: View {
    let key: QueueKey
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var session: GameSession?
    @State private var showCageHelper = false
    @State private var showCompletion = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let binding = Binding($session) {
                content(binding)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            // Opening a game (new or resumed) starts the clock; pausing only applies while away.
            guard var s = model.resumable(key) else { return }
            s.setPaused(false)
            session = s
        }
        .onReceive(timer) { _ in
            // Only advances the clock; the game is saved on moves and when the app leaves the foreground.
            guard phase == .active, var s = session, !s.isComplete else { return }
            s.tick(1)
            session = s
        }
        .onChange(of: phase) { _, new in
            if new != .active, var s = session, !s.isComplete { s.setPaused(true); session = s; model.update(s, for: key) }
        }
    }

    @ViewBuilder
    private func content(_ s: Binding<GameSession>) -> some View {
        VStack(spacing: 16) {
            ZStack {
                BoardView(session: s.wrappedValue, settings: model.settings) { cell in
                    s.wrappedValue.selected = cell
                }
                .opacity(s.wrappedValue.isPaused ? 0 : 1)
                if s.wrappedValue.isPaused {
                    Button {
                        s.wrappedValue.setPaused(false)
                        model.update(s.wrappedValue, for: key)
                    } label: {
                        Label("Resume", systemImage: "play.fill").font(.title2)
                    }
                    .accessibilityIdentifier("resumeButton")
                }
            }
            .padding(.horizontal, 8)
            ControlsView(session: s, settings: model.settings, onChange: { changed(s.wrappedValue) }, showCageHelper: $showCageHelper)
                .padding(.horizontal, 12)
                .disabled(s.wrappedValue.isPaused)
            Spacer(minLength: 0)
        }
        .navigationTitle("\(key.mode.rawValue.capitalized) · \(key.tier.name.capitalized)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(Self.clock(s.wrappedValue.elapsed)).monospacedDigit().font(.headline).accessibilityIdentifier("clock")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(s.wrappedValue.isPaused ? "Resume" : "Pause", systemImage: s.wrappedValue.isPaused ? "play.fill" : "pause.fill") {
                    s.wrappedValue.setPaused(!s.wrappedValue.isPaused)
                    model.update(s.wrappedValue, for: key)
                }
                .accessibilityIdentifier("pauseButton")
                Menu {
                    Button("Check Cell") { s.wrappedValue.checkCell(); changed(s.wrappedValue) }
                    Button("Check Puzzle") { s.wrappedValue.checkPuzzle(); changed(s.wrappedValue) }
                    Button("Reveal Cell") { s.wrappedValue.revealCell(); changed(s.wrappedValue) }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityIdentifier("gameMenu")
            }
        }
        .sheet(isPresented: $showCageHelper) { CageHelperView(session: s.wrappedValue) }
        .sheet(isPresented: $showCompletion) {
            CompletionView(session: s.wrappedValue, mistakesCounted: model.settings.mistakeHighlighting) {
                showCompletion = false
                dismiss()
            }
            .interactiveDismissDisabled()
        }
    }

    private func changed(_ s: GameSession) {
        if s.isComplete {
            model.finish(s, for: key)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showCompletion = true
        } else {
            model.update(s, for: key)
            if let cell = s.selected, model.settings.mistakeHighlighting, s.isWrong(cell) {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}
