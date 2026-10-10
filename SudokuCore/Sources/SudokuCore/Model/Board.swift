public struct Board: Hashable, Sendable {
    /// 81 digits, 0 = empty.
    public private(set) var values: [Int]
    public let givens: [Bool]
    public var candidates: [CandidateSet]
    public let cages: [Cage]

    /// Builds a board from 81 values (0 = empty); candidates are filled from the placed digits.
    public init(values: [Int], cages: [Cage] = []) {
        precondition(values.count == 81, "A board needs 81 values")
        self.values = values
        self.givens = values.map { $0 != 0 }
        self.cages = cages
        self.candidates = Array(repeating: .empty, count: 81)
        for c in 0..<81 where values[c] == 0 {
            var set = CandidateSet.all
            for p in Geometry.peers[c] where values[p] != 0 { set.remove(values[p]) }
            candidates[c] = set
        }
    }

    public init?(string: String, cages: [Cage] = []) {
        guard let values = Board.parse(string) else { return nil }
        self.init(values: values, cages: cages)
    }

    /// Parses exactly 81 characters: digits 1–9, with '0' or '.' for empty.
    public static func parse(_ string: String) -> [Int]? {
        let chars = Array(string)
        guard chars.count == 81 else { return nil }
        var out: [Int] = []
        out.reserveCapacity(81)
        for ch in chars {
            if ch == "." || ch == "0" {
                out.append(0)
            } else if let d = ch.wholeNumberValue, (1...9).contains(d) {
                out.append(d)
            } else {
                return nil
            }
        }
        return out
    }

    public var string: String { values.map { $0 == 0 ? "." : String($0) }.joined() }

    public var isSolved: Bool { !values.contains(0) }

    /// Places a digit and removes it from the candidates of every peer.
    public mutating func place(_ digit: Int, at cell: Int) {
        values[cell] = digit
        candidates[cell] = .empty
        for p in Geometry.peers[cell] { candidates[p].remove(digit) }
    }

    public mutating func eliminate(_ digit: Int, at cell: Int) {
        candidates[cell].remove(digit)
    }

    public mutating func apply(_ step: Step) {
        for p in step.placements { place(p.digit, at: p.cell) }
        for e in step.eliminations { eliminate(e.digit, at: e.cell) }
    }
}
