import SwiftUI
import SudokuCore
import SudokuGame

/// Escalating hint: technique → digit → place → Show where (spotlight) → Lesson.
struct HintBar: View {
    let message: String
    /// The hint is pointing at a mistake (shows More specific until the exact cell).
    let isMistake: Bool
    /// The hint is a solving step (shows More specific / Show where, and Lesson).
    let isStep: Bool
    let offersAutoPencil: Bool
    /// A one-tap fix for a pointed-out mistake ("Erase it", "Put it back").
    var fixLabel: String? = nil
    /// 1...nudgeLevels are nudges; above that the spotlight is on.
    let level: Int
    let nudgeLevels: Int
    let onMore: () -> Void
    let onSpotlight: () -> Void
    let onLesson: () -> Void
    let onAutoCandidates: () -> Void
    let onClose: () -> Void
    var onFix: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text(message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hintMessage")
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose).labelStyle(.iconOnly).accessibilityIdentifier("hintClose")
            }
            if isMistake {
                HStack {
                    if level < nudgeLevels {
                        Button(nudgeLevels == 4 && level == 3 ? "Which digit?" : "More specific", action: onMore)
                            .buttonStyle(.bordered).accessibilityIdentifier("hintMore")
                    }
                    if let fixLabel {
                        Button(fixLabel, action: onFix).buttonStyle(.borderedProminent).accessibilityIdentifier("hintFix")
                    }
                }
            }
            if offersAutoPencil {
                Button("Turn on Auto Pencil", action: onAutoCandidates)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("hintAutoCandidates")
            }
            if isStep {
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

}

extension HintBar {
    /// A Sudoku hint.
    init(diagnosis: HintDiagnosis, level: Int, nudgeLevels: Int, cages: [Cage], answer: Int?, onMore: @escaping () -> Void,
         onSpotlight: @escaping () -> Void, onLesson: @escaping () -> Void, onAutoCandidates: @escaping () -> Void,
         onClose: @escaping () -> Void, onFix: @escaping () -> Void) {
        let isStep: Bool
        if case .step = diagnosis { isStep = true } else { isStep = false }
        self.init(message: HintText.message(diagnosis, level: level, cages: cages, answer: answer), isMistake: diagnosis.isMistake,
                  isStep: isStep, offersAutoPencil: HintText.offersAutoCandidates(diagnosis),
                  fixLabel: HintText.fixLabel(diagnosis, level: level), level: level, nudgeLevels: nudgeLevels,
                  onMore: onMore, onSpotlight: onSpotlight, onLesson: onLesson, onAutoCandidates: onAutoCandidates,
                  onClose: onClose, onFix: onFix)
    }
}
