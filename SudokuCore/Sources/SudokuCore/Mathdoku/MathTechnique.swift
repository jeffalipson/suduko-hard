/// A Mathdoku solving technique, by difficulty level (1 easiest).
public enum MathTechnique: String, Codable, Sendable, CaseIterable, Comparable {
    case nakedSingle, hiddenSingle, cageArithmetic
    case cageLineForced, nakedPair, hiddenPair, nakedTriple, hiddenTriple
    case xWing, swordfish, cagePair
    case contradiction

    /// 1: singles and cage arithmetic; 2: line reasoning; 3: patterns across lines and cages;
    /// 4: testing a candidate until it breaks.
    public var level: Int {
        switch self {
        case .nakedSingle, .hiddenSingle, .cageArithmetic: 1
        case .cageLineForced, .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple: 2
        case .xWing, .swordfish, .cagePair: 3
        case .contradiction: 4
        }
    }

    public var name: String {
        switch self {
        case .nakedSingle: "Naked Single"
        case .hiddenSingle: "Hidden Single"
        case .cageArithmetic: "Cage Arithmetic"
        case .cageLineForced: "Cage Forces a Digit"
        case .nakedPair: "Naked Pair"
        case .hiddenPair: "Hidden Pair"
        case .nakedTriple: "Naked Triple"
        case .hiddenTriple: "Hidden Triple"
        case .xWing: "X-Wing"
        case .swordfish: "Swordfish"
        case .cagePair: "Two-Cage Combination"
        case .contradiction: "Contradiction"
        }
    }

    public static func < (a: MathTechnique, b: MathTechnique) -> Bool {
        (a.level, allCases.firstIndex(of: a)!) < (b.level, allCases.firstIndex(of: b)!)
    }
}
