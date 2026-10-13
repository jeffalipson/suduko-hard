import SwiftUI

extension View {
    /// On iPad-sized windows, raise text-style fonts to at least xxxLarge (about 1.3–1.4×)
    /// while still honouring a larger accessibility size the player has chosen.
    func regularWidthTypeBoost(_ on: Bool) -> some View {
        transformEnvironment(\.dynamicTypeSize) { size in
            if on { size = max(size, .xxxLarge) }
        }
    }
}
