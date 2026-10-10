import SudokuCore

extension GameSession {
    /// What VoiceOver reads for a cell: position, contents, notes, and its Killer cage.
    public func spokenDescription(of cell: Int) -> String {
        var parts = ["Row \(Geometry.row(cell) + 1), column \(Geometry.col(cell) + 1)."]
        let v = entries[cell]
        if v != 0 {
            parts.append(isGiven(cell) ? "\(v), given." : "\(v).")
        } else {
            parts.append("Empty.")
            let shown = displayedNotes(cell)
            if !shown.isEmpty {
                parts.append("Candidates \(shown.digits.map(String.init).joined(separator: ", ")).")
            }
        }
        if let index = cageIndex(of: cell) {
            let cage = puzzle.cages[index]
            parts.append("Cage of \(cage.cells.count) cells, total \(cage.sum).")
        }
        return parts.joined(separator: " ")
    }
}
