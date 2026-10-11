import SwiftUI
import SudokuCore
import SudokuGame

/// Walks through why a step works, one beat at a time, on a board (an example, or the player's own).
struct ExplainView: View {
    let board: Board
    let step: Step
    /// Applies the step to the player's board; nil for example boards.
    let onApply: (() -> Void)?

    @State private var frames: [ExplanationFrame] = []
    @State private var index = 0
    @State private var playing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if frames.isEmpty {
                ProgressView("Working it out…").frame(maxWidth: .infinity, minHeight: 300)
            } else {
                let frame = frames[index]
                BoardView(session: session, settings: GameSettings(),
                          spotlight: Set(frame.cells), marks: frame.falsehoods, pattern: frame.truths,
                          placed: frame.placements) { _ in }
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.25), value: index)
                Text("Step \(index + 1) of \(frames.count)").font(.caption).foregroundStyle(.secondary)
                Text(frame.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                    .accessibilityIdentifier("explainText")
                HStack {
                    Button("Back", systemImage: "chevron.left") { index = max(0, index - 1) }
                        .disabled(index == 0)
                    Spacer()
                    Button(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill") { playing.toggle() }
                    Spacer()
                    Button("Next", systemImage: "chevron.right") { index = min(frames.count - 1, index + 1) }
                        .disabled(index == frames.count - 1)
                        .accessibilityIdentifier("explainNext")
                }
                .labelStyle(.titleAndIcon)
                legend
                if let onApply, index == frames.count - 1 {
                    Button {
                        onApply()
                    } label: {
                        Label("Apply this step", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("applyStep")
                    Text("Applying counts as a reveal.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .navigationTitle(step.technique.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Forcing-chain traces can take a moment; build the frames off the main thread.
            let (board, step) = (board, step)
            frames = await Task.detached { StepExplainer.frames(for: step, on: board) }.value
        }
        .task(id: playing) {
            while playing && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                guard playing else { break }
                if index < frames.count - 1 { index += 1 } else { playing = false }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            Label("true", systemImage: "circle.fill").foregroundStyle(.green)
            Label("false", systemImage: "circle.fill").foregroundStyle(Theme.wrong)
        }
        .font(.caption)
    }

    /// A display-only session showing the board's digits and candidates.
    private var session: GameSession {
        let puzzle = Puzzle(id: "explain", mode: board.cages.isEmpty ? .classic : .killer, givens: board.values,
                            cages: board.cages, solution: board.values, grade: Grade(tier: step.technique.tier, score: 0),
                            techniquesRequired: [])
        return GameSession(lessonPuzzle: puzzle, notes: (0..<81).map { board.values[$0] == 0 ? board.candidates[$0] : .empty })
    }
}
