import SwiftUI
import SudokuCore
import SudokuGame

/// Escalating hint: technique → digit → place → Show where (spotlight) → Lesson.
struct HintBar: View {
    let diagnosis: HintDiagnosis
    /// 1...nudgeLevels are nudges; above that the spotlight is on.
    let level: Int
    let nudgeLevels: Int
    let onMore: () -> Void
    let onSpotlight: () -> Void
    let onLesson: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text(message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hintMessage")
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose).labelStyle(.iconOnly)
            }
            if case .step = diagnosis {
                HStack {
                    if level < nudgeLevels {
                        Button("More specific", action: onMore).buttonStyle(.bordered).accessibilityIdentifier("hintMore")
                    } else if level == nudgeLevels {
                        Button("Show where", action: onSpotlight).buttonStyle(.bordered).accessibilityIdentifier("hintSpotlight")
                    }
                    Button("Lesson", action: onLesson).buttonStyle(.borderedProminent).accessibilityIdentifier("hintLesson")
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hintBar")
    }

    private var message: String {
        if case .step(let step) = diagnosis { return HintText.nudge(step, level: min(level, nudgeLevels)) }
        return HintText.message(diagnosis)
    }
}
