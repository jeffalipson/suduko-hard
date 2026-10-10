public struct CellDigit: Hashable, Sendable, Codable {
    public let cell: Int
    public let digit: Int

    public init(cell: Int, digit: Int) {
        self.cell = cell
        self.digit = digit
    }
}

/// One logical deduction. Drives grading, hints, Spotlight and "Show me".
public struct Step: Hashable, Sendable, Codable {
    public let technique: TechniqueID
    /// Cells forming the pattern (highlighted by Spotlight).
    public let patternCells: [Int]
    /// Candidates forming the pattern.
    public let patternCandidates: [CellDigit]
    public let placements: [CellDigit]
    public let eliminations: [CellDigit]
    /// Houses the pattern lives in, used for Nudge text ("in row 4").
    public let regions: [Region]
    /// Digits the pattern is about.
    public let digits: [Int]
    /// Secondary highlights for hints: colour groups, fins, subset cells.
    public let groups: [[CellDigit]]

    public init(
        technique: TechniqueID,
        patternCells: [Int] = [],
        patternCandidates: [CellDigit] = [],
        placements: [CellDigit] = [],
        eliminations: [CellDigit] = [],
        regions: [Region] = [],
        digits: [Int] = [],
        groups: [[CellDigit]] = []
    ) {
        self.technique = technique
        self.patternCells = patternCells
        self.patternCandidates = patternCandidates
        self.placements = placements
        self.eliminations = eliminations
        self.regions = regions
        self.digits = digits
        self.groups = groups
    }
}
