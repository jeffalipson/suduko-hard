# Diabolical & Nightmare Chains Implementation Plan (Plan 3 of 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Diabolical (X-Cycles, XY-Chains, AIC, ALS-XZ, Sue de Coq) and Nightmare (cell, unit and digit forcing chains, nested forcing chains) techniques so the grader, generator and `sudoku-forge` cover the full Easy→Nightmare ladder.

**Architecture:** Alternating inference chains run on a candidate graph (729 nodes: cell × digit) with strong links (conjugate pairs, bivalue cells) and weak links (same digit in peers, other digits in the same cell). A breadth-first search finds the shortest chain that starts and ends with a strong link and removes a candidate; one engine serves X-Cycles, XY-Chains and AIC by restricting which links it may use. Forcing chains assume each branch of a cell/house/candidate, propagate with singles (nested: with the Easy–Hard techniques), and keep conclusions common to every surviving branch. The generator grades with a solver capped at the target tier, which keeps expensive Nightmare searches out of easier generation, and may drop symmetry for Diabolical and Nightmare.

**Tech Stack:** Swift 6.2, SwiftPM, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-10-hard-sudoku-design.md` (§4.5, §5.1)

## Global Constraints

- Diabolical = X-Cycles, XY-Chain, AIC, ALS-XZ, Sue de Coq. Nightmare = forcing chains (cell, unit, digit) and nested forcing chains.
- Catalog order non-decreasing in tier; every `TechniqueID` appears once.
- No technique may contradict the solution of a consistent unique board. Forcing-chain propagation must not use uniqueness techniques (they're invalid under a hypothetical assumption).
- Generator: symmetric clue removal for all tiers; Diabolical and Nightmare may continue with non-symmetric single-cell removal (spec §5.1).
- Spec deviation (ruled here): "ALS chains" are not implemented separately — nested forcing chains subsume them for grading purposes; "X-Cycles" are implemented as single-digit alternating chains (discontinuous loops). The spec's §4.5 table is amended in Task 5.

## Review Focus

1. **Chain soundness on long chains** (repeated nodes, chain ending at its own start) → the implication "start false ⇒ end true" stays valid; a chain whose end is its start is ignored. Fuzz in Task 1.
2. **Forcing chains on branches that contradict** → contradictory branches are dropped; a board where every branch contradicts yields nothing. Tests in Task 4.
3. **Circular static initialisation** (catalog ↔ propagation technique lists) → propagation lists are spelled out, never derived from the catalog. Enforced by Task 4 code and Task 5 catalog test.
4. **Generator time for Diabolical/Nightmare** → capped-tier grading; measured in Task 5, with `--timeout` bounding CLI runs.
5. **Inkala ("world's hardest")** → graded Nightmare by the full catalog, or a recorded ruling if even nested forcing gets stuck.

## File Structure

```
SudokuCore/Sources/SudokuCore/
├── Model/TechniqueID.swift              (modify: 9 new cases)
├── Model/Board+Contradiction.swift      (new: Board.isContradictory)
├── Techniques/Chains.swift              (new: ChainKind, ChainGraph, AlternatingChain)
├── Techniques/AlmostLockedSets.swift    (new: AlmostLockedSet, ALSXZ)
├── Techniques/SueDeCoq.swift            (new)
├── Techniques/ForcingChains.swift       (new: Propagation, ForcingChain)
├── Solvers/Technique.swift              (modify: catalog)
└── Generation/ClassicGenerator.swift    (modify: capped grading, asymmetric pass)
SudokuCore/Tests/SudokuCoreTests/
├── ChainTests.swift, AlmostLockedSetTests.swift, SueDeCoqTests.swift, ForcingChainTests.swift (new)
├── LogicalSolverTests.swift, ClassicGeneratorTests.swift (modify)
```

---

### Task 1: Technique IDs and the chain engine (X-Cycle, XY-Chain, AIC)

**Files:**
- Modify: `SudokuCore/Sources/SudokuCore/Model/TechniqueID.swift`
- Create: `SudokuCore/Sources/SudokuCore/Techniques/Chains.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/ChainTests.swift`

**Interfaces:**
- Produces: `TechniqueID` cases `xCycle, xyChain, sueDeCoq, alsXZ, aic, cellForcingChain, unitForcingChain, digitForcingChain, nestedForcingChain`; `AlternatingChain.xCycle`, `.xyChain`, `.aic` (each a `Technique`). `Step.patternCandidates` holds the chain's nodes in order.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/ChainTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct ChainTests {
    @Test func xCycleFindsSkyscraperAsAChain() throws {
        let b = board(digit: 4, onlyIn: [rc(1, 0), rc(1, 4), rc(6, 0), rc(6, 5), rc(0, 5), rc(2, 5)])
        let step = try #require(AlternatingChain.xCycle.find(in: b))
        #expect(step.technique == .xCycle)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 5), digit: 4), CellDigit(cell: rc(2, 5), digit: 4)])
        #expect(step.patternCandidates.count == 4)
        #expect(step.digits == [4])
    }

    @Test func xyChainFindsXYWingAsAChain() throws {
        var b = emptyBoard()
        b.candidates[rc(4, 4)] = CandidateSet([1, 2])
        b.candidates[rc(4, 0)] = CandidateSet([1, 3])
        b.candidates[rc(0, 4)] = CandidateSet([2, 3])
        #expect(AlternatingChain.xCycle.find(in: b) == nil)
        let step = try #require(AlternatingChain.xyChain.find(in: b))
        #expect(step.technique == .xyChain)
        #expect(step.eliminations == [CellDigit(cell: rc(0, 0), digit: 3)])
        #expect(step.patternCandidates.count == 6)
    }

    @Test func aicFindsWWingAsAChain() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([4, 8])
        b.candidates[rc(5, 3)] = CandidateSet([4, 8])
        for row in 0..<9 where row != 2 && row != 5 { b.eliminate(4, at: rc(row, 1)) }
        let step = try #require(AlternatingChain.aic.find(in: b))
        #expect(step.technique == .aic)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 3), digit: 8), CellDigit(cell: rc(5, 0), digit: 8)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(AlternatingChain.xCycle.find(in: emptyBoard()) == nil)
        #expect(AlternatingChain.aic.find(in: emptyBoard()) == nil)
    }

    @Test func newIDsAreDiabolicalOrNightmare() {
        #expect(TechniqueID.aic.tier == .diabolical)
        #expect(TechniqueID.sueDeCoq.tier == .diabolical)
        #expect(TechniqueID.nestedForcingChain.tier == .nightmare)
        #expect(TechniqueID.xCycle.displayName == "X-Cycle")
    }

    @Test func sound() {
        #expect(soundnessViolations(of: AlternatingChain.xCycle, seeds: 1...20).isEmpty)
        #expect(soundnessViolations(of: AlternatingChain.xyChain, seeds: 1...20).isEmpty)
        #expect(soundnessViolations(of: AlternatingChain.aic, seeds: 1...20).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter ChainTests`
