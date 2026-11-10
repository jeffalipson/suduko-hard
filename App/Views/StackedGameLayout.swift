import SwiftUI

/// Board above the controls, with the hint floating over the layout instead of taking space in it, so
/// opening, escalating or closing a hint never resizes the board or moves a key. The hint sits in the
/// free space under the tools when it fits there; on short screens it covers the input switch and
/// keypad instead, leaving the board (where the spotlight draws) and the tools row visible.
struct StackedGameLayout<Board: View, Controls: View, Hint: View>: View {
    let regular: Bool
    @ViewBuilder let board: Board
    @ViewBuilder let controls: Controls
    @ViewBuilder let hint: Hint

    @State private var controlsFrame: CGRect = .zero
    @State private var hintHeight: CGFloat = 0
    private static var space: String { "stackedGame" }

    var body: some View {
        VStack(spacing: 16) {
            board.padding(.horizontal, 8)
            controls
                .padding(.horizontal, 12)
                .frame(maxWidth: regular ? 560 : .infinity)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { controlsFrame = $0 }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .coordinateSpace(.named(Self.space))
        .overlay(alignment: .top) {
            GeometryReader { geo in
                // The overlay reaches into the bottom safe area: only the hint's padded edge sits behind
                // the home indicator, never its text or buttons.
                let below = controlsFrame.maxY + 8
                let fitsBelow = below + hintHeight <= geo.size.height
                hint
                    .padding(.horizontal, 12)
                    .frame(maxWidth: regular ? 560 : .infinity)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hintHeight = $0 }
                    .frame(maxWidth: .infinity)
                    .offset(y: fitsBelow ? below : controlsFrame.minY)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
