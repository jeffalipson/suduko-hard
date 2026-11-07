/// Where a Mathdoku step happens, for hint text ("in row 4", "in the 12× cage").
public enum MathRegion: Hashable, Sendable, Codable {
    case row(Int), column(Int), cage(Int)
}

/// One logical deduction on a Mathdoku board. Drives grading, hints and Show me.
public struct MathStep: Hashable, Sendable {
    public let technique: MathTechnique
    public let placements: [CellDigit]
    public let eliminations: [CellDigit]
    /// Cells forming the pattern (Spotlight highlights them).
    public let cells: [Int]
    /// Digits the pattern is about.
    public let digits: [Int]
    public let regions: [MathRegion]

    public init(technique: MathTechnique, placements: [CellDigit] = [], eliminations: [CellDigit] = [],
                cells: [Int] = [], digits: [Int] = [], regions: [MathRegion] = []) {
        self.technique = technique
        self.placements = placements
        self.eliminations = eliminations
        self.cells = cells
        self.digits = digits
        self.regions = regions
    }
}

extension MathdokuBoard {
    /// Applies a step's placements and eliminations.
    public mutating func apply(_ step: MathStep) {
        for p in step.placements where values[p.cell] == 0 { place(p.cell, p.digit) }
        for e in step.eliminations { candidates[e.cell].remove(e.digit) }
    }

    /// Every cell's options (placed cells: just their digit), indexed by cell.
    var optionGrid: [CandidateSet] { (0..<(n * n)).map(options) }

    /// False when the position can't lead to a solution: an empty cell with no candidates, a digit with
    /// nowhere to go in a line, a repeated digit, or a cage nothing can fill.
    public var isConsistent: Bool {
        for cell in 0..<(n * n) where values[cell] == 0 && candidates[cell].isEmpty { return false }
        for line in lines {
            let placed = line.map { values[$0] }.filter { $0 != 0 }
            if Set(placed).count != placed.count { return false }
            for d in 1...n where !placed.contains(d) && !line.contains(where: { values[$0] == 0 && candidates[$0].contains(d) }) {
                return false
            }
        }
        let grid = optionGrid
        for cage in cages where cage.fillings(n: n, candidates: grid, limit: 1).isEmpty { return false }
        return true
    }

    var region: (Int) -> MathRegion { { $0 < n ? .row($0) : .column($0 - n) } }
}

/// Finds the next deduction, easiest technique first.
public enum MathdokuSolver {
    /// The order techniques are tried in: easiest first, so hints and grades use the simplest step.
    public static let order: [MathTechnique] = [
        .nakedSingle, .hiddenSingle, .cageArithmetic,
        .cageLineForced, .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple,
        .xWing, .swordfish, .cagePair,
        .contradiction,
    ]

    public static func nextStep(on board: MathdokuBoard, maxLevel: Int = 4) -> MathStep? {
        for t in order where t.level <= maxLevel {
            if let s = step(t, on: board) { return s }
        }
        return nil
    }

    /// The first application of `technique` on `board`, if any.
    public static func step(_ technique: MathTechnique, on board: MathdokuBoard) -> MathStep? {
        switch technique {
        case .nakedSingle: nakedSingle(board)
        case .hiddenSingle: hiddenSingle(board)
        case .cageArithmetic: cageArithmetic(board)
        case .cageLineForced: cageLineForced(board)
        case .nakedPair: nakedSubset(board, size: 2, technique)
        case .nakedTriple: nakedSubset(board, size: 3, technique)
        case .hiddenPair: hiddenSubset(board, size: 2, technique)
        case .hiddenTriple: hiddenSubset(board, size: 3, technique)
        case .xWing: fish(board, size: 2, technique)
        case .swordfish: fish(board, size: 3, technique)
        case .cagePair: cagePair(board)
        case .contradiction: contradiction(board)
        }
    }

    // MARK: Level 1

    static func nakedSingle(_ b: MathdokuBoard) -> MathStep? {
        for cell in 0..<(b.n * b.n) where b.values[cell] == 0 {
            if let d = b.candidates[cell].single {
                return MathStep(technique: .nakedSingle, placements: [CellDigit(cell: cell, digit: d)], cells: [cell], digits: [d])
            }
        }
        return nil
    }

    static func hiddenSingle(_ b: MathdokuBoard) -> MathStep? {
        for (li, line) in b.lines.enumerated() {
            for d in 1...b.n where !line.contains(where: { b.values[$0] == d }) {
                let spots = line.filter { b.values[$0] == 0 && b.candidates[$0].contains(d) }
                if spots.count == 1 {
                    return MathStep(technique: .hiddenSingle, placements: [CellDigit(cell: spots[0], digit: d)],
                                    cells: spots, digits: [d], regions: [b.region(li)])
                }
            }
        }
        return nil
    }

