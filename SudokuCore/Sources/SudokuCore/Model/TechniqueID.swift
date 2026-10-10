/// Every technique the engine knows. Later plans append cases.
public enum TechniqueID: String, Codable, CaseIterable, Sendable {
    case fullHouse, nakedSingle, hiddenSingle
    case pointing, boxLineReduction, nakedPair, hiddenPair
    case nakedTriple, hiddenTriple, nakedQuad, hiddenQuad
    case xWing, uniqueRectangle1, skyscraper, twoStringKite, xyWing, swordfish
    case emptyRectangle, xyzWing, wWing, uniqueRectangle2, uniqueRectangle4, uniqueRectangle3
    case finnedXWing, simpleColoring, finnedSwordfish, jellyfish

    public var tier: Tier {
        switch self {
        case .fullHouse, .nakedSingle, .hiddenSingle:
            return .easy
        case .pointing, .boxLineReduction, .nakedPair, .hiddenPair:
            return .medium
        case .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad:
            return .hard
        case .xWing, .uniqueRectangle1, .skyscraper, .twoStringKite, .xyWing, .swordfish:
            return .expert
        case .emptyRectangle, .xyzWing, .wWing, .uniqueRectangle2, .uniqueRectangle4, .uniqueRectangle3,
             .finnedXWing, .simpleColoring, .finnedSwordfish, .jellyfish:
            return .fiendish
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
        case .xWing: return 100
        case .uniqueRectangle1: return 100
        case .skyscraper: return 110
        case .twoStringKite: return 110
        case .xyWing: return 120
        case .swordfish: return 140
        case .emptyRectangle: return 150
        case .xyzWing: return 160
        case .wWing: return 170
        case .uniqueRectangle2: return 170
        case .uniqueRectangle4: return 170
        case .uniqueRectangle3: return 180
        case .finnedXWing: return 180
        case .simpleColoring: return 200
        case .finnedSwordfish: return 210
        case .jellyfish: return 220
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
        case .xWing: return "X-Wing"
        case .uniqueRectangle1: return "Unique Rectangle (Type 1)"
        case .skyscraper: return "Skyscraper"
        case .twoStringKite: return "2-String Kite"
        case .xyWing: return "XY-Wing"
        case .swordfish: return "Swordfish"
        case .emptyRectangle: return "Empty Rectangle"
        case .xyzWing: return "XYZ-Wing"
        case .wWing: return "W-Wing"
        case .uniqueRectangle2: return "Unique Rectangle (Type 2)"
        case .uniqueRectangle4: return "Unique Rectangle (Type 4)"
        case .uniqueRectangle3: return "Unique Rectangle (Type 3)"
        case .finnedXWing: return "Finned X-Wing"
        case .simpleColoring: return "Simple Coloring"
        case .finnedSwordfish: return "Finned Swordfish"
        case .jellyfish: return "Jellyfish"
        }
    }
}
