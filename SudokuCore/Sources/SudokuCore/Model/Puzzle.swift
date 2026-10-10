public struct Grade: Codable, Hashable, Sendable {
    public var tier: Tier
    public var score: Int

    public init(tier: Tier, score: Int) {
        self.tier = tier
        self.score = score
    }
}

public struct Puzzle: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var mode: Mode
    public var givens: [Int]
    public var cages: [Cage]
    public var solution: [Int]
    public var grade: Grade
    public var techniquesRequired: [TechniqueID]

    public init(
        id: String,
        mode: Mode,
        givens: [Int],
        cages: [Cage],
        solution: [Int],
        grade: Grade,
        techniquesRequired: [TechniqueID]
    ) {
        self.id = id
        self.mode = mode
        self.givens = givens
        self.cages = cages
        self.solution = solution
        self.grade = grade
        self.techniquesRequired = techniquesRequired
    }

    enum CodingKeys: String, CodingKey {
        case id, mode, givens, cages, solution, grade, techniquesRequired
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        mode = try c.decode(Mode.self, forKey: .mode)
        guard let givens = Board.parse(try c.decode(String.self, forKey: .givens)) else {
            throw DecodingError.dataCorruptedError(forKey: .givens, in: c, debugDescription: "Expected 81 digits")
        }
        guard let solution = Board.parse(try c.decode(String.self, forKey: .solution)) else {
            throw DecodingError.dataCorruptedError(forKey: .solution, in: c, debugDescription: "Expected 81 digits")
        }
        self.givens = givens
        self.solution = solution
        cages = try c.decodeIfPresent([Cage].self, forKey: .cages) ?? []
        grade = try c.decode(Grade.self, forKey: .grade)
        techniquesRequired = try c.decode([TechniqueID].self, forKey: .techniquesRequired)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(mode, forKey: .mode)
        try c.encode(givens.map(String.init).joined(), forKey: .givens)
        try c.encode(solution.map(String.init).joined(), forKey: .solution)
        if !cages.isEmpty { try c.encode(cages, forKey: .cages) }
        try c.encode(grade, forKey: .grade)
        try c.encode(techniquesRequired, forKey: .techniquesRequired)
    }
}