    static func cageArithmetic(_ b: MathdokuBoard) -> MathStep? {
        let grid = b.optionGrid
        for (ci, cage) in b.cages.enumerated() where cage.cells.contains(where: { b.values[$0] == 0 }) {
            let fs = cage.fillings(n: b.n, candidates: grid)
            guard !fs.isEmpty else { continue }
            var elims: [CellDigit] = []
            for (i, cell) in cage.cells.enumerated() where b.values[cell] == 0 {
                let allowed = CandidateSet(fs.map { $0[i] })
                for d in b.candidates[cell].subtracting(allowed).digits { elims.append(CellDigit(cell: cell, digit: d)) }
            }
            if !elims.isEmpty {
                return MathStep(technique: .cageArithmetic, eliminations: elims, cells: cage.cells,
                                digits: Array(Set(elims.map(\.digit))).sorted(), regions: [.cage(ci)])
            }
        }
        return nil
    }

    // MARK: Level 2

    static func cageLineForced(_ b: MathdokuBoard) -> MathStep? {
        let grid = b.optionGrid
        for (ci, cage) in b.cages.enumerated() where cage.cells.contains(where: { b.values[$0] == 0 }) {
            let fs = cage.fillings(n: b.n, candidates: grid)
            guard !fs.isEmpty else { continue }
            for (li, line) in b.lines.enumerated() {
                let idx = cage.cells.indices.filter { line.contains(cage.cells[$0]) && b.values[cage.cells[$0]] == 0 }
                guard !idx.isEmpty else { continue }
                for d in 1...b.n where fs.allSatisfy({ f in idx.contains { f[$0] == d } }) {
                    let elims = line.filter { !cage.cells.contains($0) && b.values[$0] == 0 && b.candidates[$0].contains(d) }
                        .map { CellDigit(cell: $0, digit: d) }
                    if !elims.isEmpty {
                        return MathStep(technique: .cageLineForced, eliminations: elims, cells: idx.map { cage.cells[$0] },
                                        digits: [d], regions: [.cage(ci), b.region(li)])
                    }
                }
            }
        }
        return nil
    }

    static func nakedSubset(_ b: MathdokuBoard, size: Int, _ t: MathTechnique) -> MathStep? {
        for (li, line) in b.lines.enumerated() {
            let open = line.filter { b.values[$0] == 0 && b.candidates[$0].count <= size }
            for group in combinations(open, size) {
                let union = group.reduce(CandidateSet.empty) { $0.union(b.candidates[$1]) }
                guard union.count == size else { continue }
                let elims = line.filter { !group.contains($0) && b.values[$0] == 0 }
                    .flatMap { c in b.candidates[c].intersection(union).digits.map { CellDigit(cell: c, digit: $0) } }
                if !elims.isEmpty {
                    return MathStep(technique: t, eliminations: elims, cells: group, digits: union.digits, regions: [b.region(li)])
                }
            }
        }
        return nil
    }

    static func hiddenSubset(_ b: MathdokuBoard, size: Int, _ t: MathTechnique) -> MathStep? {
        for (li, line) in b.lines.enumerated() {
            let open = line.filter { b.values[$0] == 0 }
            let digits = (1...b.n).filter { d in
                let spots = open.filter { b.candidates[$0].contains(d) }.count
                return spots >= 2 && spots <= size
            }
            for ds in combinations(digits, size) {
                let spots = open.filter { c in ds.contains { b.candidates[c].contains($0) } }
                guard spots.count == size else { continue }
                let keep = CandidateSet(ds)
                let elims = spots.flatMap { c in b.candidates[c].subtracting(keep).digits.map { CellDigit(cell: c, digit: $0) } }
                if !elims.isEmpty {
                    return MathStep(technique: t, eliminations: elims, cells: spots, digits: ds, regions: [b.region(li)])
                }
            }
        }
        return nil
    }

    // MARK: Level 3

    static func fish(_ b: MathdokuBoard, size: Int, _ t: MathTechnique) -> MathStep? {
        let n = b.n
        for d in 1...n {
            for byRow in [true, false] {
                // Base lines where d has 2…size spots, and the cross-lines those spots sit in.
                var base: [(Int, Set<Int>)] = []
                for i in 0..<n {
                    let cells = byRow ? b.rowCells(i) : b.colCells(i)
                    let cover = Set(cells.filter { b.values[$0] == 0 && b.candidates[$0].contains(d) }.map { byRow ? b.col($0) : b.row($0) })
                    if cover.count >= 2 && cover.count <= size { base.append((i, cover)) }
                }
                for group in combinations(base.indices.map { $0 }, size) {
                    let rows = group.map { base[$0].0 }
                    let cover = group.reduce(Set<Int>()) { $0.union(base[$1].1) }
                    guard cover.count == size else { continue }
                    var elims: [CellDigit] = []
                    for j in cover {
                        for i in 0..<n where !rows.contains(i) {
                            let cell = byRow ? i * n + j : j * n + i
                            if b.values[cell] == 0 && b.candidates[cell].contains(d) { elims.append(CellDigit(cell: cell, digit: d)) }
                        }
                    }
                    if !elims.isEmpty {
                        let cells = rows.flatMap { r in cover.map { c in byRow ? r * n + c : c * n + r } }
                            .filter { b.values[$0] == 0 && b.candidates[$0].contains(d) }
                        return MathStep(technique: t, eliminations: elims, cells: cells, digits: [d],
                                        regions: rows.map { byRow ? .row($0) : .column($0) })
                    }
                }
            }
        }
        return nil
    }

