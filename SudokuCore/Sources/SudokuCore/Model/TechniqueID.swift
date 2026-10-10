/// Every technique the engine knows. Later plans append cases.
public enum TechniqueID: String, Codable, CaseIterable, Sendable {
    case fullHouse, nakedSingle, hiddenSingle
    case pointing, boxLineReduction, nakedPair, hiddenPair
    case nakedTriple, hiddenTriple, nakedQuad, hiddenQuad
    case xWing, uniqueRectangle1, skyscraper, twoStringKite, xyWing, swordfish
    case emptyRectangle, xyzWing, wWing, uniqueRectangle2, uniqueRectangle4, uniqueRectangle3
    case finnedXWing, simpleColoring, finnedSwordfish, jellyfish
    case xCycle, xyChain, sueDeCoq, alsXZ, aic
    case cellForcingChain, unitForcingChain, digitForcingChain, nestedForcingChain
    case cageCompletion, uniqueCageCombination, cageCombination
    case innieOutie1, cageLockedDigit, innieOutie2, innieOutieMulti

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
        case .xCycle, .xyChain, .sueDeCoq, .alsXZ, .aic:
            return .diabolical
        case .cellForcingChain, .unitForcingChain, .digitForcingChain, .nestedForcingChain:
            return .nightmare
        case .cageCompletion, .uniqueCageCombination:
            return .easy
        case .cageCombination:
            return .medium
        case .innieOutie1:
            return .hard
        case .cageLockedDigit, .innieOutie2:
            return .expert
        case .innieOutieMulti:
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
        case .xCycle: return 250
        case .xyChain: return 260
        case .sueDeCoq: return 270
        case .alsXZ: return 280
        case .aic: return 300
        case .cellForcingChain: return 400
        case .unitForcingChain: return 420
        case .digitForcingChain: return 450
        case .nestedForcingChain: return 500
        case .cageCompletion: return 1
        case .uniqueCageCombination: return 3
        case .cageCombination: return 12
        case .innieOutie1: return 40
        case .cageLockedDigit: return 102
        case .innieOutie2: return 105
        case .innieOutieMulti: return 155
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
        case .xCycle: return "X-Cycle"
        case .xyChain: return "XY-Chain"
        case .sueDeCoq: return "Sue de Coq"
        case .alsXZ: return "ALS-XZ"
        case .aic: return "Alternating Inference Chain"
        case .cellForcingChain: return "Cell Forcing Chain"
        case .unitForcingChain: return "Unit Forcing Chain"
        case .digitForcingChain: return "Digit Forcing Chain"
        case .nestedForcingChain: return "Nested Forcing Chain"
        case .cageCompletion: return "Cage Completion"
        case .uniqueCageCombination: return "Unique Cage Combination"
        case .cageCombination: return "Cage Combinations"
        case .innieOutie1: return "45 Rule (One House)"
        case .cageLockedDigit: return "Cage-Locked Digit"
        case .innieOutie2: return "45 Rule (Two Houses)"
        case .innieOutieMulti: return "45 Rule (Three+ Houses)"
        }
    }

    /// Techniques that only apply to Killer puzzles.
    public var isKillerOnly: Bool {
        switch self {
        case .cageCompletion, .uniqueCageCombination, .cageCombination,
             .innieOutie1, .cageLockedDigit, .innieOutie2, .innieOutieMulti:
            return true
        default:
            return false
        }
    }
}
