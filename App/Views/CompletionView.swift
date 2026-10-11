import SwiftUI
import SudokuCore
import SudokuGame

struct CompletionView: View {
    let session: GameSession
    let mistakesCounted: Bool
    let onDone: () -> Void
    @State private var counts: [(technique: TechniqueID, count: Int)]?

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
                Text("What it took").font(.headline)
                if let counts {
                    Text(counts.isEmpty ? "Only singles." : counts.map { SolveSummary.phrase($0.technique, $0.count) }.joined(separator: ", ") + ", plus singles.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if let counts {
                    ShareLink(item: SolveSummary.shareText(session: session, counts: counts)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("shareSolve")
                }
                Button("Done", action: onDone).buttonStyle(.borderedProminent).accessibilityIdentifier("completionDone")
            }
        }
        .padding(28)
        .task {
            let puzzle = session.puzzle
            counts = await Task.detached { SolveSummary.techniqueCounts(puzzle) }.value
        }
    }
}