    static func cagePair(_ b: MathdokuBoard) -> MathStep? {
        let grid = b.optionGrid
        let n = b.n
        let fills = b.cages.map { $0.fillings(n: n, candidates: grid, limit: 20_001) }
        for a in b.cages.indices {
            for c in (a + 1)..<b.cages.count {
                let ca = b.cages[a], cb = b.cages[c]
                guard ca.cells.contains(where: { b.values[$0] == 0 }) || cb.cells.contains(where: { b.values[$0] == 0 }) else { continue }
                let links = ca.cells.indices.flatMap { i in cb.cells.indices.compactMap { j -> (Int, Int)? in
                    let x = ca.cells[i], y = cb.cells[j]
                    return x / n == y / n || x % n == y % n ? (i, j) : nil
                } }
                guard !links.isEmpty else { continue }
                let fa = fills[a], fb = fills[c]
                guard fa.count * fb.count <= 20_000, fa.count > 1 || fb.count > 1 else { continue }
                var okA = Set<[Int]>(), okB = Set<[Int]>()
                for f in fa {
                    for g in fb where links.allSatisfy({ f[$0.0] != g[$0.1] }) {
                        okA.insert(f)
                        okB.insert(g)
                    }
                }
                var elims: [CellDigit] = []
                for (cage, ok) in [(ca, okA), (cb, okB)] {
                    for (i, cell) in cage.cells.enumerated() where b.values[cell] == 0 {
                        let allowed = CandidateSet(ok.map { $0[i] })
                        for d in b.candidates[cell].subtracting(allowed).digits { elims.append(CellDigit(cell: cell, digit: d)) }
                    }
                }
                if !elims.isEmpty {
                    return MathStep(technique: .cagePair, eliminations: elims, cells: ca.cells + cb.cells,
                                    digits: Array(Set(elims.map(\.digit))).sorted(), regions: [.cage(a), .cage(c)])
                }
            }
        }
        return nil
    }

    // MARK: Level 4

    /// Try a candidate and follow the easier techniques; if the board breaks, the candidate is wrong.
    static func contradiction(_ b: MathdokuBoard) -> MathStep? {
        let cells = (0..<(b.n * b.n)).filter { b.values[$0] == 0 && b.candidates[$0].count <= 3 }
            .sorted { b.candidates[$0].count < b.candidates[$1].count }
        for cell in cells.prefix(40) {
            for d in b.candidates[cell].digits {
                var trial = b
                trial.place(cell, d)
                if leadsToContradiction(trial) {
                    return MathStep(technique: .contradiction, eliminations: [CellDigit(cell: cell, digit: d)],
                                    cells: [cell], digits: [d])
                }
            }
        }
        return nil
    }

    /// Follows level 1–2 steps until stuck; true if the position becomes impossible on the way.
    static func leadsToContradiction(_ start: MathdokuBoard) -> Bool {
        var board = start
        while true {
            if !board.isConsistent { return true }
            if board.isSolved { return false }
            guard let step = nextStep(on: board, maxLevel: 2) else { return false }
            board.apply(step)
        }
    }

    static func combinations<T>(_ items: [T], _ k: Int) -> [[T]] {
        guard k > 0, items.count >= k else { return k == 0 ? [[]] : [] }
        if k == items.count { return [items] }
        let first = items[0], rest = Array(items.dropFirst())
        return combinations(rest, k - 1).map { [first] + $0 } + combinations(rest, k)
    }
}

/// How hard a Mathdoku is: the hardest technique a logical solve needs.
public struct MathGrade: Sendable {
    /// The answer, if the solver finished (which also proves it is the only one).
    public let solution: [Int]?
    /// 1–4: the hardest technique level used.
    public let level: Int
    public let counts: [MathTechnique: Int]

    public var techniques: [MathTechnique] { counts.keys.sorted() }
}

public enum MathdokuGrader {
    public static func grade(_ puzzle: MathdokuPuzzle, maxLevel: Int = 4) -> MathGrade {
        var board = MathdokuBoard(puzzle: puzzle)
        var counts: [MathTechnique: Int] = [:]
        while !board.isSolved {
            guard board.isConsistent, let step = MathdokuSolver.nextStep(on: board, maxLevel: maxLevel) else {
                return MathGrade(solution: nil, level: counts.keys.map(\.level).max() ?? 0, counts: counts)
            }
            counts[step.technique, default: 0] += 1
            board.apply(step)
        }
        let valid = board.isConsistent && puzzle.cages.allSatisfy { $0.satisfies($0.cells.map { board.values[$0] }) }
        return MathGrade(solution: valid ? board.values : nil, level: max(1, counts.keys.map(\.level).max() ?? 1), counts: counts)
    }
}
