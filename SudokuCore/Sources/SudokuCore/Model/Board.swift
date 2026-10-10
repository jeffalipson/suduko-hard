public struct Board: Hashable, Sendable {
    /// 81 digits, 0 = empty.
    public private(set) var values: [Int]
    public let givens: [Bool]
    public var candidates: [CandidateSet]
    public let cages: [Cage]
    /// Index into `cages` for each cell, or -1 when the cell has no cage.
    public let cageOf: [Int]

    /// Builds a board from 81 values (0 = empty); candidates are filled from the placed digits.
    public init(values: [Int], cages: [Cage] = []) {
        precondition(values.count == 81, "A board needs 81 values")
        self.values = values
        self.givens = values.map { $0 != 0 }
        // Malformed cages (empty, out-of-range or repeated cells, or overlapping an earlier cage) are dropped.
        var cageOf = [Int](repeating: -1, count: 81)
        var kept: [Cage] = []
        for cage in cages {
            guard !cage.cells.isEmpty, Set(cage.cells).count == cage.cells.count,
                  cage.cells.allSatisfy({ (0..<81).contains($0) && cageOf[$0] == -1 }) else { continue }
            for c in cage.cells { cageOf[c] = kept.count }
            kept.append(cage)
        }
        self.cages = kept
        self.cageOf = cageOf
        self.candidates = Array(repeating: .empty, count: 81)
        for c in 0..<81 where values[c] == 0 {
            var set = CandidateSet.all
            for p in Geometry.peers[c] where values[p] != 0 { set.remove(values[p]) }
            if cageOf[c] >= 0 {
                for p in kept[cageOf[c]].cells where values[p] != 0 { set.remove(values[p]) }
            }
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
            } else if let ascii = ch.asciiValue, (49...57).contains(ascii) {   // "1"..."9" only
                out.append(Int(ascii) - 48)
            } else {
                return nil
            }
        }
        return out
    }

    public var string: String { values.map { $0 == 0 ? "." : String($0) }.joined() }

    public var isSolved: Bool { !values.contains(0) }

    /// Other cells in `cell`'s cage.
    public func cageMates(of cell: Int) -> [Int] {
        cageOf[cell] < 0 ? [] : cages[cageOf[cell]].cells.filter { $0 != cell }
    }

    /// Places a digit and removes it from the candidates of every peer.
    public mutating func place(_ digit: Int, at cell: Int) {
        values[cell] = digit
        candidates[cell] = .empty
        for p in Geometry.peers[cell] { candidates[p].remove(digit) }
        for p in cageMates(of: cell) { candidates[p].remove(digit) }
    }

    public mutating func eliminate(_ digit: Int, at cell: Int) {
        candidates[cell].remove(digit)
    }

    public mutating func apply(_ step: Step) {
        for p in step.placements { place(p.digit, at: p.cell) }
        for e in step.eliminations { eliminate(e.digit, at: e.cell) }
    }
}