Expected: build FAILS with `cannot find 'AlternatingChain' in scope`.

- [ ] **Step 3: Extend TechniqueID**

In `SudokuCore/Sources/SudokuCore/Model/TechniqueID.swift` make these edits:
- After the line `case finnedXWing, simpleColoring, finnedSwordfish, jellyfish` add:
```swift
    case xCycle, xyChain, sueDeCoq, alsXZ, aic
    case cellForcingChain, unitForcingChain, digitForcingChain, nestedForcingChain
```
- In `tier`, before the closing brace of the switch add:
```swift
        case .xCycle, .xyChain, .sueDeCoq, .alsXZ, .aic:
            return .diabolical
        case .cellForcingChain, .unitForcingChain, .digitForcingChain, .nestedForcingChain:
            return .nightmare
```
- In `weight` add:
```swift
        case .xCycle: return 250
        case .xyChain: return 260
        case .sueDeCoq: return 270
        case .alsXZ: return 280
        case .aic: return 300
        case .cellForcingChain: return 400
        case .unitForcingChain: return 420
        case .digitForcingChain: return 450
        case .nestedForcingChain: return 500
```
- In `displayName` add:
```swift
        case .xCycle: return "X-Cycle"
        case .xyChain: return "XY-Chain"
        case .sueDeCoq: return "Sue de Coq"
        case .alsXZ: return "ALS-XZ"
        case .aic: return "Alternating Inference Chain"
        case .cellForcingChain: return "Cell Forcing Chain"
        case .unitForcingChain: return "Unit Forcing Chain"
        case .digitForcingChain: return "Digit Forcing Chain"
        case .nestedForcingChain: return "Nested Forcing Chain"
```

