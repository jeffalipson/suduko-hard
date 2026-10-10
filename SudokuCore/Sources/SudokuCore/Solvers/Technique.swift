/// A human solving technique. `find` returns the first instance on the board
/// that makes progress (at least one placement or elimination), or nil.
public protocol Technique: Sendable {
    var id: TechniqueID { get }
    func find(in board: Board) -> Step?
}

public enum TechniqueCatalog {
    /// Classic techniques in the order the solver tries them (easiest first).
    public static let classic: [any Technique] = [
        FullHouse(),
        NakedSingle(),
        HiddenSingle(),
        Pointing(),
        BoxLineReduction(),
        NakedSubset(size: 2),
        HiddenSubset(size: 2),
        NakedSubset(size: 3),
        HiddenSubset(size: 3),
        NakedSubset(size: 4),
        HiddenSubset(size: 4),
    ]
}
