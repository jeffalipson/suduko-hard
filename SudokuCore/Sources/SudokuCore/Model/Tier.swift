public enum Tier: Int, Codable, CaseIterable, Comparable, Sendable {
    case easy, medium, hard, expert, fiendish, diabolical, nightmare

    public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

    public var name: String { String(describing: self) }

    /// Case-insensitive lookup, e.g. "Nightmare" → `.nightmare`.
    public init?(name: String) {
        guard let tier = Tier.allCases.first(where: { $0.name == name.lowercased() }) else { return nil }
        self = tier
    }
}

public enum Mode: String, Codable, CaseIterable, Sendable {
    case classic, killer
}
