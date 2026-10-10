import SwiftUI
import SudokuGame

struct CompletionView: View {
    let session: GameSession
    let mistakesCounted: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: session.log.isClean ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)
            Text(session.log.isClean ? "Clean Solve" : "Solved").font(.largeTitle.bold())
            Text("\(session.puzzle.mode.rawValue.capitalized) · \(session.puzzle.grade.tier.name.capitalized)")
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { Text("Time"); Text(GameView.clock(session.elapsed)).monospacedDigit() }
                if mistakesCounted { GridRow { Text("Mistakes"); Text("\(session.log.mistakes)") } }
                GridRow { Text("Checks"); Text("\(session.log.checks)") }
                GridRow { Text("Reveals"); Text("\(session.log.reveals)") }
                GridRow { Text("Assists"); Text("\(session.log.autoCandidates + session.log.cageHelper)") }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Techniques this puzzle needed").font(.headline)
                Text(session.puzzle.techniquesRequired.map(\.displayName).joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Done", action: onDone).buttonStyle(.borderedProminent).accessibilityIdentifier("completionDone")
        }
        .padding(28)
    }
}
