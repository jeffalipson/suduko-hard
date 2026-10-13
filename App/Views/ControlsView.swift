import SwiftUI
import SudokuGame

/// `.row`: today's layout (keys 1–5 over 6–9, one row of tools). `.column`: the side column (3×3 keys, tools in rows of three).
enum ControlsArrangement { case row, column }

struct ControlsView: View {
    @Binding var session: GameSession
    let settings: GameSettings
    let onChange: () -> Void
    @Binding var showCageHelper: Bool
    let onHint: () -> Void
    var arrangement: ControlsArrangement = .row
    /// Size multiplier for keys and tools (1.3 in iPad-sized windows).
    var scale: CGFloat = 1

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
            keypad
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

    @ViewBuilder private var tools: some View {
        switch arrangement {
        case .row: HStack { toolButtons }
        case .column: LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) { toolButtons }
        }
    }

    @ViewBuilder private var toolButtons: some View {
        tool("Undo", "arrow.uturn.backward", id: "undo", enabled: session.canUndo) { session.undo() }
            .keyboardShortcut("z", modifiers: .command)
        tool("Redo", "arrow.uturn.forward", id: "redo", enabled: session.canRedo) { session.redo() }
            .keyboardShortcut("z", modifiers: [.command, .shift])
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
                Image(systemName: icon).font(.system(size: 20 * scale))
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
        .accessibilityIdentifier(id)
    }
}
