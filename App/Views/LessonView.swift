import SwiftUI
import SudokuCore
import SudokuGame

/// The lesson modal: animated example, explanation, and "Show me" on the player's board.
struct LessonView: View {
    let technique: TechniqueID
    let example: LessonExample?
    let onShowMe: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var phase = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let example {
                        BoardView(session: exampleSession(example), settings: GameSettings(),
                                  spotlight: phase >= 1 ? Set(example.step.patternCells) : [],
                                  marks: phase >= 2 ? example.step.eliminations : [],
                                  pattern: phase >= 1 ? example.step.patternCandidates : [],
                                  placed: phase >= 2 ? example.step.placements : []) { _ in }
                            .frame(maxWidth: .infinity)
                            .task {
                                while !Task.isCancelled {
                                    for p in 0...2 {
                                        withAnimation { phase = p }
                                        try? await Task.sleep(for: .seconds(1.6))
                                    }
                                }
                            }
                        Text(caption).font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(LessonText.explanation(for: technique)).font(.body)
                    Button {
                        onShowMe()
                        dismiss()
                    } label: {
                        Label("Show me on my board", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("showMe")
                    Text("Show me counts as a reveal.").font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(technique.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private var caption: String {
        switch phase {
        case 0: return "The position."
        case 1: return "The pattern."
        default:
            guard let step = example?.step else { return "" }
            return step.placements.isEmpty ? "What it removes." : (step.eliminations.isEmpty ? "What it places." : "What it places and removes.")
        }
    }

    private func exampleSession(_ e: LessonExample) -> GameSession {
        let puzzle = Puzzle(id: "lesson", mode: e.cages.isEmpty ? .classic : .killer, givens: e.values, cages: e.cages,
                            solution: e.values, grade: Grade(tier: e.technique.tier, score: 0), techniquesRequired: [])
        return GameSession(lessonPuzzle: puzzle, notes: e.candidates.map { CandidateSet(raw: $0) })
    }
}
