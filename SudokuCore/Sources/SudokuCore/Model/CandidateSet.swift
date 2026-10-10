/// A set of Sudoku digits 1...9 stored as a bitmask (bit d = digit d).
public struct CandidateSet: Hashable, Sendable, CustomStringConvertible {
    public var raw: UInt16

    static let allMask: UInt16 = 0b11_1111_1110

    public static let all = CandidateSet(raw: allMask)
    public static let empty = CandidateSet(raw: 0)

    public init(raw: UInt16 = 0) {
        self.raw = raw & CandidateSet.allMask
    }

    public init<S: Sequence>(_ digits: S) where S.Element == Int {
        self.raw = 0
        for d in digits { insert(d) }
    }

    public var count: Int { raw.nonzeroBitCount }
    public var isEmpty: Bool { raw == 0 }
    public var digits: [Int] { (1...9).filter { contains($0) } }

    /// The only digit, when exactly one is present.
    public var single: Int? { count == 1 ? raw.trailingZeroBitCount : nil }

    public func contains(_ digit: Int) -> Bool { raw & (1 << digit) != 0 }
    public mutating func insert(_ digit: Int) { raw |= 1 << digit }
    public mutating func remove(_ digit: Int) { raw &= ~(1 << digit) }

    public func union(_ other: CandidateSet) -> CandidateSet { CandidateSet(raw: raw | other.raw) }
    public func intersection(_ other: CandidateSet) -> CandidateSet { CandidateSet(raw: raw & other.raw) }
    public func subtracting(_ other: CandidateSet) -> CandidateSet { CandidateSet(raw: raw & ~other.raw) }

    public var description: String { digits.map(String.init).joined() }
}

/// Encodes as a bare number (compact for saved games); also reads the older {"raw": n} form.
extension CandidateSet: Codable {
    private enum Keys: String, CodingKey { case raw }

    public init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let raw = try? single.decode(UInt16.self) {
            self.init(raw: raw)
        } else {
            self.init(raw: try decoder.container(keyedBy: Keys.self).decode(UInt16.self, forKey: .raw))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }
}
