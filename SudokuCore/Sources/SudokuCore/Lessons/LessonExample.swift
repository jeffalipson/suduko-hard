/// A board state where a technique applies, used as the lesson's demo.
public struct LessonExample: Codable, Equatable, Sendable {
    public let technique: TechniqueID
    public let values: [Int]
    public let candidates: [UInt16]
    public let cages: [Cage]
    public let step: Step

    public init(technique: TechniqueID, board: Board, step: Step) {
        self.technique = technique
        self.values = board.values
        self.candidates = board.candidates.map(\.raw)
        self.cages = board.cages
        self.step = step
    }

    public var board: Board {
        var b = Board(values: values, cages: cages)
        for c in 0..<81 { b.candidates[c] = CandidateSet(raw: candidates[c]) }
        return b
    }
}
