/// Every technique the engine knows. Later plans append cases.
public enum TechniqueID: String, Codable, CaseIterable, Sendable {
    case fullHouse, nakedSingle, hiddenSingle
    case pointing, boxLineReduction, nakedPair, hiddenPair
    case nakedTriple, hiddenTriple, nakedQuad, hiddenQuad

    public var tier: Tier {
        switch self {
        case .fullHouse, .nakedSingle, .hiddenSingle:
            return .easy
        case .pointing, .boxLineReduction, .nakedPair, .hiddenPair:
            return .medium
        case .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad:
            return .hard
        }
    }

    /// Contribution of one use of this technique to a puzzle's score.
    public var weight: Int {
        switch self {
        case .fullHouse: return 1
        case .nakedSingle: return 2
        case .hiddenSingle: return 2
        case .pointing: return 10
        case .boxLineReduction: return 10
        case .nakedPair: return 15
        case .hiddenPair: return 20
        case .nakedTriple: return 30
        case .hiddenTriple: return 35
        case .nakedQuad: return 50
        case .hiddenQuad: return 60
        }
    }

    public var displayName: String {
        switch self {
        case .fullHouse: return "Full House"
        case .nakedSingle: return "Naked Single"
        case .hiddenSingle: return "Hidden Single"
        case .pointing: return "Pointing"
        case .boxLineReduction: return "Box/Line Reduction"
        case .nakedPair: return "Naked Pair"
        case .hiddenPair: return "Hidden Pair"
        case .nakedTriple: return "Naked Triple"
        case .hiddenTriple: return "Hidden Triple"
        case .nakedQuad: return "Naked Quad"
        case .hiddenQuad: return "Hidden Quad"
        }
    }
}
