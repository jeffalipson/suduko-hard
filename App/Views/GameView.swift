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

    /// How many nudge levels the current hint has; the spotlight comes after them.
    private var nudgeLevels: Int { diagnosis.map(HintText.levels(for:)) ?? 1 }
    private var spotlightOn: Bool { hintStep != nil && hintLevel > nudgeLevels }

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
            if ProcessInfo.processInfo.arguments.contains("-nearlysolved") {   // UI tests: one cell left
                let open = (0..<81).filter { s.entries[$0] == 0 }
                for c in open.dropLast() {
                    s.selected = c
                    s.input(s.puzzle.solution[c], settings: GameSettings())
                }
                s.selected = open.last
            }
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
                          spotlight: spotlightOn ? Set(hintStep?.patternCells ?? []) : [],
                          pattern: spotlightOn ? (hintStep?.patternCandidates ?? []) : [],
                          secondary: spotlightOn ? (hintStep?.groups.dropFirst(hintStep?.technique == .simpleColoring ? 1 : 0).flatMap { $0 } ?? []) : []) { cell in
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
                HintBar(diagnosis: diagnosis, level: hintLevel, nudgeLevels: nudgeLevels,
                        onMore: { escalateHint(s) },
                        onSpotlight: { escalateHint(s) },
                        onLesson: {
                            logHint("lesson", s)
                            showLesson = true
                        },
                        onAutoCandidates: {
                            s.wrappedValue.setAutoCandidates(true)
                            changed(s.wrappedValue)
                            startHint(s)   // re-diagnose now that every candidate is shown
                        },
                        onClose: { self.diagnosis = nil; hintLevel = 0 })
                    .padding(.horizontal, 12)
            }
            ControlsView(session: s, settings: model.settings, onChange: { changed(s.wrappedValue) }, showCageHelper: $showCageHelper,
                         onHint: {
                             // Each tap escalates: technique → digit → place → spotlight → lesson,
                             // or for a mistake: what's wrong → which box → which cell.
                             if hintStep != nil {
                                 if hintLevel <= nudgeLevels { escalateHint(s) } else { logHint("lesson", s); showLesson = true }
                                 return
                             }
                             if diagnosis?.isMistake == true && hintLevel < nudgeLevels {
                                 escalateHint(s)
                                 return
                             }
                             startHint(s)
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
                LessonView(technique: step.technique, example: model.lessons[step.technique],
                           yours: (HintEngine.playerBoard(s.wrappedValue), step)) {
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

    /// Next hint level: a more specific nudge, then the spotlight.
    private func startHint(_ s: Binding<GameSession>) {
        let d = HintEngine.diagnose(s.wrappedValue)
        diagnosis = d
        hintLevel = 1
        loggedLevels = []
        if case .step = d { logHint("nudge", s) }
        if d.isMistake { logHint("nudge", s) }
    }

    private func escalateHint(_ s: Binding<GameSession>) {
        hintLevel += 1
        if case .mistake(let cell, _) = diagnosis, hintLevel >= nudgeLevels {
            // The exact cell is what Check would show, so it counts as a check.
            s.wrappedValue.pointOutMistake(cell)
            model.update(s.wrappedValue, for: key)
        } else if hintLevel <= nudgeLevels {
            logHint("nudge\(hintLevel)", s, counting: "nudge")
        } else {
            logHint("spotlight", s)
        }
    }

    private func logHint(_ level: String, _ s: Binding<GameSession>, counting stat: String? = nil) {
        guard loggedLevels.insert(level).inserted else { return }
        s.wrappedValue.useHint(stat ?? level)
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
