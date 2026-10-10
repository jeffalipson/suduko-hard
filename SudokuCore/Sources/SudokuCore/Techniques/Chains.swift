/// Which links a chain search may use.
enum ChainKind: Sendable {
    /// One digit; strong links are conjugate pairs.
    case xCycle
    /// Strong links inside bivalue cells; weak links between cells on the same digit.
    case xyChain
    /// Any strong and weak links.
    case aic
}

/// Candidates as nodes (id = cell * 9 + digit - 1) joined by strong links (at least one true)
/// and weak links (not both true).
struct ChainGraph {
    let board: Board
    let present: [Bool]
    let strong: [[Int]]
    let weak: [[Int]]

    static func id(_ cell: Int, _ digit: Int) -> Int { cell * 9 + digit - 1 }
    static func node(_ id: Int) -> CellDigit { CellDigit(cell: id / 9, digit: id % 9 + 1) }

    init(board: Board, kind: ChainKind) {
        self.board = board
        var present = [Bool](repeating: false, count: 729)
        for c in 0..<81 where board.values[c] == 0 {
            for d in board.candidates[c].digits { present[ChainGraph.id(c, d)] = true }
        }
        var strong = [[Int]](repeating: [], count: 729)
        var weak = [[Int]](repeating: [], count: 729)

        func link(_ a: Int, _ b: Int) {
            if !strong[a].contains(b) { strong[a].append(b) }
            if !strong[b].contains(a) { strong[b].append(a) }
        }
        if kind != .xyChain {
            for d in 1...9 {
                for pair in board.conjugatePairs(of: d) { link(ChainGraph.id(pair.a, d), ChainGraph.id(pair.b, d)) }
            }
        }
        if kind != .xCycle {
            for c in 0..<81 where board.values[c] == 0 && board.candidates[c].count == 2 {
                let ds = board.candidates[c].digits
                link(ChainGraph.id(c, ds[0]), ChainGraph.id(c, ds[1]))
            }
        }
        for c in 0..<81 where board.values[c] == 0 {
            for d in board.candidates[c].digits {
                let a = ChainGraph.id(c, d)
                for p in Geometry.peers[c] where present[ChainGraph.id(p, d)] { weak[a].append(ChainGraph.id(p, d)) }
                if kind == .aic {
                    for d2 in board.candidates[c].digits where d2 != d { weak[a].append(ChainGraph.id(c, d2)) }
                }
            }
        }
        for i in 0..<729 { strong[i].sort() }
        self.present = present
        self.strong = strong
        self.weak = weak
    }

    /// Two different candidates that can't both be true.
    static func conflict(_ a: Int, _ b: Int) -> Bool {
        guard a != b else { return false }
        let (ca, cb) = (a / 9, b / 9)
        return ca == cb || (a % 9 == b % 9 && Geometry.sees(ca, cb))
    }

    /// Present candidates (other than `a` and `b`) that conflict with both.
    func commonConflicts(_ a: Int, _ b: Int) -> [Int] {
        let cell = a / 9, digit = a % 9 + 1
        var out: [Int] = []
        for d in board.candidates[cell].digits where d != digit { out.append(ChainGraph.id(cell, d)) }
        for p in Geometry.peers[cell] where present[ChainGraph.id(p, digit)] { out.append(ChainGraph.id(p, digit)) }
        return out.filter { $0 != b && ChainGraph.conflict($0, b) }.sorted()
    }

    /// The shortest chain that starts and ends with a strong link and removes a candidate.
    /// "start false ⇒ end true", so anything conflicting with both ends is false.
    func shortestChain(maxNodes: Int) -> (chain: [Int], eliminations: [Int])? {
        var best: (chain: [Int], eliminations: [Int])?
        for start in 0..<729 where present[start] && !strong[start].isEmpty {
            let limit = min(maxNodes, (best?.chain.count ?? maxNodes + 1) - 1)
            // State = node * 2 + (0: next link strong, 1: next link weak).
            var parent = [Int](repeating: -2, count: 1458)
            parent[start * 2] = -1
            var frontier = [start * 2]
            var length = 1
            search: while !frontier.isEmpty && length < limit {
                length += 1
                var next: [Int] = []
                for state in frontier {
                    let node = state / 2
                    let viaStrong = state % 2 == 0
                    for n in viaStrong ? strong[node] : weak[node] {
                        let ns = n * 2 + (viaStrong ? 1 : 0)
                        guard parent[ns] == -2 else { continue }
                        parent[ns] = state
                        next.append(ns)
                        guard viaStrong, n != start else { continue }
                        let eliminations = commonConflicts(start, n)
                        guard !eliminations.isEmpty else { continue }
                        var chain: [Int] = []
                        var s = ns
                        while s >= 0 {
                            chain.append(s / 2)
                            s = parent[s]
                        }
                        best = (chain.reversed(), eliminations)
                        break search
                    }
                }
                frontier = next
            }
        }
        return best
    }
}

/// Alternating inference chains: X-Cycle (one digit), XY-Chain (bivalue cells), AIC (any links).
public struct AlternatingChain: Technique {
    let kind: ChainKind
    let maxNodes: Int
    public let id: TechniqueID

    public static let xCycle = AlternatingChain(kind: .xCycle, maxNodes: 12, id: .xCycle)
    public static let xyChain = AlternatingChain(kind: .xyChain, maxNodes: 14, id: .xyChain)
    public static let aic = AlternatingChain(kind: .aic, maxNodes: 14, id: .aic)

    public func find(in board: Board) -> Step? {
        guard let found = ChainGraph(board: board, kind: kind).shortestChain(maxNodes: maxNodes) else { return nil }
        let nodes = found.chain.map(ChainGraph.node)
        var cells: [Int] = []
        for n in nodes where !cells.contains(n.cell) { cells.append(n.cell) }
        return Step(
            technique: id,
            patternCells: cells,
            patternCandidates: nodes,
            eliminations: found.eliminations.map(ChainGraph.node),
            digits: Set(nodes.map(\.digit)).sorted()
        )
    }
}
