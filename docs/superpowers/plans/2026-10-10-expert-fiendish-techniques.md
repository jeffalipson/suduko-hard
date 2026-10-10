# Expert & Fiendish Techniques Implementation Plan (Plan 2 of 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Expert and Fiendish classic techniques to `SudokuCore` so the grader, generator and `sudoku-forge` can produce Expert and Fiendish puzzles.

**Architecture:** Each technique is a `Technique` returning a `Step`, exactly like Plan 1. Shared board queries (candidate lookup, "sees all" eliminations, conjugate pairs) live in one internal extension. A reusable soundness fuzz walks the solve path of random unique puzzles and checks every step a technique produces against the known solution. The catalog grows to Fiendish, which lifts `LogicalSolver.classic.maxTier`, the generator and the CLI automatically.

**Tech Stack:** Swift 6.2, SwiftPM, Swift Testing. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-10-hard-sudoku-design.md` (§4.3–4.5)

## Roadmap (revised: 7 plans)

Plan 2 of the original roadmap is split because chains need their own inference engine:

1. SudokuCore foundation — done (PR #1).
2. **Expert & Fiendish techniques** (this plan).
3. Diabolical & Nightmare: X-Cycles, XY-Chain, AIC, ALS-XZ, Sue de Coq, forcing chains, ALS chains, nested chains; generator symmetry relaxation.
4. Killer engine.
5. iOS app (Mac app + simulator from here on).
6. Hints & lessons — first harden LogicalSolver for inconsistent player candidates (see Plan 1 roadmap note).
7. Stats.

## Global Constraints

- Swift 6 language mode, no third-party dependencies; `SudokuCore` stays UI-free.
- Tier ladder (spec §4.5): Expert = X-Wing, Swordfish, XY-Wing, Skyscraper, 2-String Kite, UR type 1. Fiendish = XYZ-Wing, W-Wing, Jellyfish, finned X-Wing/Swordfish, simple coloring, empty rectangle, UR types 2–4.
- Techniques are tried easiest first; ties broken by weight (spec §4.3). Catalog order must be non-decreasing in tier.
- No technique may produce a placement or elimination that contradicts the solution of a consistent, uniquely solvable board.
- Uniqueness techniques (unique rectangles) are allowed because every puzzle has exactly one solution; all four rectangle cells must be unsolved.
- Cell indices `0..<81` row-major; houses 0–8 rows, 9–17 columns, 18–26 boxes.

## Review Focus

1. **Unsound eliminations in rarely-firing techniques** (Jellyfish, finned Swordfish, UR type 3) → never remove a solution digit. Every task runs the soundness fuzz for its techniques (Tasks 2–7); Task 8 fuzzes the whole catalog.
2. **Degenerate patterns that overlap simpler techniques** (Skyscraper whose roofs align = X-Wing; finned fish with no fin) → technique returns nil so the simpler technique gets the credit. Guards tested in Tasks 2, 3, 5.
3. **Simple coloring on a cluster with an odd cycle** (only possible on inconsistent boards) → cluster skipped, no crash. Guard in Task 6 code; fuzz exercises consistent boards.
4. **Generator time for Fiendish** → the generator must still return within the test's run; Task 8 measures it and the CLI's `--timeout` bounds library builds.
5. **Catalog drift** (a TechniqueID with no technique, or out-of-order tiers) → Task 8 test asserts every `TechniqueID` is in the catalog exactly once and tiers are non-decreasing.

## File Structure

```
SudokuCore/Sources/SudokuCore/
├── Model/TechniqueID.swift              (modify: 16 new cases, tiers, weights, names)
├── Support/BoardQueries.swift           (new: has/cells/eliminations/conjugatePairs/candidates)
├── Techniques/Fish.swift                (new: FishBase, BasicFish, FinnedFish)
├── Techniques/SingleDigitPatterns.swift (new: Skyscraper, TwoStringKite, EmptyRectangle)
├── Techniques/Wings.swift               (new: XYWing, XYZWing, WWing)
├── Techniques/Coloring.swift            (new: SimpleColoring)
├── Techniques/UniqueRectangles.swift    (new: UniqueRectangle(type:))
└── Solvers/Technique.swift              (modify: catalog)
SudokuCore/Tests/SudokuCoreTests/
├── TestSupport.swift                    (modify: rc, board(digit:onlyIn:), fuzz helpers)
├── SoundnessTests.swift                 (new)
├── FishTests.swift, SingleDigitPatternTests.swift, WingTests.swift,
├── ColoringTests.swift, UniqueRectangleTests.swift (new)
├── LogicalSolverTests.swift, ClassicGeneratorTests.swift (modify)
```

All commands run from `/Users/jeffreylipson/suduko-hard`.

---

### Task 1: Technique IDs, board queries, soundness harness

**Files:**
- Modify: `SudokuCore/Sources/SudokuCore/Model/TechniqueID.swift`
- Create: `SudokuCore/Sources/SudokuCore/Support/BoardQueries.swift`
- Modify: `SudokuCore/Tests/SudokuCoreTests/TestSupport.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/SoundnessTests.swift`

**Interfaces:**
- Produces:
  - New `TechniqueID` cases: `xWing, swordfish, skyscraper, twoStringKite, xyWing, uniqueRectangle1, emptyRectangle, xyzWing, wWing, uniqueRectangle2, uniqueRectangle4, uniqueRectangle3, finnedXWing, simpleColoring, finnedSwordfish, jellyfish`.
  - Internal `Board` extension: `has(_:at:) -> Bool`, `cells(with:in:) -> [Int]`, `eliminations(of:seeingAll:excluding:) -> [CellDigit]`, `conjugatePairs(of:houses:) -> [ConjugatePair]`, `candidateDigits(of:) -> [CellDigit]`; internal `struct ConjugatePair { house, a, b, ends }`.
  - Test helpers: `rc(_:_:)`, `board(digit:onlyIn:)`, `randomUniquePuzzle(seed:)`, `isSound(_:solution:)`, `soundnessViolations(of:seeds:)`.

- [ ] **Step 1: Write the failing test**

Append to `SudokuCore/Tests/SudokuCoreTests/TestSupport.swift`:
```swift

func rc(_ row: Int, _ col: Int) -> Int { Geometry.cell(row, col) }

/// An all-candidates board where `digit` survives only in `cells`.
func board(digit: Int, onlyIn cells: [Int]) -> Board {
    var b = emptyBoard()
    for c in 0..<81 where !cells.contains(c) { b.eliminate(digit, at: c) }
    return b
}

/// A random unique puzzle: symmetric clue removal while the solution stays unique (no grading).
func randomUniquePuzzle(seed: UInt64) -> (givens: [Int], solution: [Int]) {
    var rng = SplitMix64(seed: seed)
    let solution = BruteForceSolver.randomSolution(using: &rng)
    var givens = solution
    var order = Array(0...40)
    order.shuffle(using: &rng)
    for c in order {
        let pair = c == 40 ? [40] : [c, 80 - c]
        let saved = pair.map { givens[$0] }
        for p in pair { givens[p] = 0 }
        if BruteForceSolver.countSolutions(givens) != 1 {
            for (p, v) in zip(pair, saved) { givens[p] = v }
        }
    }
    return (givens, solution)
}