- [ ] **Step 4: Implement the chain engine**

`SudokuCore/Sources/SudokuCore/Techniques/Chains.swift`:
```swift
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter ChainTests`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add alternating inference chains (X-Cycle, XY-Chain, AIC)"
```

---

### Task 2: ALS-XZ

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/AlmostLockedSets.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/AlmostLockedSetTests.swift`

**Interfaces:**
- Produces: `ALSXZ()`; internal `AlmostLockedSet { cells, digits, house; static all(in:maxSize:) }`.

An almost locked set is N cells in one house holding N+1 candidates. Two disjoint ALSs A and B sharing a restricted common digit x (every x in A sees every x in B) and another common digit z: z must be in A or B, so cells seeing every z of both lose z.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/AlmostLockedSetTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct AlmostLockedSetTests {
    @Test func alsXZ() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([1, 2])   // ALS A (one cell)
        b.candidates[rc(4, 0)] = CandidateSet([1, 3])   // ALS B (row 4, two cells)
        b.candidates[rc(4, 1)] = CandidateSet([2, 3])
        let step = try #require(ALSXZ().find(in: b))
        #expect(step.technique == .alsXZ)
        let expected = [rc(0, 1), rc(1, 1), rc(2, 1), rc(3, 0), rc(5, 0)].map { CellDigit(cell: $0, digit: 2) }
        #expect(Set(step.eliminations) == Set(expected))
    }

    @Test func nothingOnEmptyBoard() {
        #expect(ALSXZ().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: ALSXZ(), seeds: 1...20).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter AlmostLockedSetTests`
Expected: build FAILS with `cannot find 'ALSXZ' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/AlmostLockedSets.swift`:
```swift
/// N cells of one house holding exactly N+1 candidates.
struct AlmostLockedSet {
    let cells: [Int]
    let digits: CandidateSet
    let house: Int

    func cells(with digit: Int, on board: Board) -> [Int] { cells.filter { board.has(digit, at: $0) } }

    /// Every ALS of 1...maxSize cells, each cell set listed once.
    static func all(in board: Board, maxSize: Int) -> [AlmostLockedSet] {
        var seen = Set<[Int]>()
        var out: [AlmostLockedSet] = []
        for (h, house) in Geometry.houses.enumerated() {
            let empties = house.filter { board.values[$0] == 0 }
            for k in 1...maxSize where k < empties.count {
                for combo in empties.combinations(of: k) {
                    let digits = combo.reduce(CandidateSet.empty) { $0.union(board.candidates[$1]) }
                    guard digits.count == k + 1, seen.insert(combo).inserted else { continue }
                    out.append(AlmostLockedSet(cells: combo, digits: digits, house: h))
                }
            }
        }
        return out
    }
}

/// Two almost locked sets joined by a restricted common digit x: another common digit z
/// must sit in one of them, so cells seeing every z in both lose z.
public struct ALSXZ: Technique {
    public init() {}
    public var id: TechniqueID { .alsXZ }

    public func find(in board: Board) -> Step? {
        let sets = AlmostLockedSet.all(in: board, maxSize: 3)
        for i in sets.indices {
            for j in sets.indices where j > i {
                let (a, b) = (sets[i], sets[j])
                guard Set(a.cells).isDisjoint(with: b.cells) else { continue }
                let common = a.digits.intersection(b.digits)
                guard common.count >= 2 else { continue }
                for x in common.digits {
                    let ax = a.cells(with: x, on: board), bx = b.cells(with: x, on: board)
                    guard ax.allSatisfy({ p in bx.allSatisfy { Geometry.sees(p, $0) } }) else { continue }
                    for z in common.digits where z != x {
                        let zCells = a.cells(with: z, on: board) + b.cells(with: z, on: board)
                        let eliminations = board.eliminations(of: z, seeingAll: zCells, excluding: a.cells + b.cells)
                        guard !eliminations.isEmpty else { continue }
                        return Step(
                            technique: id,
                            patternCells: a.cells + b.cells,
                            patternCandidates: board.candidateDigits(of: a.cells + b.cells),
                            eliminations: eliminations,
                            regions: [Region(house: a.house), Region(house: b.house)],
                            digits: [x, z]
                        )
                    }
                }
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter AlmostLockedSetTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add ALS-XZ"
```

---

### Task 3: Sue de Coq

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/SueDeCoq.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/SueDeCoqTests.swift`

**Interfaces:**
- Produces: `SueDeCoq()`.

Box/line intersection cells C (2 or 3, unsolved) holding |C|+2 digits V. A bivalue line cell L ⊂ V and a bivalue box cell B ⊂ V with L ∩ B = ∅: the |C|+2 cells take all of V, so (L ∪ rest) leaves the rest of the line, (B ∪ rest) leaves the rest of the box, and V leaves any other intersection cell, where rest = V − L − B.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/SueDeCoqTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct SueDeCoqTests {
    @Test func sueDeCoq() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([1, 2, 3, 4])
        b.candidates[rc(0, 1)] = CandidateSet([1, 2, 3, 4])
        b.candidates[rc(0, 5)] = CandidateSet([1, 2])   // line cell
        b.candidates[rc(2, 2)] = CandidateSet([3, 4])   // box cell
        let step = try #require(SueDeCoq().find(in: b))
        #expect(step.technique == .sueDeCoq)
        var expected = Set<CellDigit>()
        for c in [rc(0, 3), rc(0, 4), rc(0, 6), rc(0, 7), rc(0, 8)] { for d in [1, 2] { expected.insert(CellDigit(cell: c, digit: d)) } }
        for c in [rc(1, 0), rc(1, 1), rc(1, 2), rc(2, 0), rc(2, 1)] { for d in [3, 4] { expected.insert(CellDigit(cell: c, digit: d)) } }
        for d in 1...4 { expected.insert(CellDigit(cell: rc(0, 2), digit: d)) }
        #expect(Set(step.eliminations) == expected)
    }

    @Test func nothingOnEmptyBoard() {
        #expect(SueDeCoq().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: SueDeCoq(), seeds: 1...20).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter SueDeCoqTests`
Expected: build FAILS with `cannot find 'SueDeCoq' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/SueDeCoq.swift`:
```swift
public struct SueDeCoq: Technique {
    public init() {}
    public var id: TechniqueID { .sueDeCoq }

    public func find(in board: Board) -> Step? {
        for b in 0..<9 {
            let box = Geometry.boxes[b]
            let lines = Set(box.map(Geometry.row)).sorted() + Set(box.map { 9 + Geometry.col($0) }).sorted()
            for line in lines {
                let lineCells = Geometry.houses[line]
                let intersection = box.filter { lineCells.contains($0) && board.values[$0] == 0 }
                let lineRest = lineCells.filter { !box.contains($0) && board.values[$0] == 0 }
                let boxRest = box.filter { !lineCells.contains($0) && board.values[$0] == 0 }
                for size in 2...3 where size <= intersection.count {
                    for core in intersection.combinations(of: size) {
                        let v = core.reduce(CandidateSet.empty) { $0.union(board.candidates[$1]) }
                        guard v.count == size + 2 else { continue }
                        for lc in lineRest where board.candidates[lc].count == 2 && board.candidates[lc].subtracting(v).isEmpty {
                            let l = board.candidates[lc]
                            for bc in boxRest where board.candidates[bc].count == 2 && board.candidates[bc].subtracting(v).isEmpty {
                                let bset = board.candidates[bc]
                                guard l.intersection(bset).isEmpty else { continue }
                                let rest = v.subtracting(l).subtracting(bset)
                                var eliminations: [CellDigit] = []
                                func remove(_ digits: CandidateSet, from cells: [Int]) {
                                    for c in cells {
                                        for d in board.candidates[c].intersection(digits).digits {
                                            eliminations.append(CellDigit(cell: c, digit: d))
                                        }
                                    }
                                }
                                remove(l.union(rest), from: lineRest.filter { $0 != lc })
                                remove(bset.union(rest), from: boxRest.filter { $0 != bc })
                                remove(v, from: intersection.filter { !core.contains($0) })
                                guard !eliminations.isEmpty else { continue }
                                return Step(
                                    technique: id,
                                    patternCells: core + [lc, bc],
                                    patternCandidates: board.candidateDigits(of: core + [lc, bc]),
                                    eliminations: eliminations,
                                    regions: [Region(house: line), .box(b)],
                                    digits: v.digits
                                )
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter SueDeCoqTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add Sue de Coq"
```

---

### Task 4: Contradiction detection and forcing chains

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Model/Board+Contradiction.swift`
- Create: `SudokuCore/Sources/SudokuCore/Techniques/ForcingChains.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/ForcingChainTests.swift`

**Interfaces:**
- Produces: `Board.isContradictory: Bool` (public); `ForcingChain.cell`, `.unit`, `.digit`, `.nested` (each a `Technique`); internal `Propagation.singles`, `Propagation.basic`, `Propagation.run(_:techniques:change:)`.

Each forcing chain assumes every branch, propagates, drops branches that hit a contradiction, and keeps the first conclusion shared by every surviving branch: one placement if any, otherwise the eliminations in the first cell that has them.
- Cell: each candidate of a cell with 2–4 candidates.
- Unit: each position of a digit in a house with 2–4 positions.
- Digit: a candidate true vs false; a contradicting side settles it directly.
- Nested: digit, cell, then unit, propagating with Easy–Hard techniques instead of singles only.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/ForcingChainTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct ForcingChainTests {
    @Test func contradictionDetection() {
        #expect(!emptyBoard().isContradictory)
        var noCandidates = emptyBoard()
        noCandidates.candidates[0] = .empty
        #expect(noCandidates.isContradictory)
        var missingDigit = emptyBoard()
        for c in Geometry.rows[3] { missingDigit.eliminate(6, at: c) }
        #expect(missingDigit.isContradictory)
    }

    @Test func forcingChainsCrackInkalaWhereFiendishGetsStuck() throws {
        let stuck = LogicalSolver.classic.solve(Board(values: values(inkalaPuzzle))).board
        let solution = try #require(BruteForceSolver.solve(values(inkalaPuzzle)))
        let steps = [ForcingChain.cell, .unit, .digit, .nested].compactMap { $0.find(in: stuck) }
        #expect(!steps.isEmpty)
        for step in steps { #expect(isSound(step, solution: solution), "\(step.technique)") }
    }

    @Test func nothingWhenEveryBranchContradicts() {
        var b = emptyBoard()
        for d in 1...9 { for c in Geometry.rows[0] { b.eliminate(d, at: c) } }
        for forcing in [ForcingChain.cell, .unit, .digit, .nested] { #expect(forcing.find(in: b) == nil) }
    }

    @Test func sound() {
        for forcing in [ForcingChain.cell, .unit, .digit, .nested] {
            #expect(soundnessViolations(of: forcing, seeds: 1...4).isEmpty, "\(forcing.id)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter ForcingChainTests`
Expected: build FAILS with `value of type 'Board' has no member 'isContradictory'`.

- [ ] **Step 3: Implement contradiction detection**

`SudokuCore/Sources/SudokuCore/Model/Board+Contradiction.swift`:
```swift
extension Board {
    /// An empty cell with no candidates, a repeated digit in a house, or a digit with no place left in a house.
    public var isContradictory: Bool {
        for c in 0..<81 where values[c] == 0 && candidates[c].isEmpty { return true }
        for house in Geometry.houses {
            var placed = CandidateSet.empty
            var possible = CandidateSet.empty
            for c in house {
                if values[c] != 0 {
                    if placed.contains(values[c]) { return true }
                    placed.insert(values[c])
                } else {
                    possible = possible.union(candidates[c])
                }
            }
            if placed.union(possible) != .all { return true }
        }
        return false
    }
}
```

- [ ] **Step 4: Implement forcing chains**

`SudokuCore/Sources/SudokuCore/Techniques/ForcingChains.swift`:
```swift
enum Propagation {
    /// Spelled out (not derived from the catalog) to avoid circular static initialisation.
    static let singles: [any Technique] = [FullHouse(), NakedSingle(), HiddenSingle()]
    /// No uniqueness techniques: they're invalid under a hypothetical assumption.
    static let basic: [any Technique] = singles + [
        Pointing(), BoxLineReduction(),
        NakedSubset(size: 2), HiddenSubset(size: 2),
        NakedSubset(size: 3), HiddenSubset(size: 3),
    ]

    /// Applies `change`, then `techniques` until stuck. Nil when the board becomes contradictory.
    static func run(_ board: Board, techniques: [any Technique], maxSteps: Int = 300, change: (inout Board) -> Void) -> Board? {
        var b = board
        change(&b)
        let solver = LogicalSolver(techniques: techniques)
        for _ in 0..<maxSteps {
            if b.isContradictory { return nil }
            guard let step = solver.nextStep(on: b) else { return b }
            b.apply(step)
        }
        return b.isContradictory ? nil : b
    }
}

public struct ForcingChain: Technique {
    enum Kind: Sendable { case digit, cell, unit }

    public let id: TechniqueID
    let kinds: [Kind]
    let propagation: [any Technique]

    public static let cell = ForcingChain(id: .cellForcingChain, kinds: [.cell], propagation: Propagation.singles)
    public static let unit = ForcingChain(id: .unitForcingChain, kinds: [.unit], propagation: Propagation.singles)
    public static let digit = ForcingChain(id: .digitForcingChain, kinds: [.digit], propagation: Propagation.singles)
    public static let nested = ForcingChain(id: .nestedForcingChain, kinds: [.digit, .cell, .unit], propagation: Propagation.basic)

    public func find(in board: Board) -> Step? {
        for kind in kinds {
            let step: Step?
            switch kind {
            case .digit: step = digitForcing(board)
            case .cell: step = cellForcing(board)
            case .unit: step = unitForcing(board)
            }
            if let step { return step }
        }
        return nil
    }

    private func assume(_ board: Board, _ digit: Int, at cell: Int) -> Board? {
        Propagation.run(board, techniques: propagation) { $0.place(digit, at: cell) }
    }

    private func cellForcing(_ board: Board) -> Step? {
        for c in 0..<81 where board.values[c] == 0 && (2...4).contains(board.candidates[c].count) {
            let digits = board.candidates[c].digits
            let branches = digits.compactMap { assume(board, $0, at: c) }
            if let step = common(board, branches, pattern: digits.map { CellDigit(cell: c, digit: $0) }) { return step }
        }
        return nil
    }

    private func unitForcing(_ board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            for d in 1...9 {
                let spots = board.cells(with: d, in: house)
                guard (2...4).contains(spots.count) else { continue }
                let branches = spots.compactMap { assume(board, d, at: $0) }
                if var step = common(board, branches, pattern: spots.map { CellDigit(cell: $0, digit: d) }) {
                    step = Step(
                        technique: step.technique, patternCells: step.patternCells, patternCandidates: step.patternCandidates,
                        placements: step.placements, eliminations: step.eliminations, regions: [Region(house: h)], digits: [d]
                    )
                    return step
                }
            }
        }
        return nil
    }

    private func digitForcing(_ board: Board) -> Step? {
        for c in 0..<81 where board.values[c] == 0 {
            for d in board.candidates[c].digits {
                let pattern = [CellDigit(cell: c, digit: d)]
                let ifTrue = assume(board, d, at: c)
                let ifFalse = Propagation.run(board, techniques: propagation) { $0.eliminate(d, at: c) }
                switch (ifTrue, ifFalse) {
                case (nil, nil):
                    continue
                case (nil, _):
                    return Step(technique: id, patternCells: [c], patternCandidates: pattern, eliminations: pattern, digits: [d])
                case (_, nil):
                    return Step(technique: id, patternCells: [c], patternCandidates: pattern, placements: pattern, digits: [d])
                case let (t?, f?):
                    if let step = common(board, [t, f], pattern: pattern) { return step }
                }
            }
        }
        return nil
    }

    /// The first conclusion shared by every branch: a placement, else one cell's eliminations.
    private func common(_ board: Board, _ branches: [Board], pattern: [CellDigit]) -> Step? {
        guard !branches.isEmpty else { return nil }
        let patternCells = Array(Set(pattern.map(\.cell))).sorted()
        let digits = Set(pattern.map(\.digit)).sorted()
        for c in 0..<81 where board.values[c] == 0 {
            let v = branches[0].values[c]
            if v != 0 && branches.allSatisfy({ $0.values[c] == v }) {
                return Step(technique: id, patternCells: patternCells, patternCandidates: pattern,
                            placements: [CellDigit(cell: c, digit: v)], digits: digits)
            }
        }
        for c in 0..<81 where board.values[c] == 0 {
            let gone = board.candidates[c].digits.filter { d in
                branches.allSatisfy { b in b.values[c] != 0 ? b.values[c] != d : !b.candidates[c].contains(d) }
            }
            if !gone.isEmpty {
                return Step(technique: id, patternCells: patternCells, patternCandidates: pattern,
                            eliminations: gone.map { CellDigit(cell: c, digit: $0) }, digits: digits)
            }
        }
        return nil
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter ForcingChainTests`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add contradiction detection and forcing chains"
```

---

### Task 5: Full catalog, capped generator grading, Diabolical/Nightmare generation

**Files:**
- Modify: `SudokuCore/Sources/SudokuCore/Solvers/Technique.swift` (catalog)
- Modify: `SudokuCore/Sources/SudokuCore/Generation/ClassicGenerator.swift`
- Modify: `SudokuCore/Tests/SudokuCoreTests/LogicalSolverTests.swift`, `ClassicGeneratorTests.swift`
- Modify: `docs/superpowers/specs/2026-10-10-hard-sudoku-design.md` (§4.5 Diabolical/Nightmare rows)

**Interfaces:**
- Produces: `LogicalSolver.classic.maxTier == .nightmare`; generator supports every tier.

- [ ] **Step 1: Update the failing tests**

In `LogicalSolverTests.swift`:
- `maxTierOfClassicCatalog` expects `.nightmare`.
- Replace `stuckPuzzleHasNoGrade` with:
```swift
    @Test func inkalaIsNightmare() throws {
        let report = try #require(Grader.grade(values(inkalaPuzzle)))
        #expect(report.grade.tier == .nightmare)
    }
```

In `ClassicGeneratorTests.swift`:
- Remove `unsupportedTierReturnsNilImmediately` (every tier is supported now).
- Add:
```swift
    @Test(arguments: [Tier.diabolical, .nightmare])
    func generatesChainTiers(tier: Tier) throws {
        var rng = SplitMix64(seed: 3)
        let p = try #require(ClassicGenerator().generate(tier: tier, using: &rng))
        #expect(p.grade.tier == tier)
        #expect(BruteForceSolver.countSolutions(p.givens) == 1)
        #expect(Grader.grade(p.givens)?.grade == p.grade)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter "LogicalSolverTests|ClassicGeneratorTests"`
Expected: FAIL — maxTier is `.fiendish`, Inkala ungraded, chain tiers return nil.

- [ ] **Step 3: Extend the catalog**

In `TechniqueCatalog.classic`, after `BasicFish(size: 4),` append:
```swift
        // Diabolical
        AlternatingChain.xCycle,
        AlternatingChain.xyChain,
        SueDeCoq(),
        ALSXZ(),
        AlternatingChain.aic,
        // Nightmare
        ForcingChain.cell,
        ForcingChain.unit,
        ForcingChain.digit,
        ForcingChain.nested,
```

- [ ] **Step 4: Cap grading and allow asymmetric digging in the generator**

Replace `attempt` in `ClassicGenerator.swift` with:
```swift
    private func attempt<R: RandomNumberGenerator>(tier: Tier, using rng: inout R) -> Puzzle? {
        // Grade only with techniques up to the target: anything harder leaves the solver stuck,
        // which rejects the removal without running expensive searches.
        let capped = LogicalSolver(techniques: solver.techniques.filter { $0.id.tier <= tier })
        let solution = BruteForceSolver.randomSolution(using: &rng)
        var givens = solution
        var accepted: GradeReport?

        func tryRemoving(_ cells: [Int]) {
            let saved = cells.map { givens[$0] }
            for p in cells { givens[p] = 0 }
            if BruteForceSolver.countSolutions(givens) == 1,
               let report = Grader.grade(givens, solution: solution, solver: capped) {
                accepted = report
            } else {
                for (p, v) in zip(cells, saved) { givens[p] = v }
            }
        }

        // Cell c pairs with 80 - c (180° symmetry); 40 is the centre.
        var order = Array(0...40)
        order.shuffle(using: &rng)
        for c in order { tryRemoving(c == 40 ? [40] : [c, 80 - c]) }

        // Diabolical and Nightmare may drop symmetry to dig deeper (spec §5.1).
        if tier >= .diabolical {
            var singles = (0..<81).filter { givens[$0] != 0 }
            singles.shuffle(using: &rng)
            for c in singles where (accepted?.grade.tier ?? .easy) < tier { tryRemoving([c]) }
        }

        guard let report = accepted, report.grade.tier == tier else { return nil }
        return Puzzle(
            id: String(rng.next(), radix: 16),
            mode: .classic,
            givens: givens,
            cages: [],
            solution: solution,
            grade: report.grade,
            techniquesRequired: report.techniquesRequired
        )
    }
```

- [ ] **Step 5: Amend the spec**

In the spec's §4.5 table, change the Diabolical row's techniques to `X-Cycles (single-digit alternating chains), XY-Chains, AIC, ALS-XZ, Sue de Coq` and the Nightmare row to `Forcing chains (cell, unit, digit), nested forcing chains (propagating with Easy–Hard techniques)`.

- [ ] **Step 6: Run the whole suite**

Run: `swift test --package-path SudokuCore`
Expected: PASS. Record the Diabolical/Nightmare generation times from the output; if Nightmare exceeds 120 s in debug, rule it into a release-only check rather than weakening the assertion.

- [ ] **Step 7: CLI check**

Run:
```bash
swift build --package-path SudokuCore -c release
SudokuCore/.build/release/sudoku-forge --tier nightmare --count 2 --seed 1 --timeout 300 --out "$TMPDIR/nightmare.json"
```
Expected: two `[n/2] score …` lines whose technique lists include a forcing chain.

- [ ] **Step 8: Commit**

```bash
git add SudokuCore docs
git commit -m "feat(core): grade and generate Diabolical and Nightmare puzzles"
```
