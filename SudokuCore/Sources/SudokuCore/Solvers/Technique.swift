/// A human solving technique. `find` returns the first instance on the board
/// that makes progress (at least one placement or elimination), or nil.
public protocol Technique: Sendable {
    var id: TechniqueID { get }
    func find(in board: Board) -> Step?
}

public enum TechniqueCatalog {
    /// Classic techniques in the order the solver tries them (easiest first, then by weight).
    public static let classic: [any Technique] = [
        // Easy
        FullHouse(),
        NakedSingle(),
        HiddenSingle(),
        // Medium
        Pointing(),
        BoxLineReduction(),
        NakedSubset(size: 2),
        HiddenSubset(size: 2),
        // Hard
        NakedSubset(size: 3),
        HiddenSubset(size: 3),
        NakedSubset(size: 4),
        HiddenSubset(size: 4),
        // Expert
        BasicFish(size: 2),
        UniqueRectangle(type: 1),
        Skyscraper(),
        TwoStringKite(),
        XYWing(),
        BasicFish(size: 3),
        // Fiendish
        EmptyRectangle(),
        XYZWing(),
        WWing(),
        UniqueRectangle(type: 2),
        UniqueRectangle(type: 4),
        UniqueRectangle(type: 3),
        FinnedFish(size: 2),
        SimpleColoring(),
        FinnedFish(size: 3),
        BasicFish(size: 4),
        // Diabolical
        AlternatingChain.xCycle,
        AlternatingChain.xyChain,
        SueDeCoq(),
        ALSXZ(),
        AlternatingChain.aic,
        // Nightmare
        ForcingChain.cell,
        ForcingChain.unit,
        ForcingChain.digit,
        ForcingChain.nested,
    ]
}