/// True when a step never contradicts the known solution.
func isSound(_ step: Step, solution: [Int]) -> Bool {
    step.placements.allSatisfy { solution[$0.cell] == $0.digit }
        && step.eliminations.allSatisfy { solution[$0.cell] != $0.digit }
}

/// Walks the solve path of random unique puzzles (catalog + `technique`) and records every
/// unsound step `technique` produces along the way.
func soundnessViolations(of technique: any Technique, seeds: ClosedRange<Int>) -> [String] {
    let solver = LogicalSolver(techniques: TechniqueCatalog.classic + [technique])
    var failures: [String] = []
    for seed in seeds {
        let (givens, solution) = randomUniquePuzzle(seed: UInt64(seed))
        var board = Board(values: givens)
        for _ in 0..<500 {
            if let step = technique.find(in: board), !isSound(step, solution: solution) {
                failures.append("seed \(seed): \(step.technique) on \(board.string)")
            }
            guard let next = solver.nextStep(on: board) else { break }
            board.apply(next)
        }
    }
    return failures
}
```

`SudokuCore/Tests/SudokuCoreTests/SoundnessTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct SoundnessTests {
    @Test func everyCatalogTechniqueIsSound() {
        for technique in TechniqueCatalog.classic {
            #expect(soundnessViolations(of: technique, seeds: 1...20).isEmpty, "\(technique.id)")
        }
    }

    @Test func newTechniqueIDsHaveExpectedTiers() {
        #expect(TechniqueID.xWing.tier == .expert)
        #expect(TechniqueID.uniqueRectangle1.tier == .expert)
        #expect(TechniqueID.jellyfish.tier == .fiendish)
        #expect(TechniqueID.uniqueRectangle3.tier == .fiendish)
        #expect(TechniqueID.finnedSwordfish.displayName == "Finned Swordfish")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter SoundnessTests`
Expected: build FAILS with `type 'TechniqueID' has no member 'xWing'`.

- [ ] **Step 3: Extend TechniqueID**

Replace `SudokuCore/Sources/SudokuCore/Model/TechniqueID.swift` with:
```swift
/// Every technique the engine knows. Later plans append cases.
public enum TechniqueID: String, Codable, CaseIterable, Sendable {
    case fullHouse, nakedSingle, hiddenSingle
    case pointing, boxLineReduction, nakedPair, hiddenPair
    case nakedTriple, hiddenTriple, nakedQuad, hiddenQuad
    case xWing, uniqueRectangle1, skyscraper, twoStringKite, xyWing, swordfish
    case emptyRectangle, xyzWing, wWing, uniqueRectangle2, uniqueRectangle4, uniqueRectangle3
    case finnedXWing, simpleColoring, finnedSwordfish, jellyfish

    public var tier: Tier {
        switch self {
        case .fullHouse, .nakedSingle, .hiddenSingle:
            return .easy
        case .pointing, .boxLineReduction, .nakedPair, .hiddenPair:
            return .medium
        case .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad:
            return .hard
        case .xWing, .uniqueRectangle1, .skyscraper, .twoStringKite, .xyWing, .swordfish:
            return .expert
        case .emptyRectangle, .xyzWing, .wWing, .uniqueRectangle2, .uniqueRectangle4, .uniqueRectangle3,
             .finnedXWing, .simpleColoring, .finnedSwordfish, .jellyfish:
            return .fiendish
        }
    }

    /// Contribution of one use of this technique to a puzzle's score.
    public var weight: Int {
        switch self {
        case .fullHouse: return 1
        case .nakedSingle: return 2
        case .hiddenSingle: return 2
        case .pointing: return 10
        case .boxLineReduction: return 10
        case .nakedPair: return 15
        case .hiddenPair: return 20
        case .nakedTriple: return 30
        case .hiddenTriple: return 35
        case .nakedQuad: return 50
        case .hiddenQuad: return 60
        case .xWing: return 100
        case .uniqueRectangle1: return 100
        case .skyscraper: return 110
        case .twoStringKite: return 110
        case .xyWing: return 120
        case .swordfish: return 140
        case .emptyRectangle: return 150
        case .xyzWing: return 160
        case .wWing: return 170
        case .uniqueRectangle2: return 170
        case .uniqueRectangle4: return 170
        case .uniqueRectangle3: return 180
        case .finnedXWing: return 180
        case .simpleColoring: return 200
        case .finnedSwordfish: return 210
        case .jellyfish: return 220
        }
    }

    public var displayName: String {
        switch self {
        case .fullHouse: return "Full House"
        case .nakedSingle: return "Naked Single"
        case .hiddenSingle: return "Hidden Single"
        case .pointing: return "Pointing"
        case .boxLineReduction: return "Box/Line Reduction"
        case .nakedPair: return "Naked Pair"
        case .hiddenPair: return "Hidden Pair"
        case .nakedTriple: return "Naked Triple"
        case .hiddenTriple: return "Hidden Triple"
        case .nakedQuad: return "Naked Quad"
        case .hiddenQuad: return "Hidden Quad"
        case .xWing: return "X-Wing"
        case .uniqueRectangle1: return "Unique Rectangle (Type 1)"
        case .skyscraper: return "Skyscraper"
        case .twoStringKite: return "2-String Kite"
        case .xyWing: return "XY-Wing"
        case .swordfish: return "Swordfish"
        case .emptyRectangle: return "Empty Rectangle"
        case .xyzWing: return "XYZ-Wing"
        case .wWing: return "W-Wing"
        case .uniqueRectangle2: return "Unique Rectangle (Type 2)"
        case .uniqueRectangle4: return "Unique Rectangle (Type 4)"
        case .uniqueRectangle3: return "Unique Rectangle (Type 3)"
        case .finnedXWing: return "Finned X-Wing"
        case .simpleColoring: return "Simple Coloring"
        case .finnedSwordfish: return "Finned Swordfish"
        case .jellyfish: return "Jellyfish"
        }
    }
}
```

- [ ] **Step 4: Add the board queries**

`SudokuCore/Sources/SudokuCore/Support/BoardQueries.swift`:
```swift
/// Two cells that are the only places for a digit in a house (a strong link).
struct ConjugatePair {
    let house: Int
    let a: Int
    let b: Int

    /// Both orientations as (end, other end).
    var ends: [(Int, Int)] { [(a, b), (b, a)] }
}

extension Board {
    /// True when `cell` is empty and still has `digit` as a candidate.
    func has(_ digit: Int, at cell: Int) -> Bool {
        values[cell] == 0 && candidates[cell].contains(digit)
    }

    /// Cells of `house` that still hold `digit`.
    func cells(with digit: Int, in house: [Int]) -> [Int] {
        house.filter { has(digit, at: $0) }
    }

    /// Removes `digit` from every cell that sees all of `targets`,
    /// skipping the targets themselves and any `pattern` cells.
    func eliminations(of digit: Int, seeingAll targets: [Int], excluding pattern: [Int] = []) -> [CellDigit] {
        (0..<81)
            .filter { c in
                has(digit, at: c) && !targets.contains(c) && !pattern.contains(c)
                    && targets.allSatisfy { Geometry.sees($0, c) }
            }
            .map { CellDigit(cell: $0, digit: digit) }
    }

    /// Strong links for `digit` in the given houses.
    func conjugatePairs(of digit: Int, houses: Range<Int> = 0..<27) -> [ConjugatePair] {
        houses.compactMap { h in
            let found = cells(with: digit, in: Geometry.houses[h])
            return found.count == 2 ? ConjugatePair(house: h, a: found[0], b: found[1]) : nil
        }
    }

    /// Every candidate of the given cells, for `Step.patternCandidates`.
    func candidateDigits(of cells: [Int]) -> [CellDigit] {
        cells.flatMap { c in candidates[c].digits.map { CellDigit(cell: c, digit: $0) } }
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore`
Expected: PASS. (`everyCatalogTechniqueIsSound` covers the Plan 1 catalog; later tasks reuse the harness for each new technique.)

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add expert/fiendish technique IDs, board queries and soundness harness"
```

---

### Task 2: Basic fish (X-Wing, Swordfish, Jellyfish)

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/Fish.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/FishTests.swift`

**Interfaces:**
- Consumes: Task 1 board queries.
- Produces: `BasicFish(size: 2|3|4)` (ids `.xWing/.swordfish/.jellyfish`); internal `FishBase` (`baseHouses`, `cells`, `baseIsRows`, `coverIndex(_:)`, `coverIndices`, `coverHouse(_:)`, `static all(board:digit:baseIsRows:size:maxPerLine:)`) reused by Task 5.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/FishTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct FishTests {
    @Test func xWing() throws {
        let b = board(digit: 5, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(7, 2), rc(0, 6)])
        let step = try #require(BasicFish(size: 2).find(in: b))
        #expect(step.technique == .xWing)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(7, 2), digit: 5), CellDigit(cell: rc(0, 6), digit: 5)])
        #expect(step.regions == [.row(1), .row(4), .column(2), .column(6)])
    }

    @Test func swordfish() throws {
        let b = board(digit: 3, onlyIn: [
            rc(0, 1), rc(0, 4), rc(3, 4), rc(3, 7), rc(6, 1), rc(6, 7), rc(2, 1), rc(8, 4),
        ])
        #expect(BasicFish(size: 2).find(in: b) == nil)
        let step = try #require(BasicFish(size: 3).find(in: b))
        #expect(step.technique == .swordfish)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(2, 1), digit: 3), CellDigit(cell: rc(8, 4), digit: 3)])
    }

    @Test func jellyfish() throws {
        let b = board(digit: 9, onlyIn: [
            rc(0, 0), rc(0, 2), rc(2, 2), rc(2, 4), rc(4, 4), rc(4, 6), rc(6, 6), rc(6, 0), rc(8, 0),
        ])
        #expect(BasicFish(size: 2).find(in: b) == nil)
        #expect(BasicFish(size: 3).find(in: b) == nil)
        let step = try #require(BasicFish(size: 4).find(in: b))
        #expect(step.technique == .jellyfish)
        #expect(step.eliminations == [CellDigit(cell: rc(8, 0), digit: 9)])
    }

    @Test func nothingOnEmptyBoard() {
        for size in 2...4 { #expect(BasicFish(size: size).find(in: emptyBoard()) == nil) }
    }

    @Test(arguments: 2...4)
    func sound(size: Int) {
        #expect(soundnessViolations(of: BasicFish(size: size), seeds: 1...30).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter FishTests`
Expected: build FAILS with `cannot find 'BasicFish' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/Fish.swift`:
```swift
/// A choice of base lines (all rows or all columns) for a fish on one digit.
struct FishBase {
    let baseHouses: [Int]
    /// The digit's candidate cells inside the base lines.
    let cells: [Int]
    let baseIsRows: Bool

    /// Cover-line index (0–8) of a cell: its column when the base lines are rows.
    func coverIndex(_ cell: Int) -> Int { baseIsRows ? Geometry.col(cell) : Geometry.row(cell) }

    var coverIndices: [Int] { Set(cells.map(coverIndex)).sorted() }

    func coverHouse(_ index: Int) -> Int { baseIsRows ? 9 + index : index }

    /// Every `size`-combination of base lines holding 2...`maxPerLine` candidates of `digit`.
    static func all(board: Board, digit: Int, baseIsRows: Bool, size: Int, maxPerLine: Int) -> [FishBase] {
        let lines = baseIsRows ? Array(0..<9) : Array(9..<18)
        let eligible = lines.filter {
            (2...maxPerLine).contains(board.cells(with: digit, in: Geometry.houses[$0]).count)
        }
        return eligible.combinations(of: size).map { combo in
            FishBase(
                baseHouses: combo,
                cells: combo.flatMap { board.cells(with: digit, in: Geometry.houses[$0]) },
                baseIsRows: baseIsRows
            )
        }
    }
}

/// N base lines whose candidates for a digit lie in exactly N cover lines: the digit leaves
/// the rest of the cover lines. X-Wing (2), Swordfish (3), Jellyfish (4).
public struct BasicFish: Technique {
    public let size: Int

    public init(size: Int) {
        precondition((2...4).contains(size), "Fish size must be 2, 3 or 4")
        self.size = size
    }

    public var id: TechniqueID {
        switch size {
        case 2: return .xWing
        case 3: return .swordfish
        default: return .jellyfish
        }
    }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            for baseIsRows in [true, false] {
                for base in FishBase.all(board: board, digit: digit, baseIsRows: baseIsRows, size: size, maxPerLine: size) {
                    let cover = base.coverIndices
                    guard cover.count == size else { continue }
                    let coverHouses = cover.map(base.coverHouse)
                    let eliminations = coverHouses
                        .flatMap { Geometry.houses[$0] }
                        .filter { board.has(digit, at: $0) && !base.cells.contains($0) }
                        .map { CellDigit(cell: $0, digit: digit) }
                    guard !eliminations.isEmpty else { continue }
                    return Step(
                        technique: id,
                        patternCells: base.cells,
                        patternCandidates: base.cells.map { CellDigit(cell: $0, digit: digit) },
                        eliminations: eliminations,
                        regions: (base.baseHouses + coverHouses).map(Region.init(house:)),
                        digits: [digit]
                    )
                }
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter FishTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add X-Wing, Swordfish and Jellyfish"
```

---

### Task 3: Single-digit patterns (Skyscraper, 2-String Kite, Empty Rectangle)

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/SingleDigitPatterns.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/SingleDigitPatternTests.swift`

**Interfaces:**
- Consumes: Task 1 board queries.
- Produces: `Skyscraper()`, `TwoStringKite()`, `EmptyRectangle()`.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/SingleDigitPatternTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct SingleDigitPatternTests {
    @Test func skyscraper() throws {
        // Rows 1 and 6 are strong links on 4 sharing column 0; roofs (1,4) and (6,5).
        let b = board(digit: 4, onlyIn: [rc(1, 0), rc(1, 4), rc(6, 0), rc(6, 5), rc(0, 5), rc(2, 5)])
        let step = try #require(Skyscraper().find(in: b))
        #expect(step.technique == .skyscraper)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 5), digit: 4), CellDigit(cell: rc(2, 5), digit: 4)])
        #expect(step.regions == [.row(1), .row(6)])
    }

    @Test func alignedRoofsAreAnXWingNotASkyscraper() {
        let b = board(digit: 4, onlyIn: [rc(1, 0), rc(1, 4), rc(6, 0), rc(6, 4), rc(3, 4)])
        #expect(Skyscraper().find(in: b) == nil)
    }

    @Test func twoStringKite() throws {
        // Row 0 link (0,1)-(0,6); column 2 link (1,2)-(5,2); (0,1) and (1,2) share box 0.
        let b = board(digit: 6, onlyIn: [rc(0, 1), rc(0, 6), rc(1, 2), rc(5, 2), rc(5, 6)])
        let step = try #require(TwoStringKite().find(in: b))
        #expect(step.technique == .twoStringKite)
        #expect(step.eliminations == [CellDigit(cell: rc(5, 6), digit: 6)])
    }

    @Test func emptyRectangle() throws {
        // Box 0 holds 7 only on row 0 / column 0; column 5 link (0,5)-(6,5).
        let b = board(digit: 7, onlyIn: [rc(0, 1), rc(0, 2), rc(2, 0), rc(0, 5), rc(6, 5), rc(6, 0)])
        let step = try #require(EmptyRectangle().find(in: b))
        #expect(step.technique == .emptyRectangle)
        #expect(step.eliminations == [CellDigit(cell: rc(6, 0), digit: 7)])
        #expect(step.regions == [.box(0), .column(5)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(Skyscraper().find(in: emptyBoard()) == nil)
        #expect(TwoStringKite().find(in: emptyBoard()) == nil)
        #expect(EmptyRectangle().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: Skyscraper(), seeds: 1...30).isEmpty)
        #expect(soundnessViolations(of: TwoStringKite(), seeds: 1...30).isEmpty)
        #expect(soundnessViolations(of: EmptyRectangle(), seeds: 1...30).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter SingleDigitPatternTests`
Expected: build FAILS with `cannot find 'Skyscraper' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/SingleDigitPatterns.swift`:
```swift
/// Two parallel strong links on a digit whose bases share a cross line:
/// one of the two roofs holds the digit, so cells seeing both roofs lose it.
public struct Skyscraper: Technique {
    public init() {}
    public var id: TechniqueID { .skyscraper }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            for lines in [0..<9, 9..<18] {
                let rowsAreLines = lines.lowerBound == 0
                func cross(_ cell: Int) -> Int { rowsAreLines ? Geometry.col(cell) : Geometry.row(cell) }
                for links in board.conjugatePairs(of: digit, houses: lines).combinations(of: 2) {
                    let (p, q) = (links[0], links[1])
                    for (base1, roof1) in p.ends {
                        for (base2, roof2) in q.ends {
                            guard cross(base1) == cross(base2), cross(roof1) != cross(roof2) else { continue }
                            let pattern = [base1, roof1, base2, roof2]
                            let eliminations = board.eliminations(of: digit, seeingAll: [roof1, roof2], excluding: pattern)
                            guard !eliminations.isEmpty else { continue }
                            return Step(
                                technique: id,
                                patternCells: pattern,
                                patternCandidates: pattern.map { CellDigit(cell: $0, digit: digit) },
                                eliminations: eliminations,
                                regions: [Region(house: p.house), Region(house: q.house)],
                                digits: [digit]
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
}

/// A row strong link and a column strong link with one end each in the same box:
/// one of the two far ends holds the digit.
public struct TwoStringKite: Technique {
    public init() {}
    public var id: TechniqueID { .twoStringKite }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            let rowLinks = board.conjugatePairs(of: digit, houses: 0..<9)
            let colLinks = board.conjugatePairs(of: digit, houses: 9..<18)
            for rowLink in rowLinks {
                for colLink in colLinks {
                    for (rowEnd, rowOther) in rowLink.ends {
                        for (colEnd, colOther) in colLink.ends {
                            let pattern = [rowOther, rowEnd, colEnd, colOther]
                            guard Set(pattern).count == 4, Geometry.box(rowEnd) == Geometry.box(colEnd) else { continue }
                            let eliminations = board.eliminations(of: digit, seeingAll: [rowOther, colOther], excluding: pattern)
                            guard !eliminations.isEmpty else { continue }
                            return Step(
                                technique: id,
                                patternCells: pattern,
                                patternCandidates: pattern.map { CellDigit(cell: $0, digit: digit) },
                                eliminations: eliminations,
                                regions: [Region(house: rowLink.house), Region(house: colLink.house), .box(Geometry.box(rowEnd))],
                                digits: [digit]
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
}

/// A box whose candidates for a digit lie on one row and one column (a cross), combined with
/// a strong link that ends on the cross's row or column outside the box.
public struct EmptyRectangle: Technique {
    public init() {}
    public var id: TechniqueID { .emptyRectangle }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            for b in 0..<9 {
                let boxCells = board.cells(with: digit, in: Geometry.boxes[b])
                guard boxCells.count >= 2 else { continue }
                let boxRows = Set(Geometry.boxes[b].map(Geometry.row))
                let boxCols = Set(Geometry.boxes[b].map(Geometry.col))
                for r in boxRows.sorted() {
                    for c in boxCols.sorted() {
                        guard boxCells.allSatisfy({ Geometry.row($0) == r || Geometry.col($0) == c }),
                              boxCells.contains(where: { Geometry.row($0) == r && Geometry.col($0) != c }),
                              boxCells.contains(where: { Geometry.col($0) == c && Geometry.row($0) != r })
                        else { continue }

                        func step(link: ConjugatePair, end: Int, other: Int, target: Int) -> Step {
                            Step(
                                technique: id,
                                patternCells: boxCells + [end, other],
                                patternCandidates: (boxCells + [end, other]).map { CellDigit(cell: $0, digit: digit) },
                                eliminations: [CellDigit(cell: target, digit: digit)],
                                regions: [.box(b), Region(house: link.house)],
                                digits: [digit]
                            )
                        }

                        // Strong link in a column outside the box, one end on row r.
                        for link in board.conjugatePairs(of: digit, houses: 9..<18) where !boxCols.contains(link.house - 9) {
                            for (end, other) in link.ends where Geometry.row(end) == r && !boxRows.contains(Geometry.row(other)) {
                                let target = Geometry.cell(Geometry.row(other), c)
                                if board.has(digit, at: target) { return step(link: link, end: end, other: other, target: target) }
                            }
                        }
                        // Strong link in a row outside the box, one end on column c.
                        for link in board.conjugatePairs(of: digit, houses: 0..<9) where !boxRows.contains(link.house) {
                            for (end, other) in link.ends where Geometry.col(end) == c && !boxCols.contains(Geometry.col(other)) {
                                let target = Geometry.cell(r, Geometry.col(other))
                                if board.has(digit, at: target) { return step(link: link, end: end, other: other, target: target) }
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

Run: `swift test --package-path SudokuCore --filter SingleDigitPatternTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add Skyscraper, 2-String Kite and Empty Rectangle"
```

---

### Task 4: Wings (XY-Wing, XYZ-Wing, W-Wing)

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/Wings.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/WingTests.swift`

**Interfaces:**
- Consumes: Task 1 board queries.
- Produces: `XYWing()`, `XYZWing()`, `WWing()`.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/WingTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct WingTests {
    @Test func xyWing() throws {
        var b = emptyBoard()
        b.candidates[rc(4, 4)] = CandidateSet([1, 2])   // pivot
        b.candidates[rc(4, 0)] = CandidateSet([1, 3])   // pincer (row)
        b.candidates[rc(0, 4)] = CandidateSet([2, 3])   // pincer (column)
        let step = try #require(XYWing().find(in: b))
        #expect(step.technique == .xyWing)
        #expect(step.patternCells == [rc(4, 4), rc(0, 4), rc(4, 0)])
        #expect(step.eliminations == [CellDigit(cell: rc(0, 0), digit: 3)])
    }

    @Test func xyzWing() throws {
        var b = emptyBoard()
        b.candidates[rc(4, 4)] = CandidateSet([1, 2, 3])
        b.candidates[rc(4, 0)] = CandidateSet([1, 3])
        b.candidates[rc(3, 4)] = CandidateSet([2, 3])
        let step = try #require(XYZWing().find(in: b))
        #expect(step.technique == .xyzWing)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(4, 3), digit: 3), CellDigit(cell: rc(4, 5), digit: 3)])
    }

    @Test func wWing() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([4, 8])
        b.candidates[rc(5, 3)] = CandidateSet([4, 8])
        // Column 1: 4 only at (2,1), which sees (0,0), and (5,1), which sees (5,3).
        for row in 0..<9 where row != 2 && row != 5 { b.eliminate(4, at: rc(row, 1)) }
        let step = try #require(WWing().find(in: b))
        #expect(step.technique == .wWing)
        #expect(step.digits == [4, 8])
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 3), digit: 8), CellDigit(cell: rc(5, 0), digit: 8)])
        #expect(step.regions == [.column(1)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(XYWing().find(in: emptyBoard()) == nil)
        #expect(XYZWing().find(in: emptyBoard()) == nil)
        #expect(WWing().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: XYWing(), seeds: 1...30).isEmpty)
        #expect(soundnessViolations(of: XYZWing(), seeds: 1...30).isEmpty)
        #expect(soundnessViolations(of: WWing(), seeds: 1...30).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter WingTests`
Expected: build FAILS with `cannot find 'XYWing' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/Wings.swift`:
```swift
/// Pivot {a,b} seeing pincers {a,c} and {b,c}: one pincer is c, so cells seeing both lose c.
public struct XYWing: Technique {
    public init() {}
    public var id: TechniqueID { .xyWing }

    public func find(in board: Board) -> Step? {
        for pivot in 0..<81 where board.values[pivot] == 0 && board.candidates[pivot].count == 2 {
            let pc = board.candidates[pivot]
            let pincers = Geometry.peers[pivot].filter {
                board.values[$0] == 0 && board.candidates[$0].count == 2 && board.candidates[$0].intersection(pc).count == 1
            }
            for pair in pincers.combinations(of: 2) {
                let (x, y) = (pair[0], pair[1])
                let cx = board.candidates[x], cy = board.candidates[y]
                guard cx.intersection(pc) != cy.intersection(pc) else { continue }
                let ex = cx.subtracting(pc), ey = cy.subtracting(pc)
                guard ex == ey, let z = ex.single else { continue }
                let eliminations = board.eliminations(of: z, seeingAll: [x, y], excluding: [pivot])
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: [pivot, x, y],
                    patternCandidates: board.candidateDigits(of: [pivot, x, y]),
                    eliminations: eliminations,
                    digits: pc.digits + [z]
                )
            }
        }
        return nil
    }
}

/// Pivot {a,b,c} seeing pincers {a,c} and {b,c}: c is in one of the three,
/// so cells seeing all three lose c.
public struct XYZWing: Technique {
    public init() {}
    public var id: TechniqueID { .xyzWing }

    public func find(in board: Board) -> Step? {
        for pivot in 0..<81 where board.values[pivot] == 0 && board.candidates[pivot].count == 3 {
            let pc = board.candidates[pivot]
            let pincers = Geometry.peers[pivot].filter {
                board.values[$0] == 0 && board.candidates[$0].count == 2 && board.candidates[$0].subtracting(pc).isEmpty
            }
            for pair in pincers.combinations(of: 2) {
                let (x, y) = (pair[0], pair[1])
                let cx = board.candidates[x], cy = board.candidates[y]
                guard cx != cy, let z = cx.intersection(cy).single else { continue }
                let eliminations = board.eliminations(of: z, seeingAll: [pivot, x, y])
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: [pivot, x, y],
                    patternCandidates: board.candidateDigits(of: [pivot, x, y]),
                    eliminations: eliminations,
                    digits: pc.digits
                )
            }
        }
        return nil
    }
}

/// Two identical bivalue cells {a,b} that don't see each other, joined by a strong link on a
/// (each link end sees one wing): one wing is b, so cells seeing both wings lose b.
public struct WWing: Technique {
    public init() {}
    public var id: TechniqueID { .wWing }

    public func find(in board: Board) -> Step? {
        let bivalue = (0..<81).filter { board.values[$0] == 0 && board.candidates[$0].count == 2 }
        for wings in bivalue.combinations(of: 2) {
            let (i, j) = (wings[0], wings[1])
            guard board.candidates[i] == board.candidates[j], !Geometry.sees(i, j) else { continue }
            let ds = board.candidates[i].digits
            for (link, removed) in [(ds[0], ds[1]), (ds[1], ds[0])] {
                for pair in board.conjugatePairs(of: link) {
                    guard ![i, j].contains(pair.a), ![i, j].contains(pair.b) else { continue }
                    let joined = (Geometry.sees(pair.a, i) && Geometry.sees(pair.b, j))
                        || (Geometry.sees(pair.a, j) && Geometry.sees(pair.b, i))
                    guard joined else { continue }
                    let eliminations = board.eliminations(of: removed, seeingAll: [i, j])
                    guard !eliminations.isEmpty else { continue }
                    return Step(
                        technique: id,
                        patternCells: [i, j, pair.a, pair.b],
                        patternCandidates: board.candidateDigits(of: [i, j])
                            + [CellDigit(cell: pair.a, digit: link), CellDigit(cell: pair.b, digit: link)],
                        eliminations: eliminations,
                        regions: [Region(house: pair.house)],
                        digits: [link, removed]
                    )
                }
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter WingTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add XY-Wing, XYZ-Wing and W-Wing"
```

---

### Task 5: Finned fish (finned X-Wing, finned Swordfish)

**Files:**
- Modify: `SudokuCore/Sources/SudokuCore/Techniques/Fish.swift` (append)
- Test: `SudokuCore/Tests/SudokuCoreTests/FishTests.swift` (append a suite)

**Interfaces:**
- Consumes: `FishBase` (Task 2).
- Produces: `FinnedFish(size: 2|3)` (ids `.finnedXWing/.finnedSwordfish`).

- [ ] **Step 1: Write the failing test**

Append to `SudokuCore/Tests/SudokuCoreTests/FishTests.swift`:
```swift

@Suite struct FinnedFishTests {
    @Test func finnedXWing() throws {
        // Rows 1 and 4 on columns 2/6, fin at (4,7) in box 5.
        let b = board(digit: 2, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(4, 7), rc(3, 6)])
        #expect(BasicFish(size: 2).find(in: b) == nil)
        let step = try #require(FinnedFish(size: 2).find(in: b))
        #expect(step.technique == .finnedXWing)
        #expect(step.eliminations == [CellDigit(cell: rc(3, 6), digit: 2)])
        #expect(step.regions.last == .box(5))
    }

    @Test func finnedSwordfish() throws {
        // Rows 0, 3, 6 on columns 1/4/7, fin at (6,8) in box 8.
        let b = board(digit: 8, onlyIn: [
            rc(0, 1), rc(0, 4), rc(3, 4), rc(3, 7), rc(6, 1), rc(6, 7), rc(6, 8), rc(8, 7),
        ])
        let step = try #require(FinnedFish(size: 3).find(in: b))
        #expect(step.technique == .finnedSwordfish)
        #expect(step.eliminations == [CellDigit(cell: rc(8, 7), digit: 8)])
    }

    @Test func plainXWingHasNoFin() {
        // Rows give a basic X-Wing; the column view has fins in different boxes.
        let b = board(digit: 5, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(7, 2), rc(0, 6)])
        #expect(FinnedFish(size: 2).find(in: b) == nil)
    }

    @Test(arguments: 2...3)
    func sound(size: Int) {
        #expect(soundnessViolations(of: FinnedFish(size: size), seeds: 1...30).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter FinnedFishTests`
Expected: build FAILS with `cannot find 'FinnedFish' in scope`.

- [ ] **Step 3: Implement**

Append to `SudokuCore/Sources/SudokuCore/Techniques/Fish.swift`:
```swift

/// A fish with extra candidates ("fins") confined to one box: either a fin is true or the
/// fish holds, so cover-line cells inside the fin box lose the digit.
public struct FinnedFish: Technique {
    public let size: Int

    public init(size: Int) {
        precondition((2...3).contains(size), "Finned fish size must be 2 or 3")
        self.size = size
    }

    public var id: TechniqueID { size == 2 ? .finnedXWing : .finnedSwordfish }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            for baseIsRows in [true, false] {
                for base in FishBase.all(board: board, digit: digit, baseIsRows: baseIsRows, size: size, maxPerLine: size + 2) {
                    let allCover = base.coverIndices
                    guard allCover.count > size else { continue }
                    for cover in allCover.combinations(of: size) {
                        let fins = base.cells.filter { !cover.contains(base.coverIndex($0)) }
                        let finBox = Geometry.box(fins[0])
                        guard fins.allSatisfy({ Geometry.box($0) == finBox }) else { continue }
                        // Every base line keeps at least one candidate inside the cover.
                        let covered = base.baseHouses.allSatisfy { h in
                            Geometry.houses[h].contains { base.cells.contains($0) && cover.contains(base.coverIndex($0)) }
                        }
                        guard covered else { continue }
                        let eliminations = cover.map(base.coverHouse)
                            .flatMap { Geometry.houses[$0] }
                            .filter { board.has(digit, at: $0) && !base.cells.contains($0) && Geometry.box($0) == finBox }
                            .map { CellDigit(cell: $0, digit: digit) }
                        guard !eliminations.isEmpty else { continue }
                        return Step(
                            technique: id,
                            patternCells: base.cells,
                            patternCandidates: base.cells.map { CellDigit(cell: $0, digit: digit) },
                            eliminations: eliminations,
                            regions: (base.baseHouses + cover.map(base.coverHouse)).map(Region.init(house:)) + [.box(finBox)],
                            digits: [digit]
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

Run: `swift test --package-path SudokuCore --filter "FishTests|FinnedFishTests"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add finned X-Wing and finned Swordfish"
```

---

### Task 6: Simple coloring

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/Coloring.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/ColoringTests.swift`

**Interfaces:**
- Consumes: Task 1 board queries.
- Produces: `SimpleColoring()` — color wrap (a colour that sees itself is false) and color trap (a cell seeing both colours loses the digit).

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/ColoringTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct ColoringTests {
    @Test func colorWrap() throws {
        // Chain (0,0)A-(0,4)B-(4,4)A-(4,1)B-(1,1)A; (0,0) and (1,1) share box 0.
        // (2,2) keeps box 0 from being a strong link.
        let b = board(digit: 1, onlyIn: [rc(0, 0), rc(0, 4), rc(4, 4), rc(4, 1), rc(1, 1), rc(2, 2)])
        let step = try #require(SimpleColoring().find(in: b))
        #expect(step.technique == .simpleColoring)
        #expect(Set(step.eliminations) == Set([rc(0, 0), rc(1, 1), rc(4, 4)].map { CellDigit(cell: $0, digit: 1) }))
    }

    @Test func colorTrap() throws {
        // Chain (0,0)A -box0- (1,2)B -col2- (5,2)A -row5- (5,6)B; (0,6) sees A and B.
        // (0,3) and (8,6) stop row 0 and column 6 from being strong links.
        let b = board(digit: 1, onlyIn: [rc(0, 0), rc(1, 2), rc(5, 2), rc(5, 6), rc(0, 6), rc(0, 3), rc(8, 6)])
        let step = try #require(SimpleColoring().find(in: b))
        #expect(step.eliminations == [CellDigit(cell: rc(0, 6), digit: 1)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(SimpleColoring().find(in: emptyBoard()) == nil)
    }

    @Test func sound() {
        #expect(soundnessViolations(of: SimpleColoring(), seeds: 1...30).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter ColoringTests`
Expected: build FAILS with `cannot find 'SimpleColoring' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/Coloring.swift`:
```swift
/// Two-colours each cluster of strong links on a digit. Exactly one colour is true.
/// Wrap: a colour with two cells seeing each other is false everywhere.
/// Trap: a cell outside the cluster seeing both colours loses the digit.
public struct SimpleColoring: Technique {
    public init() {}
    public var id: TechniqueID { .simpleColoring }

    public func find(in board: Board) -> Step? {
        for digit in 1...9 {
            var links: [Int: [Int]] = [:]
            for pair in board.conjugatePairs(of: digit) {
                links[pair.a, default: []].append(pair.b)
                links[pair.b, default: []].append(pair.a)
            }
            var color: [Int: Int] = [:]
            for start in links.keys.sorted() where color[start] == nil {
                var cluster = [start]
                var queue = [start]
                var consistent = true
                color[start] = 0
                while let cell = queue.popLast() {
                    for next in links[cell, default: []] {
                        if let existing = color[next] {
                            if existing == color[cell] { consistent = false }
                        } else {
                            color[next] = 1 - color[cell]!
                            cluster.append(next)
                            queue.append(next)
                        }
                    }
                }
                // An odd cycle only happens on an inconsistent board; skip it.
                guard consistent else { continue }
                cluster.sort()
                let groups = [0, 1].map { k in cluster.filter { color[$0] == k } }

                func step(_ eliminations: [CellDigit]) -> Step {
                    Step(
                        technique: id,
                        patternCells: cluster,
                        patternCandidates: cluster.map { CellDigit(cell: $0, digit: digit) },
                        eliminations: eliminations,
                        digits: [digit]
                    )
                }

                for group in groups where group.combinations(of: 2).contains(where: { Geometry.sees($0[0], $0[1]) }) {
                    return step(group.map { CellDigit(cell: $0, digit: digit) })
                }
                let trapped = (0..<81).filter { c in
                    board.has(digit, at: c) && !cluster.contains(c)
                        && groups[0].contains { Geometry.sees($0, c) }
                        && groups[1].contains { Geometry.sees($0, c) }
                }
                if !trapped.isEmpty {
                    return step(trapped.map { CellDigit(cell: $0, digit: digit) })
                }
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter ColoringTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add simple coloring"
```

---

### Task 7: Unique rectangles (types 1–4)

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/UniqueRectangles.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/UniqueRectangleTests.swift`

**Interfaces:**
- Consumes: Task 1 board queries.
- Produces: `UniqueRectangle(type: 1...4)` (ids `.uniqueRectangle1` … `.uniqueRectangle4`).

Rectangle: rows r1<r2, columns c1<c2, exactly two boxes, all four corners unsolved, all holding a and b. Floor = corners whose candidates are exactly {a,b}; roof = the rest.
- Type 1: three floor cells → remove a and b from the roof cell.
- Types 2–4 need two floor cells sharing a row or column (so the roof cells share the opposite line).
  - Type 2: the roof's extra candidates are a single digit z → remove z from cells seeing both roof cells.
  - Type 3: the roof's extras E act as one virtual cell; in a house both roof cells share, k other cells (1–3) whose candidates together with E make k+1 digits form a naked subset → remove those digits from the house's remaining cells.
  - Type 4: in a house both roof cells share, a or b appears only in the roof cells → remove the other digit from both roof cells.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/UniqueRectangleTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct UniqueRectangleTests {
    func rectangle(roof1: [Int], roof2: [Int]) -> Board {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([1, 2])
        b.candidates[rc(1, 0)] = CandidateSet([1, 2])
        b.candidates[rc(0, 3)] = CandidateSet(roof1)
        b.candidates[rc(1, 3)] = CandidateSet(roof2)
        return b
    }

    @Test func type1() throws {
        let b = rectangle(roof1: [1, 2], roof2: [1, 2, 5, 7])
        let step = try #require(UniqueRectangle(type: 1).find(in: b))
        #expect(step.technique == .uniqueRectangle1)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(1, 3), digit: 1), CellDigit(cell: rc(1, 3), digit: 2)])
        #expect(step.digits == [1, 2])
    }

    @Test func type2() throws {
        let b = rectangle(roof1: [1, 2, 6], roof2: [1, 2, 6])
        let step = try #require(UniqueRectangle(type: 2).find(in: b))
        #expect(step.technique == .uniqueRectangle2)
        #expect(step.eliminations.count == 13)   // rest of column 3 (7) + rest of box 1 off column 3 (6)
        #expect(step.eliminations.allSatisfy { $0.digit == 6 })
    }

    @Test func type3() throws {
        var b = rectangle(roof1: [1, 2, 3], roof2: [1, 2, 4])
        b.candidates[rc(5, 3)] = CandidateSet([3, 4])
        let step = try #require(UniqueRectangle(type: 3).find(in: b))
        #expect(step.technique == .uniqueRectangle3)
        let others = [2, 3, 4, 6, 7, 8].map { rc($0, 3) }
        #expect(Set(step.eliminations) == Set(others.flatMap { [CellDigit(cell: $0, digit: 3), CellDigit(cell: $0, digit: 4)] }))
    }

    @Test func type4() throws {
        var b = rectangle(roof1: [1, 2, 6, 7], roof2: [1, 2, 6, 7])
        for row in 2..<9 { b.eliminate(1, at: rc(row, 3)) }   // 1 only in the roof within column 3
        let step = try #require(UniqueRectangle(type: 4).find(in: b))
        #expect(step.technique == .uniqueRectangle4)
        #expect(Set(step.eliminations) == [CellDigit(cell: rc(0, 3), digit: 2), CellDigit(cell: rc(1, 3), digit: 2)])
    }

    @Test func solvedCornerIsNotARectangle() {
        var b = rectangle(roof1: [1, 2], roof2: [1, 2, 5, 7])
        b.place(1, at: rc(0, 3))
        #expect(UniqueRectangle(type: 1).find(in: b) == nil)
    }

    @Test(arguments: 1...4)
    func sound(type: Int) {
        #expect(soundnessViolations(of: UniqueRectangle(type: type), seeds: 1...30).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter UniqueRectangleTests`
Expected: build FAILS with `cannot find 'UniqueRectangle' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/UniqueRectangles.swift`:
```swift
/// Avoids the "deadly pattern": four unsolved cells in two rows, two columns and two boxes
/// that could swap a and b would give the puzzle two solutions, which a valid puzzle can't have.
public struct UniqueRectangle: Technique {
    public let type: Int

    public init(type: Int) {
        precondition((1...4).contains(type), "Unique rectangle type must be 1–4")
        self.type = type
    }

    public var id: TechniqueID {
        [TechniqueID.uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle3, .uniqueRectangle4][type - 1]
    }

    public func find(in board: Board) -> Step? {
        for rows in Array(0..<9).combinations(of: 2) {
            for cols in Array(0..<9).combinations(of: 2) {
                let corners = [
                    Geometry.cell(rows[0], cols[0]), Geometry.cell(rows[0], cols[1]),
                    Geometry.cell(rows[1], cols[0]), Geometry.cell(rows[1], cols[1]),
                ]
                guard Set(corners.map(Geometry.box)).count == 2,
                      corners.allSatisfy({ board.values[$0] == 0 }) else { continue }
                let common = corners.reduce(CandidateSet.all) { $0.intersection(board.candidates[$1]) }
                for pair in common.digits.combinations(of: 2) {
                    let ab = CandidateSet(pair)
                    let regions: [Region] = [.row(rows[0]), .row(rows[1]), .column(cols[0]), .column(cols[1])]
                    if let step = step(board: board, corners: corners, ab: ab, regions: regions) { return step }
                }
            }
        }
        return nil
    }

    private func step(board: Board, corners: [Int], ab: CandidateSet, regions: [Region]) -> Step? {
        let floor = corners.filter { board.candidates[$0] == ab }
        let roof = corners.filter { board.candidates[$0] != ab }

        func make(_ eliminations: [CellDigit]) -> Step? {
            guard !eliminations.isEmpty else { return nil }
            return Step(
                technique: id,
                patternCells: corners,
                patternCandidates: corners.flatMap { c in ab.digits.map { CellDigit(cell: c, digit: $0) } },
                eliminations: eliminations,
                regions: regions,
                digits: ab.digits
            )
        }

        if type == 1 {
            guard floor.count == 3 else { return nil }
            return make(ab.digits.map { CellDigit(cell: roof[0], digit: $0) })
        }

        guard floor.count == 2,
              Geometry.row(floor[0]) == Geometry.row(floor[1]) || Geometry.col(floor[0]) == Geometry.col(floor[1])
        else { return nil }
        let extras = roof.reduce(CandidateSet.empty) { $0.union(board.candidates[$1].subtracting(ab)) }
        let sharedHouses = Geometry.houses.indices.filter { h in roof.allSatisfy { Geometry.houses[h].contains($0) } }

        switch type {
        case 2:
            guard let z = extras.single else { return nil }
            return make(board.eliminations(of: z, seeingAll: roof, excluding: corners))
        case 3:
            for h in sharedHouses {
                let others = Geometry.houses[h].filter { board.values[$0] == 0 && !roof.contains($0) }
                for k in 1...3 {
                    for combo in others.combinations(of: k) {
                        let union = combo.reduce(extras) { $0.union(board.candidates[$1]) }
                        guard union.count == k + 1 else { continue }
                        let eliminations = others.filter { !combo.contains($0) }.flatMap { c in
                            board.candidates[c].intersection(union).digits.map { CellDigit(cell: c, digit: $0) }
                        }
                        if let step = make(eliminations) { return step }
                    }
                }
            }
            return nil
        default:
            let (a, b) = (ab.digits[0], ab.digits[1])
            for h in sharedHouses {
                for (kept, removed) in [(a, b), (b, a)] where board.cells(with: kept, in: Geometry.houses[h]) == roof {
                    if let step = make(roof.map { CellDigit(cell: $0, digit: removed) }) { return step }
                }
            }
            return nil
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter UniqueRectangleTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add unique rectangles types 1-4"
```

---

### Task 8: Catalog, generator and CLI reach Fiendish

**Files:**
- Modify: `SudokuCore/Sources/SudokuCore/Solvers/Technique.swift` (catalog)
- Modify: `SudokuCore/Tests/SudokuCoreTests/LogicalSolverTests.swift`
- Modify: `SudokuCore/Tests/SudokuCoreTests/ClassicGeneratorTests.swift`

**Interfaces:**
- Consumes: every technique from Tasks 2–7.
- Produces: `TechniqueCatalog.classic` covering every `TechniqueID`, ordered easiest first; `LogicalSolver.classic.maxTier == .fiendish`.

- [ ] **Step 1: Update the failing tests**

In `SudokuCore/Tests/SudokuCoreTests/LogicalSolverTests.swift`, replace `maxTierOfClassicCatalog` with:
```swift
    @Test func maxTierOfClassicCatalog() {
        #expect(LogicalSolver.classic.maxTier == .fiendish)
    }

    @Test func catalogCoversEveryTechniqueOnceInTierOrder() {
        let ids = TechniqueCatalog.classic.map(\.id)
        #expect(ids.count == TechniqueID.allCases.count)
        #expect(Set(ids) == Set(TechniqueID.allCases))
        #expect(ids.map(\.tier) == ids.map(\.tier).sorted())
    }
```

In `SudokuCore/Tests/SudokuCoreTests/ClassicGeneratorTests.swift`, change the tier arguments to `[Tier.easy, .medium, .hard, .expert, .fiendish]` and, in `unsupportedTierReturnsNilImmediately`, replace `.expert` with `.diabolical`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter "LogicalSolverTests|ClassicGeneratorTests"`
Expected: FAIL — `maxTier` is `.hard`, catalog has 11 of 27 techniques, and Expert/Fiendish generation returns nil immediately.

- [ ] **Step 3: Extend the catalog**

Replace the `TechniqueCatalog` enum in `SudokuCore/Sources/SudokuCore/Solvers/Technique.swift` with:
```swift
public enum TechniqueCatalog {
    /// Classic techniques in the order the solver tries them (easiest first, then by weight).
    public static let classic: [any Technique] = [
        // Easy
        FullHouse(),
        NakedSingle(),
        HiddenSingle(),
        // Medium
        Pointing(),
        BoxLineReduction(),
        NakedSubset(size: 2),
        HiddenSubset(size: 2),
        // Hard
        NakedSubset(size: 3),
        HiddenSubset(size: 3),
        NakedSubset(size: 4),
        HiddenSubset(size: 4),
        // Expert
        BasicFish(size: 2),
        UniqueRectangle(type: 1),
        Skyscraper(),
        TwoStringKite(),
        XYWing(),
        BasicFish(size: 3),
        // Fiendish
        EmptyRectangle(),
        XYZWing(),
        WWing(),
        UniqueRectangle(type: 2),
        UniqueRectangle(type: 4),
        UniqueRectangle(type: 3),
        FinnedFish(size: 2),
        SimpleColoring(),
        FinnedFish(size: 3),
        BasicFish(size: 4),
    ]
}
```

- [ ] **Step 4: Run the whole suite**

Run: `swift test --package-path SudokuCore`
Expected: PASS, including `everyCatalogTechniqueIsSound` over the full catalog, `stuckPuzzleHasNoGrade` (Inkala still needs chains), and Expert/Fiendish generation. Note the generator test's duration in the output; if the Fiendish case exceeds 60 s in debug, record a ruling and move it behind a release-only check rather than weakening the tier assertion.

- [ ] **Step 5: Generate a Fiendish sample with the CLI**

Run:
```bash
swift build --package-path SudokuCore -c release
SudokuCore/.build/release/sudoku-forge --tier fiendish --count 3 --seed 1 --out "$TMPDIR/fiendish.json"
SudokuCore/.build/release/sudoku-forge --tier diabolical --out x.json; echo "exit=$?"
```
Expected: three `[n/3] score …` lines whose technique lists include at least one Fiendish technique; then `tier diabolical is not supported yet (max: fiendish)` and `exit=1`.

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): grade and generate Expert and Fiendish puzzles"
```
