import SwiftUI
import SudokuCore
import SudokuGame

/// Escalating hint: message → Show where (spotlight) → Lesson.
struct HintBar: View {
    let diagnosis: HintDiagnosis
    let level: Int
    let onSpotlight: () -> Void
    let onLesson: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text(HintText.message(diagnosis)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose).labelStyle(.iconOnly)
            }
            if case .step = diagnosis {
                HStack {
                    if level < 2 { Button("Show where", action: onSpotlight).buttonStyle(.bordered).accessibilityIdentifier("hintSpotlight") }
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
