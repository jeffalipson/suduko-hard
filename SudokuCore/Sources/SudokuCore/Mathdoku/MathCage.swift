/// A Mathdoku cage's operation. − and ÷ only ever label two-cell cages; `.given` is a single cell;
/// `.hidden` shows only the target (Nightmare).
public enum MathOp: String, Codable, Sendable, CaseIterable {
    case add = "+", subtract = "-", multiply = "x", divide = "/", given = "=", hidden = "?"

    public var symbol: String {
        switch self {
        case .add: "+"
        case .subtract: "−"
        case .multiply: "×"
        case .divide: "÷"
        case .given, .hidden: ""
        }
    }
}

/// Cells whose digits must make `target` with `op`. Cells are indexes `row * n + column`.
public struct MathCage: Hashable, Codable, Sendable {
    public var cells: [Int]
    public var op: MathOp
    public var target: Int

    public init(cells: [Int], op: MathOp, target: Int) {
        self.cells = cells
        self.op = op
        self.target = target
    }

    /// The clue drawn in the cage's corner: "12×", "3−", or just the number for givens and hidden operations.
    public var label: String { "\(target)\(op.symbol)" }

    /// Whether `values` (one per cell, in `cells` order) make the target.
    public func satisfies(_ values: [Int]) -> Bool {
        Self.satisfies(op, target, values)
    }

    static func satisfies(_ op: MathOp, _ target: Int, _ values: [Int]) -> Bool {
        switch op {
        case .given: return values.count == 1 && values[0] == target
        case .add: return values.reduce(0, +) == target
        case .multiply: return values.reduce(1, *) == target
        case .subtract:
            return values.count == 2 && abs(values[0] - values[1]) == target
        case .divide:
            guard values.count == 2, let lo = values.min(), let hi = values.max(), lo > 0 else { return false }
            return hi % lo == 0 && hi / lo == target
        case .hidden:
            let ops: [MathOp] = values.count == 2 ? [.add, .subtract, .multiply, .divide] : values.count == 1 ? [.given] : [.add, .multiply]
            return ops.contains { satisfies($0, target, values) }
        }
    }

    /// Pairs of positions in `cells` that share a row or column, so must differ.
    public func conflicts(n: Int) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        for i in cells.indices {
            for j in (i + 1)..<cells.count where cells[i] / n == cells[j] / n || cells[i] % n == cells[j] % n {
                out.append((i, j))
            }
        }
        return out
    }

    /// Every assignment of digits to `cells`, drawn from each cell's candidates, that makes the target
    /// and keeps cells sharing a row or column different. Results are in `cells` order.
    public func fillings(n: Int, candidates: [CandidateSet], limit: Int = 100_000) -> [[Int]] {
        let k = cells.count
        let domains = cells.map { candidates[$0].digits.filter { $0 <= n } }
        var mustDiffer = Array(repeating: [Int](), count: k)
        for (i, j) in conflicts(n: n) { mustDiffer[j].append(i) }
        var out: [[Int]] = []
        var vals = Array(repeating: 0, count: k)
        let maxDigit = n

        func go(_ i: Int, _ sum: Int, _ product: Int) {
            if out.count >= limit { return }
            if i == k {
                if satisfies(vals) { out.append(vals) }
                return
            }
            let rest = k - i - 1
            for d in domains[i] {
                if mustDiffer[i].contains(where: { vals[$0] == d }) { continue }
                switch op {
                case .add:
                    if sum + d + rest > target || sum + d + rest * maxDigit < target { continue }
                case .multiply:
                    if target % (product * d) != 0 { continue }
                default: break
                }
                vals[i] = d
                go(i + 1, sum + d, product * d)
            }
            vals[i] = 0
        }
        go(0, 0, 1)
        return out
    }

    /// Digits that can appear somewhere in this cage from its arithmetic alone (every cell open):
    /// what Auto Pencil keeps. Never uses the answer.
    public func possibleDigits(n: Int) -> CandidateSet {
        let open = Array(repeating: CandidateSet.range(1...n), count: (cells.max() ?? 0) + 1)
        return fillings(n: n, candidates: open).reduce(.empty) { $0.union(CandidateSet($1)) }
    }
}

extension MathCage {
    /// The prime factorization of `n`, smallest prime first (empty for 1).
    public static func primeFactors(_ n: Int) -> [(prime: Int, power: Int)] {
        var out: [(prime: Int, power: Int)] = []
        var n = n, p = 2
        while n > 1 && p * p <= n {
            var k = 0
            while n % p == 0 { n /= p; k += 1 }
            if k > 0 { out.append((p, k)) }
            p += 1
        }
        if n > 1 { out.append((n, 1)) }
        return out
    }

    /// "2³ · 3²" for 72; a prime or 1 is just itself.
    public static func factorText(_ n: Int) -> String {
        let factors = primeFactors(n)
        guard !factors.isEmpty else { return "\(n)" }
        let superscripts: [Character] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
        return factors.map { f in
            f.power == 1 ? "\(f.prime)" : "\(f.prime)" + String(String(f.power).map { superscripts[Int(String($0))!] })
        }.joined(separator: " · ")
    }

    /// Whether a long press shows this cage's prime factors: × cages, and every cage when operations
    /// are hidden (so showing or not doesn't give the operation away).
    public var showsFactors: Bool { op == .multiply || op == .hidden }
}
