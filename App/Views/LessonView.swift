import SwiftUI
import SudokuCore
import SudokuGame

/// The lesson modal: animated example, explanation, step-by-step walk-throughs on the example and
/// on the player's own board (which ends by applying the step).
struct LessonView: View {
    let technique: TechniqueID
    let example: LessonExample?
    /// The player's board and the hint step, when opened from a hint.
    var yours: (board: Board, step: Step)? = nil
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
                                  secondary: phase >= 1 ? example.step.groups.dropFirst(example.step.technique == .simpleColoring ? 1 : 0).flatMap { $0 } : [],
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
                    if let example {
                        NavigationLink {
                            ExplainView(board: example.board, step: example.step, onApply: nil)
                        } label: {
                            Label("Explain step by step", systemImage: "list.number").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("explainExample")
                    }
                    if let yours {
                        NavigationLink {
                            ExplainView(board: yours.board, step: yours.step) {
                                onShowMe()
                                dismiss()
                            }
                        } label: {
                            Label("Explain on my board", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("showMe")
                        Text("Walks through the step on your board, then lets you apply it (counts as a reveal).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
