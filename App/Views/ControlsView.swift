import SwiftUI
import SudokuGame

struct ControlsView: View {
    @Binding var session: GameSession
    let settings: GameSettings
    let onChange: () -> Void
    @Binding var showCageHelper: Bool
    let onHint: () -> Void

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
            // Two rows, 1–5 over a centred 6–9, so each key is wide enough to hit easily.
            GeometryReader { geo in
                let spacing: CGFloat = 8
                let key = (geo.size.width - 4 * spacing) / 5
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) { ForEach(1...5, id: \.self) { digitKey($0, width: key) } }
                    HStack(spacing: spacing) { ForEach(6...9, id: \.self) { digitKey($0, width: key) } }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 2 * 52 + 8)
            HStack {
                tool("Undo", "arrow.uturn.backward", id: "undo", enabled: session.canUndo) { session.undo() }
                tool("Redo", "arrow.uturn.forward", id: "redo", enabled: session.canRedo) { session.redo() }
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
        }
    }

    private func digitKey(_ d: Int, width: CGFloat) -> some View {
        let done = session.placedCount(of: d) >= 9
        return Button {
            session.input(d, settings: settings)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onChange()
        } label: {
            Text("\(d)")
                .font(.system(size: session.inputMode == .normal ? 30 : 22, weight: .regular))
                .frame(width: width, height: 52)
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
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
        .accessibilityIdentifier(id)
    }
}
