import SwiftUI
import SudokuGame

struct CageHelperView: View {
    let session: GameSession

    var body: some View {
        NavigationStack {
            Group {
                if let cell = session.selected, let index = session.cageIndex(of: cell) {
                    let cage = session.puzzle.cages[index]
                    List {
                        Section("\(cage.sum) in \(cage.cells.count) cells") {
                            ForEach(session.combinations(ofCage: index), id: \.digits) { combo in
                                Text(combo.digits.map(String.init).joined(separator: " + "))
                                    .strikethrough(!combo.possible)
                                    .foregroundStyle(combo.possible ? .primary : .secondary)
                            }
                        }
                    }
                } else {
                    Text("Select a cell in a cage.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cage Combinations")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
