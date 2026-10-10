import SwiftUI
import SudokuGame

struct ControlsView: View {
    @Binding var session: GameSession
    let settings: GameSettings
    let onChange: () -> Void
    @Binding var showCageHelper: Bool

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
            HStack(spacing: 6) {
                ForEach(1...9, id: \.self) { d in
                    let done = session.placedCount(of: d) >= 9
                    Button {
                        session.input(d, settings: settings)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onChange()
                    } label: {
                        Text("\(d)")
                            .font(.system(size: session.inputMode == .normal ? 30 : 22, weight: .regular))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(done ? Color.secondary.opacity(0.4) : Theme.accent)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityIdentifier("digit-\(d)")
                }
            }
            HStack {
                tool("Undo", "arrow.uturn.backward", id: "undo", enabled: session.canUndo) { session.undo() }
                tool("Redo", "arrow.uturn.forward", id: "redo", enabled: session.canRedo) { session.redo() }
                tool("Erase", "eraser", id: "erase") { session.erase() }
                if settings.autoCandidates {
                    tool("Auto", "square.grid.3x3", id: "autoCandidates") { session.fillAllCandidates() }
                }
                if settings.cageHelper && !session.puzzle.cages.isEmpty {
                    tool("Cage", "sum", id: "cageHelper", enabled: session.selected != nil) {
                        session.useCageHelper()
                        showCageHelper = true
                    }
                }
                tool("Hint", "lightbulb", id: "hint", enabled: false) {}   // Plan 6
            }
        }
    }

    private func tool(_ title: String, _ icon: String, id: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            action()
            onChange()
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
