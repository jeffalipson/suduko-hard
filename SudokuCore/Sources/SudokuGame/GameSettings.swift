/// Player toggles (spec §6.3). Only highlighting is on by default.
public struct GameSettings: Codable, Equatable, Sendable {
    public var autoCandidates = false
    public var autoRemoveCandidates = false
    public var mistakeHighlighting = false
    public var cageHelper = false
    public var remainingSum = false
    public var highlightMatching = true

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case autoCandidates, autoRemoveCandidates, mistakeHighlighting, cageHelper, remainingSum, highlightMatching
    }

    /// Missing keys (older or newer save files) fall back to defaults instead of failing.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GameSettings()
        autoCandidates = try c.decodeIfPresent(Bool.self, forKey: .autoCandidates) ?? d.autoCandidates
        autoRemoveCandidates = try c.decodeIfPresent(Bool.self, forKey: .autoRemoveCandidates) ?? d.autoRemoveCandidates
        mistakeHighlighting = try c.decodeIfPresent(Bool.self, forKey: .mistakeHighlighting) ?? d.mistakeHighlighting
        cageHelper = try c.decodeIfPresent(Bool.self, forKey: .cageHelper) ?? d.cageHelper
        remainingSum = try c.decodeIfPresent(Bool.self, forKey: .remainingSum) ?? d.remainingSum
        highlightMatching = try c.decodeIfPresent(Bool.self, forKey: .highlightMatching) ?? d.highlightMatching
    }
}
