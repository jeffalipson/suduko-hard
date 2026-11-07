import SwiftUI
import SudokuCore
import SudokuGame

/// A Mathdoku game: the same screen, controls, hints and keyboard as `GameView`, on an n×n cage grid.
struct MathdokuGameView: View {
    let tier: Tier
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var session: MathdokuSession?
    @State private var showCompletion = false
    @State private var diagnosis: MathHintDiagnosis?
    @State private var hintLevel = 0
    @State private var showLesson = false
    @State private var pendingShowMe: MathStep?
    @State private var loggedLevels: Set<String> = []
    @FocusState private var boardFocused: Bool
    @State private var colorMode = false
    @State private var activeColor = 1
    /// Not used by Mathdoku; the shared controls take a binding.
    @State private var noCageHelper = false

    private var nudgeLevels: Int { diagnosis.map(MathHintText.levels(for:)) ?? 1 }
    private var spotlightOn: Bool { hintStep != nil && hintLevel > nudgeLevels }
    private var hintStep: MathStep? {
        if case .step(let step) = diagnosis { return step }
        return nil
    }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let binding = Binding($session) { content(binding) } else { ProgressView() }
        }
        .onAppear {
            guard var s = model.resumableMath(tier) else { return }
            s.setPaused(false)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-auto") { s.setAutoCandidates(true) }
            if ProcessInfo.processInfo.arguments.contains("-nearlysolved") {   // UI tests: one cell left
                let open = (0..<s.cellCount).filter { s.entries[$0] == 0 }
                for c in open.dropLast() {
                    s.selected = c
                    s.input(s.puzzle.solution[c], settings: GameSettings())
                }
                s.selected = open.last
            }
            #endif
            session = s
        }
        .onReceive(timer) { _ in
            guard phase == .active, var s = session, !s.isComplete else { return }
            s.tick(1)
            session = s
        }
        .onDisappear { if let s = session, !s.isComplete { model.updateMath(s, for: tier) } }
        .onChange(of: phase) { _, new in
            if new != .active, var s = session, !s.isComplete { s.setPaused(true); session = s; model.updateMath(s, for: tier) }
        }
    }

    private var regular: Bool { sizeClass == .regular }

    @ViewBuilder
    private func content(_ s: Binding<MathdokuSession>) -> some View {
        GeometryReader { geo in
            switch GameLayout.choose(width: geo.size.width, height: geo.size.height) {
            case .stacked:
                VStack(spacing: 16) {
                    boardArea(s).padding(.horizontal, 8)
                    VStack(spacing: 16) {
                        hintBar(s)
                        controls(s, .row)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: regular ? 560 : .infinity)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            case .sideBySide(let board):
                HStack(alignment: .top, spacing: 16) {
                    boardArea(s).frame(width: board, height: board)
                    ScrollView {
                        VStack(spacing: 16) {
                            controls(s, .column)
                            hintBar(s)
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: GameLayout.columnWidth)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .focusable()
        .focused($boardFocused)
        .focusEffectDisabled()
        .onAppear { boardFocused = true }
        .onChange(of: showLesson) { _, open in if !open { boardFocused = true } }
        .onKeyPress(phases: .down) { press in handleKey(press, s) }
        .regularWidthTypeBoost(regular)
        .navigationTitle("Mathdoku · \(tier.name.capitalized)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", systemImage: "chevron.left") { dismiss() }
                    .accessibilityIdentifier("backButton")
            }
            ToolbarItem(placement: .principal) {
                Text(GameView.clock(s.wrappedValue.elapsed)).monospacedDigit().font(.headline).accessibilityIdentifier("clock")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(s.wrappedValue.isPaused ? "Resume" : "Pause", systemImage: s.wrappedValue.isPaused ? "play.fill" : "pause.fill") {
                    s.wrappedValue.setPaused(!s.wrappedValue.isPaused)
                    model.updateMath(s.wrappedValue, for: tier)
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
        .sheet(isPresented: $showLesson, onDismiss: {
            guard let step = pendingShowMe else { return }
            pendingShowMe = nil
            s.wrappedValue.showMe(step)
            diagnosis = nil
            hintLevel = 0
            changed(s.wrappedValue)
        }) {
            if let step = hintStep {
                MathLessonView(step: step, puzzle: s.wrappedValue.puzzle) { pendingShowMe = step }
            }
        }
        .sheet(isPresented: $showCompletion) {
            MathCompletionView(session: s.wrappedValue) {
                showCompletion = false
                dismiss()
            }
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder private func boardArea(_ s: Binding<MathdokuSession>) -> some View {
        ZStack {
            MathdokuBoardView(session: s.wrappedValue, settings: model.settings,
                              spotlight: spotlightOn ? Set(hintStep?.cells ?? []) : [],
                              marks: spotlightOn ? (hintStep?.eliminations ?? []) : []) { cell in
                s.wrappedValue.selected = cell
                if colorMode {
                    s.wrappedValue.setColor(activeColor, at: cell)
                    changed(s.wrappedValue)
                }
            }
            .opacity(s.wrappedValue.isPaused ? 0 : 1)
            if s.wrappedValue.isPaused {
                Button {
                    s.wrappedValue.setPaused(false)
                    model.updateMath(s.wrappedValue, for: tier)
                } label: {
                    Label("Resume", systemImage: "play.fill").font(.title2)
                }
                .accessibilityIdentifier("resumeButton")
            }
        }
    }

    @ViewBuilder private func hintBar(_ s: Binding<MathdokuSession>) -> some View {
        if let diagnosis, !s.wrappedValue.isPaused {
            let isStep = hintStep != nil
            HintBar(message: MathHintText.message(diagnosis, level: hintLevel, puzzle: s.wrappedValue.puzzle),
                    isMistake: diagnosis.isMistake, isStep: isStep, offersAutoPencil: MathHintText.offersAutoPencil(diagnosis),
                    level: hintLevel, nudgeLevels: nudgeLevels,
                    onMore: { escalateHint(s) },
                    onSpotlight: { escalateHint(s) },
                    onLesson: {
                        logHint("lesson", s)
                        showLesson = true
                    },
                    onAutoCandidates: {
                        s.wrappedValue.setAutoCandidates(true)
                        changed(s.wrappedValue)
                        startHint(s)
                    },
                    onClose: { self.diagnosis = nil; hintLevel = 0 })
        }
    }

    private func controls(_ s: Binding<MathdokuSession>, _ arrangement: ControlsArrangement) -> some View {
        ControlsView(session: s, settings: model.settings, onChange: { changed(s.wrappedValue) }, showCageHelper: $noCageHelper,
                     colorMode: $colorMode, activeColor: $activeColor,
                     onHint: {
                         if hintStep != nil {
                             if hintLevel <= nudgeLevels { escalateHint(s) } else { logHint("lesson", s); showLesson = true }
                             return
                         }
                         if diagnosis?.isMistake == true && hintLevel < nudgeLevels {
                             escalateHint(s)
                             return
                         }
                         startHint(s)
                     },
                     arrangement: arrangement, scale: regular ? 1.3 : 1,
                     shortcutsEnabled: !(showLesson || showCompletion))
            .disabled(s.wrappedValue.isPaused)
    }

    private func handleKey(_ press: KeyPress, _ s: Binding<MathdokuSession>) -> KeyPress.Result {
        guard !s.wrappedValue.isPaused, !s.wrappedValue.isComplete, !press.modifiers.contains(.command) else { return .ignored }
        let key: GameKey
        switch press.key {
        case .upArrow: key = .up
        case .downArrow: key = .down
        case .leftArrow: key = .left
        case .rightArrow: key = .right
        case .delete, .deleteForward: key = .delete
        default: key = .text(press.characters)
        }
        guard let action = KeyCommand.action(for: key) else { return .ignored }
        switch action {
        case .move(let rows, let columns):
            s.wrappedValue.moveSelection(rows: rows, columns: columns)
        case .digit(let d):
            guard d <= s.wrappedValue.n else { return .ignored }
            s.wrappedValue.input(d, settings: model.settings)
            changed(s.wrappedValue)
        case .erase:
            s.wrappedValue.erase()
            changed(s.wrappedValue)
        case .toggleInputMode:
            s.wrappedValue.inputMode = s.wrappedValue.inputMode == .normal ? .candidate : .normal
        }
        return .handled
    }

    private func startHint(_ s: Binding<MathdokuSession>) {
        let d = MathdokuHintEngine.diagnose(s.wrappedValue)
        diagnosis = d
        hintLevel = 1
        loggedLevels = []
        if case .step = d { logHint("nudge", s) }
        if d.isMistake { logHint("nudge", s) }
    }

    private func escalateHint(_ s: Binding<MathdokuSession>) {
        hintLevel += 1
        if case .mistake(let cell, _) = diagnosis, hintLevel >= nudgeLevels {
            s.wrappedValue.pointOutMistake(cell)
            model.updateMath(s.wrappedValue, for: tier)
        } else if hintLevel <= nudgeLevels {
            logHint("nudge\(hintLevel)", s, counting: "nudge")
        } else {
            logHint("spotlight", s)
        }
    }

    private func logHint(_ level: String, _ s: Binding<MathdokuSession>, counting stat: String? = nil) {
        guard loggedLevels.insert(level).inserted else { return }
        s.wrappedValue.useHint(stat ?? level)
        model.updateMath(s.wrappedValue, for: tier)
    }

    private func changed(_ s: MathdokuSession) {
        if hintLevel > 0 && !showLesson { diagnosis = nil; hintLevel = 0 }
        if s.isComplete {
            model.finishMath(s, for: tier)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showCompletion = true
        } else {
            model.updateMath(s, for: tier)
            if let cell = s.selected, model.settings.mistakeHighlighting, s.isWrong(cell) {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

/// The lesson for a hint's technique, with Show me to apply the step on the player's board.
struct MathLessonView: View {
    let step: MathStep
    let puzzle: MathdokuPuzzle
    let onShowMe: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(MathLessonText.summary(step.technique)).font(.title3.weight(.semibold))
                    Text(MathLessonText.body(step.technique)).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("On your board").font(.headline)
                        Text(MathHintText.message(.step(step), level: 3, puzzle: puzzle))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("lessonOnBoard")
                    }
                    Button {
                        onShowMe()
                        dismiss()
                    } label: {
                        Label("Show me", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("showMe")
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(step.technique.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

struct MathCompletionView: View {
    let session: MathdokuSession
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: session.log.isClean ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)
            Text(session.log.isClean ? "Clean Solve" : "Solved").font(.largeTitle.bold())
            Text("Mathdoku · \(session.puzzle.tier.name.capitalized) · \(session.n)×\(session.n)").foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { Text("Time"); Text(GameView.clock(session.elapsed)).monospacedDigit() }
                if GameRecordData.recordedMistakes(session.log) != nil { GridRow { Text("Mistakes"); Text("\(session.log.mistakes)") } }
                GridRow { Text("Checks"); Text("\(session.log.checks)") }
                GridRow { Text("Reveals"); Text("\(session.log.reveals)") }
                GridRow { Text("Assists"); Text("\(session.log.autoCandidates)") }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("What it took").font(.headline)
                Text(session.puzzle.techniques.map(\.name).joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Done", action: onDone).buttonStyle(.borderedProminent).accessibilityIdentifier("completionDone")
        }
        .padding(28)
    }
}
