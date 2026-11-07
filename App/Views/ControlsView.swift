import SwiftUI
import SudokuGame

/// `.row`: today's layout (keys 1–5 over 6–9, one row of tools). `.column`: the side column (3×3 keys, tools in rows of three).
enum ControlsArrangement { case row, column }

struct ControlsView: View {
    @Binding var session: GameSession
    let settings: GameSettings
    let onChange: () -> Void
    @Binding var showCageHelper: Bool
    /// Colour mode: the keys become a palette and tapping cells paints them.
    @Binding var colorMode: Bool
    /// The colour cells are painted with (1…GameSession.colorCount).
    @Binding var activeColor: Int
    let onHint: () -> Void
    var arrangement: ControlsArrangement = .row
    /// Size multiplier for keys and tools (1.3 in iPad-sized windows).
    var scale: CGFloat = 1
    /// ⌘Z / ⇧⌘Z; off while a sheet is up so they can't change the board behind it.
    var shortcutsEnabled = true

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Picker("Input", selection: $session.inputMode) {
                    Text("Normal").tag(InputMode.normal)
                    Text("Candidate").tag(InputMode.candidate)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("inputMode")
            }
            if colorMode { palette } else { keypad }
            tools
        }
    }

    @ViewBuilder private var keypad: some View {
        switch arrangement {
        case .row:
            // Two rows, 1–5 over a centred 6–9, so each key is wide enough to hit easily.
            GeometryReader { geo in
                let spacing: CGFloat = 8
                let key = (geo.size.width - 4 * spacing) / 5
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) { ForEach(1...5, id: \.self) { digitKey($0, width: key, height: 52 * scale) } }
                    HStack(spacing: spacing) { ForEach(6...9, id: \.self) { digitKey($0, width: key, height: 52 * scale) } }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 2 * 52 * scale + 8)
        case .column:
            // Calculator layout: 1 2 3 / 4 5 6 / 7 8 9.
            GeometryReader { geo in
                let spacing: CGFloat = 8
                let key = (geo.size.width - 2 * spacing) / 3
                VStack(spacing: spacing) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(1...3, id: \.self) { col in digitKey(row * 3 + col, width: key, height: 72) }
                        }
                    }
                }
            }
            .frame(height: 3 * 72 + 2 * 8)
        }
    }

    /// Nine colours laid out like the keypad, then Clear and Clear all.
    @ViewBuilder private var palette: some View {
        VStack(spacing: 8) {
            switch arrangement {
            case .row:
                GeometryReader { geo in
                    let spacing: CGFloat = 8
                    let key = (geo.size.width - 4 * spacing) / 5
                    VStack(spacing: spacing) {
                        HStack(spacing: spacing) { ForEach(1...5, id: \.self) { swatch($0, width: key, height: 52 * scale) } }
                        HStack(spacing: spacing) { ForEach(6...9, id: \.self) { swatch($0, width: key, height: 52 * scale) } }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 2 * 52 * scale + 8)
            case .column:
                GeometryReader { geo in
                    let spacing: CGFloat = 8
                    let key = (geo.size.width - 2 * spacing) / 3
                    VStack(spacing: spacing) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: spacing) { ForEach(1...3, id: \.self) { col in swatch(row * 3 + col, width: key, height: 72) } }
                        }
                    }
                }
                .frame(height: 3 * 72 + 2 * 8)
            }
            HStack {
                Button("Clear cell") {
                    if let cell = session.selected { session.setColor(0, at: cell); onChange() }
                }
                .disabled(session.selected.map { session.color(of: $0) == 0 } ?? true)
                .accessibilityIdentifier("clearColor")
                Spacer()
                Button("Clear all colors") { session.clearColors(); onChange() }
                    .disabled(!session.hasColors)
                    .accessibilityIdentifier("clearAllColors")
            }
            .font(.subheadline)
        }
    }

    private func swatch(_ i: Int, width: CGFloat, height: CGFloat) -> some View {
        let chosen = activeColor == i
        return Button {
            activeColor = i
            if let cell = session.selected { session.setColor(i, at: cell); onChange() }
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.cellColors[i - 1])
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary, lineWidth: chosen ? 3 : 0))
                .frame(width: width, height: height)
        }
        .accessibilityLabel("Color \(i)")
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityIdentifier("color-\(i)")
    }

    @ViewBuilder private var tools: some View {
        switch arrangement {
        case .row: HStack { toolButtons }
        case .column: LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) { toolButtons }
        }
    }

    @ViewBuilder private var toolButtons: some View {
        tool("Undo", "arrow.uturn.backward", id: "undo", enabled: session.canUndo) { session.undo() }
            .keyboardShortcut(shortcutsEnabled ? KeyboardShortcut("z", modifiers: .command) : nil)
        tool("Redo", "arrow.uturn.forward", id: "redo", enabled: session.canRedo) { session.redo() }
            .keyboardShortcut(shortcutsEnabled ? KeyboardShortcut("z", modifiers: [.command, .shift]) : nil)
        tool("Erase", "eraser", id: "erase") { session.erase() }
        if settings.cageHelper && !session.puzzle.cages.isEmpty {
            tool("Cage", "sum", id: "cageHelper", enabled: session.selected != nil) {
                session.useCageHelper()
                showCageHelper = true
            }
        }
        tool("Auto Pencil", session.autoCandidateMode ? "checkmark.square.fill" : "square", id: "autoCandidates") {
            session.setAutoCandidates(!session.autoCandidateMode)
        }
        .accessibilityLabel("Auto Pencil")
        .accessibilityValue(session.autoCandidateMode ? "on" : "off")
        tool("Color", colorMode ? "paintpalette.fill" : "paintpalette", id: "colorMode", notify: false) {
            colorMode.toggle()
            if colorMode && activeColor == 0 { activeColor = 1 }
        }
        .accessibilityValue(colorMode ? "on" : "off")
        tool("Hint", "lightbulb", id: "hint", notify: false) { onHint() }
    }

    private func digitKey(_ d: Int, width: CGFloat, height: CGFloat) -> some View {
        let done = session.placedCount(of: d) >= 9
        return Button {
            session.input(d, settings: settings)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onChange()
        } label: {
            Text("\(d)")
                .font(.system(size: (session.inputMode == .normal ? 30 : 22) * scale, weight: .regular))
                .frame(width: width, height: height)
                .foregroundStyle(done ? Color.secondary.opacity(0.4) : Theme.accent)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityIdentifier("digit-\(d)")
    }

    private func tool(_ title: String, _ icon: String, id: String, enabled: Bool = true, notify: Bool = true,
                      action: @escaping () -> Void) -> some View {
        Button {
            action()
            if notify { onChange() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)   // iPad sizes come from regularWidthTypeBoost
                Text(title).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
        .accessibilityIdentifier(id)
    }
}
