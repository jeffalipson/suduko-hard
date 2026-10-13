import SwiftData
import SwiftUI
import SudokuCore
import SudokuGame

/// Home: the caged wordmark, a Continue card for the game in progress, the Classic/Killer switch,
/// and the difficulty ladder.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Query private var records: [GameRecord]
    @State private var mode: Mode = .classic
    @State private var playing: QueueKey?
    @State private var showSettings = false
    @State private var showStats = false
    @State private var debugLesson: TechniqueID?
    @State private var debugExplain: TechniqueID?
    @State private var confirmNew: QueueKey?
    @State private var generating: QueueKey?
    @State private var generationTask: Task<Void, Never>?
    @State private var generationFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    topBar
                    CagedWordmark()
                    if let (key, game) = latestGame { ContinueCard(key: key, game: game) { playing = key } }
                    ModeSwitch(mode: $mode)
                    ladder
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(HomePalette.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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
            .sheet(item: $debugExplain) { id in
                if let example = model.lessons[id] {
                    NavigationStack { ExplainView(board: example.board, step: example.step, onApply: nil) }
                }
            }
            .navigationDestination(item: $playing) { key in GameView(key: key) }
            .onAppear(perform: openFromLaunchArguments)
            .alert("Couldn't make a puzzle in time", isPresented: $generationFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Background generation keeps trying. Check back in a few minutes.")
            }
            .overlay { if let key = generating { generatingOverlay(key) } }
        }
        .tint(HomePalette.signal)
    }

    // MARK: Sections

    private var topBar: some View {
        HStack {
            Button { showStats = true } label: {
                Image(systemName: "chart.bar.xaxis").font(.title3)
            }
            .accessibilityLabel("Stats")
            .accessibilityIdentifier("statsButton")
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.title3)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("settingsButton")
        }
        .foregroundStyle(HomePalette.ink)
        .padding(.top, 8)
    }

    private var ladder: some View {
        VStack(spacing: 0) {
            ForEach(Tier.allCases, id: \.self) { tier in
                let key = QueueKey(mode: mode, tier: tier)
                Button { open(key) } label: {
                    TierRow(tier: tier, inProgress: model.resumable(key), best: bestTime(key))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tier-\(tier.name)")
                .contextMenu {
                    if model.resumable(key) != nil {
                        Button("New Game", systemImage: "arrow.counterclockwise") { confirmNew = key }
                    }
                }
                if tier != .nightmare { Divider().overlay(HomePalette.cell) }
            }
        }
    }

    private func generatingOverlay(_ key: QueueKey) -> some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()   // blocks taps on other rows
            VStack(spacing: 12) {
                ProgressView()
                Text("Making a \(key.mode.rawValue) \(key.tier.name) puzzle").font(.subheadline.weight(.semibold))
                Text("Hard tiers can take a minute or two.").font(.caption).foregroundStyle(.secondary)
                Button("Cancel") { generationTask?.cancel(); generating = nil }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    // MARK: Data

    /// The game in progress started most recently.
    private var latestGame: (QueueKey, GameSession)? {
        QueueKey.all.compactMap { key in model.resumable(key).map { (key, $0) } }
            .max { ($0.1.startedAt ?? .distantPast) < ($1.1.startedAt ?? .distantPast) }
    }

    private func bestTime(_ key: QueueKey) -> Double? {
        records.filter { $0.won && $0.mode == key.mode.rawValue && $0.tier == key.tier.rawValue }.map(\.elapsed).min()
    }

    // MARK: Navigation

    /// `-open killer-hard` jumps straight into a game (used for screenshots and UI tests).
    private func openFromLaunchArguments() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-stats") { showStats = true }
        if let i = args.firstIndex(of: "-lesson"), i + 1 < args.count { debugLesson = TechniqueID(rawValue: args[i + 1]) }
        if let i = args.firstIndex(of: "-explain"), i + 1 < args.count { debugExplain = TechniqueID(rawValue: args[i + 1]) }
        if args.contains("-killer") { mode = .killer }
        guard let i = args.firstIndex(of: "-open"), i + 1 < args.count,
              let key = QueueKey.all.first(where: { $0.name == args[i + 1] }) else { return }
        mode = key.mode
        if args.contains("-new") { startNew(key) } else { open(key) }
        #endif
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

// MARK: - Palette

/// Cool navy ink on paper (light) or ink on navy (dark), taken from the app icon.
enum HomePalette {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    static let paper = adaptive(0xF5F7FB, 0x0A1230)
    static let ink = adaptive(0x13214A, 0xE8EDF8)
    static let muted = adaptive(0x5B6788, 0x9AA6C8)
    static let cell = adaptive(0xE3E9F6, 0x1B2650)
    static let signal = adaptive(0x3D7BFF, 0x6E9BFF)
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - Wordmark

/// "really really Hard Sudoku" inside a dashed Killer cage, with 45 — every house's sum — as the cage total.
private struct CagedWordmark: View {
    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text("really really")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(HomePalette.muted)
            Text("Hard Sudoku")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(HomePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(HomePalette.ink.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [9, 7]))
        }
        .overlay(alignment: .topLeading) {
            Text("45")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(HomePalette.ink)
                .padding(.horizontal, 6)
                .background(HomePalette.paper)
                .offset(x: 14, y: -10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Really Really Hard Sudoku")
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Continue

private struct ContinueCard: View {
    let key: QueueKey
    let game: GameSession
    let onContinue: () -> Void

    var body: some View {
        Button(action: onContinue) {
            HStack(spacing: 16) {
                BoardView(session: game, settings: GameSettings()) { _ in }
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue").font(.subheadline.weight(.semibold)).foregroundStyle(HomePalette.signal)
                    Text("\(key.mode.rawValue.capitalized) \(key.tier.name.capitalized)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(HomePalette.ink)
                    Text("\(GameView.clock(game.elapsed)) played, \(filledPercent)% filled")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(HomePalette.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(HomePalette.signal, in: Circle())
            }
            .padding(14)
            .background(HomePalette.cell, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continueCard")
    }

    private var filledPercent: Int {
        let open = game.puzzle.givens.filter { $0 == 0 }.count
        guard open > 0 else { return 100 }
        let filled = (0..<81).filter { game.puzzle.givens[$0] == 0 && game.entries[$0] != 0 }.count
        return Int((Double(filled) / Double(open) * 100).rounded())
    }
}

// MARK: - Mode switch

private struct ModeSwitch: View {
    @Binding var mode: Mode

    var body: some View {
        HStack(spacing: 10) {
            option(.classic, "Classic", glyph: AnyView(GridGlyph()))
            option(.killer, "Killer", glyph: AnyView(CageGlyph()))
        }
        .accessibilityIdentifier("modePicker")
    }

    private func option(_ value: Mode, _ title: String, glyph: AnyView) -> some View {
        let selected = mode == value
        return Button {
            withAnimation(.snappy(duration: 0.2)) { mode = value }
        } label: {
            HStack(spacing: 10) {
                glyph.frame(width: 22, height: 22)
                Text(title).font(.system(.headline, design: .rounded))
            }
            .foregroundStyle(selected ? HomePalette.paper : HomePalette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? HomePalette.ink : HomePalette.cell, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A plain 3×3 grid.
private struct GridGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            for i in 0...3 {
                let p = CGFloat(i) * size.width / 3
                var v = Path(); v.move(to: CGPoint(x: p, y: 0)); v.addLine(to: CGPoint(x: p, y: size.height))
                var h = Path(); h.move(to: CGPoint(x: 0, y: p)); h.addLine(to: CGPoint(x: size.width, y: p))
                ctx.stroke(v, with: .foreground, lineWidth: 1.4)
                ctx.stroke(h, with: .foreground, lineWidth: 1.4)
            }
        }
    }
}

/// A dashed cage with a tiny sum.
private struct CageGlyph: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4).strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: [3, 2.5]))
            Text("9").font(.system(size: 8, weight: .bold, design: .rounded)).padding(.leading, 3).padding(.top, 1)
        }
    }
}

// MARK: - Ladder

private struct TierRow: View {
    let tier: Tier
    let inProgress: GameSession?
    let best: Double?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(tier.name.capitalized)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(HomePalette.ink)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                LevelPips(level: tier.rawValue + 1)
                status
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var status: some View {
        if let game = inProgress {
            Text("In progress \(GameView.clock(game.elapsed))")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(HomePalette.signal)
        } else if let best {
            Text("Best \(GameView.clock(best))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(HomePalette.muted)
        } else {
            Text("Not played yet").font(.caption).foregroundStyle(HomePalette.muted.opacity(0.8))
        }
    }
}

/// Seven small cells, filled up to the tier's level.
private struct LevelPips: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...7, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= level ? HomePalette.signal : HomePalette.cell)
                    .frame(width: 9, height: 9)
            }
        }
        .accessibilityHidden(true)
    }
}
