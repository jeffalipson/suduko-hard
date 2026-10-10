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
    @State private var diagnosis: HintDiagnosis?
    @State private var hintLevel = 0
    @State private var showLesson = false
    /// Show me waits until the lesson sheet has closed, so a solving step can present completion.
    @State private var pendingShowMe: Step?
    /// Hint levels already logged for the current diagnosis (each counted once).
    @State private var loggedLevels: Set<String> = []

    private var hintStep: Step? {
        if case .step(let step) = diagnosis { return step }
        return nil
    }
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
            if ProcessInfo.processInfo.arguments.contains("-auto") { s.setAutoCandidates(true) }   // screenshots
            session = s
        }
        .onReceive(timer) { _ in
            // Only advances the clock; the game is saved on moves and when the app leaves the foreground.
            guard phase == .active, var s = session, !s.isComplete else { return }
            s.tick(1)
            session = s
        }
        .onDisappear {
            // Keep the clock's progress when leaving (moves save themselves; ticks don't).
            if let s = session, !s.isComplete { model.update(s, for: key) }
        }
        .onChange(of: phase) { _, new in
            if new != .active, var s = session, !s.isComplete { s.setPaused(true); session = s; model.update(s, for: key) }
        }
    }

    @ViewBuilder
    private func content(_ s: Binding<GameSession>) -> some View {
        VStack(spacing: 16) {
            ZStack {
                BoardView(session: s.wrappedValue, settings: model.settings,
                          spotlight: hintLevel >= 2 ? Set(hintStep?.patternCells ?? []) : [],
                          pattern: hintLevel >= 2 ? (hintStep?.patternCandidates ?? []) : [],
                          secondary: hintLevel >= 2 ? (hintStep?.groups.dropFirst(hintStep?.technique == .simpleColoring ? 1 : 0).flatMap { $0 } ?? []) : []) { cell in
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
            if let diagnosis, !s.wrappedValue.isPaused {
                HintBar(diagnosis: diagnosis, level: hintLevel,
                        onSpotlight: {
                            hintLevel = 2
                            logHint("spotlight", s)
                        },
                        onLesson: {
                            logHint("lesson", s)
                            showLesson = true
                        },
                        onClose: { self.diagnosis = nil; hintLevel = 0 })
                    .padding(.horizontal, 12)
            }
            ControlsView(session: s, settings: model.settings, onChange: { changed(s.wrappedValue) }, showCageHelper: $showCageHelper,
                         onHint: {
                             // Each tap escalates: nudge → spotlight → lesson.
                             if hintStep != nil {
                                 if hintLevel < 2 {
                                     hintLevel = 2
                                     logHint("spotlight", s)
                                 } else {
                                     logHint("lesson", s)
                                     showLesson = true
                                 }
                                 return
                             }
                             let d = HintEngine.diagnose(s.wrappedValue)
                             diagnosis = d
                             hintLevel = 1
                             loggedLevels = []
                             if case .step = d { logHint("nudge", s) }
                         })
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
                    Button("Reveal Cell") { s.wrappedValue.revealCell(settings: model.settings); changed(s.wrappedValue) }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityIdentifier("gameMenu")
            }
        }
        .sheet(isPresented: $showCageHelper) { CageHelperView(session: s.wrappedValue) }
        .sheet(isPresented: $showLesson, onDismiss: {
            guard let step = pendingShowMe else { return }
            pendingShowMe = nil
            s.wrappedValue.showMe(step)
            diagnosis = nil
            hintLevel = 0
            changed(s.wrappedValue)
        }) {
            if let step = hintStep {
                LessonView(technique: step.technique, example: model.lessons[step.technique]) {
                    pendingShowMe = step
                }
            }
        }
        .sheet(isPresented: $showCompletion) {
            CompletionView(session: s.wrappedValue, mistakesCounted: GameRecordData.recordedMistakes(s.wrappedValue.log) != nil) {
                showCompletion = false
                dismiss()
            }
            .interactiveDismissDisabled()
        }
    }

    private func logHint(_ level: String, _ s: Binding<GameSession>) {
        guard loggedLevels.insert(level).inserted else { return }
        s.wrappedValue.useHint(level)
        model.update(s.wrappedValue, for: key)
    }

    private func changed(_ s: GameSession) {
        if hintLevel > 0 && !showLesson { diagnosis = nil; hintLevel = 0 }
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
