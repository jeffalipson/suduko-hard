/// Player toggles (spec §6.3). Only highlighting is on by default.
public struct GameSettings: Codable, Equatable, Sendable {
    public var autoCandidates = false
    public var autoRemoveCandidates = false
    public var mistakeHighlighting = false
    public var cageHelper = false
    public var remainingSum = false
    public var highlightMatching = true

    public init() {}
}
