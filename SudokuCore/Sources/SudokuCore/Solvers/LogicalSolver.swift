public struct SolveResult: Sendable {
    public let board: Board
    public let steps: [Step]
    public var solved: Bool { board.isSolved }
}

/// Solves like a human: always applies the easiest technique that makes progress.
public struct LogicalSolver: Sendable {
    public let techniques: [any Technique]

    public init(techniques: [any Technique]) {
        self.techniques = techniques
    }

    public static let classic = LogicalSolver(techniques: TechniqueCatalog.classic)

    /// The hardest tier this solver can grade.
    public var maxTier: Tier { techniques.map { $0.id.tier }.max() ?? .easy }

    public func nextStep(on board: Board) -> Step? {
        for technique in techniques {
            if let step = technique.find(in: board) { return step }
        }
        return nil
    }

    /// Steps until solved, stuck, or `maxSteps` (a guard against malformed boards).
    public func solve(_ start: Board, maxSteps: Int = 1000) -> SolveResult {
        var board = start
        var steps: [Step] = []
        while !board.isSolved, steps.count < maxSteps, let step = nextStep(on: board) {
            board.apply(step)
            steps.append(step)
        }
        return SolveResult(board: board, steps: steps)
    }
}
