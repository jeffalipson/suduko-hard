# SudokuCore Foundation Implementation Plan (Plan 1 of 6)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `SudokuCore` Swift package — board model, brute-force uniqueness solver, technique-based logical solver with Easy–Hard classic techniques, grader, grade-preserving transforms, classic generator — plus the `sudoku-forge` CLI that writes graded puzzle libraries to JSON.

**Architecture:** A UI-free Swift package. `Board` holds values plus `UInt16` candidate bitmasks. Each human technique is a type conforming to `Technique` that returns a `Step` (pattern, placements, eliminations, regions). `LogicalSolver` applies the easiest available step repeatedly; `Grader` turns the step list into a tier/score. `ClassicGenerator` removes clues symmetrically while preserving uniqueness and staying at or below the target tier. The CLI is a thin wrapper over the generator.

**Tech Stack:** Swift 6.2 (language mode 6), Swift Package Manager, Swift Testing (`import Testing`), Foundation (CLI only). macOS 14+/iOS 17+.

**Spec:** `docs/superpowers/specs/2026-10-10-hard-sudoku-design.md`

## Roadmap (this plan is 1 of 6)

The spec covers several independent subsystems, so it is split into plans, each producing working, tested software:

1. **SudokuCore foundation** (this plan): model, solvers, Easy–Hard classic techniques, grading, transforms, classic generator, `sudoku-forge`.
2. **Advanced classic techniques**: Expert → Nightmare (fish, wings, coloring, UR, chains, ALS, forcing chains); generator symmetry relaxation.
3. **Killer engine**: cage-aware brute force, cage techniques & 45-rule, Killer generator, forge support.
4. **iOS app**: Xcode project, game screen, settings, autosave/undo, bundled library, queue manager + BGProcessingTask.
5. **Hints & lessons**: board diagnosis, Nudge/Spotlight/Lesson modal/Show me, lesson content.
6. **Stats**: SwiftData records, stats page, charts.

## Global Constraints

- iOS 17+ / macOS 14+, Swift 6 language mode, no third-party dependencies.
- `SudokuCore` contains no UI code and no Foundation-only APIs except where noted (CLI target may use Foundation).
- Tiers: `easy, medium, hard, expert, fiendish, diabolical, nightmare`.
- Every generated puzzle has exactly one solution and is solved by the LogicalSolver without guessing.
- Tier = tier of the hardest technique the LogicalSolver used.
- Library files are JSON arrays of `Puzzle`; `givens`/`solution` encoded as 81-character digit strings (`0` = empty).
- Transforms must preserve validity, uniqueness and grade; Killer puzzles (non-empty cages) must not relabel digits.
- Cell indices are `0..<81`, row-major (`cell = row * 9 + col`). Houses: indices 0–8 rows, 9–17 columns, 18–26 boxes.

## Review Focus

1. **Malformed puzzle text** (wrong length, stray characters) → `Board.parse` returns nil; never crashes. Test in Task 2.
2. **Contradictory or multi-solution givens** → `Grader.grade` returns nil (no crash, no infinite loop). Tests in Task 7.
3. **Requesting a tier the solver can't produce yet** (Expert+ in this plan) → generator returns nil immediately; CLI exits 1 with a clear message. Tests in Task 9, manual check in Task 10.
4. **Transforms applied to Killer cages** → cells remap, sums unchanged, digits not relabelled. Tests in Task 8.
5. **Corrupt library JSON** (bad givens string) → decoding throws rather than producing a broken puzzle. Test in Task 7.

## File Structure

```
SudokuCore/
├── Package.swift
├── Sources/
│   ├── SudokuCore/
│   │   ├── Model/
│   │   │   ├── CandidateSet.swift     — bitmask set of digits 1–9
│   │   │   ├── Geometry.swift         — rows/cols/boxes/houses/peers, Region
│   │   │   ├── Tier.swift             — Tier, Mode
│   │   │   ├── TechniqueID.swift      — technique identifiers, tier, weight, name
│   │   │   ├── Cage.swift             — Killer cage
│   │   │   ├── Step.swift             — CellDigit, Step
│   │   │   ├── Board.swift            — values, givens, candidates, parsing, mutation
│   │   │   └── Puzzle.swift           — Grade, Puzzle (Codable)
│   │   ├── Solvers/
│   │   │   ├── BruteForceSolver.swift — uniqueness / solution / random full grid
│   │   │   ├── Technique.swift        — Technique protocol, TechniqueCatalog
│   │   │   ├── LogicalSolver.swift    — easiest-first stepping solver
│   │   │   └── Grader.swift           — GradeReport, Grader
│   │   ├── Techniques/
│   │   │   ├── Singles.swift          — FullHouse, NakedSingle, HiddenSingle
│   │   │   ├── Intersections.swift    — Pointing, BoxLineReduction
│   │   │   └── Subsets.swift          — NakedSubset, HiddenSubset
│   │   ├── Generation/
│   │   │   ├── SplitMix64.swift       — seedable RNG
│   │   │   ├── GridTransform.swift    — randomising transforms
│   │   │   └── ClassicGenerator.swift
│   │   └── Support/
│   │       └── Combinations.swift
│   └── sudoku-forge/
│       └── main.swift
└── Tests/SudokuCoreTests/
    ├── TestSupport.swift
    ├── CandidateSetTests.swift
    ├── GeometryTests.swift
    ├── BoardTests.swift
    ├── BruteForceSolverTests.swift
    ├── SinglesTests.swift
    ├── IntersectionsTests.swift
    ├── SubsetsTests.swift
    ├── LogicalSolverTests.swift
    ├── PuzzleCodingTests.swift
    ├── GridTransformTests.swift
    └── ClassicGeneratorTests.swift
```

All commands run from the repository root `/Users/jeffreylipson/suduko-hard`.

---

### Task 1: Package scaffold, CandidateSet, Geometry

**Files:**
- Create: `SudokuCore/Package.swift`, `.gitignore`
- Create: `SudokuCore/Sources/SudokuCore/Model/CandidateSet.swift`
- Create: `SudokuCore/Sources/SudokuCore/Model/Geometry.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/CandidateSetTests.swift`, `SudokuCore/Tests/SudokuCoreTests/GeometryTests.swift`

**Interfaces:**
- Produces: `CandidateSet` (`raw`, `init(raw:)`, `init(_ digits:)`, `.all`, `.empty`, `count`, `isEmpty`, `digits`, `single`, `contains`, `insert`, `remove`, `union`, `intersection`, `subtracting`); `Geometry` (`row`, `col`, `box`, `cell(_:_:)`, `rows`, `cols`, `boxes`, `houses`, `peers`, `sees`); `Region` (`.row/.column/.box`, `init(house:)`, `cells`).

- [ ] **Step 1: Create the package manifest and .gitignore**

`SudokuCore/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"]),
    ],
    targets: [
        .target(name: "SudokuCore"),
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
    ]
)
```

`.gitignore` (repo root):
```
.build/
.swiftpm/
DerivedData/
xcuserdata/
.DS_Store
```

- [ ] **Step 2: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/CandidateSetTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct CandidateSetTests {
    @Test func insertRemoveContains() {
        var s = CandidateSet.empty
        s.insert(3)
        s.insert(9)
        #expect(s.contains(3))
        #expect(s.contains(9))
        #expect(!s.contains(1))
        #expect(s.count == 2)
        s.remove(3)
        #expect(s.digits == [9])
        #expect(s.single == 9)
    }

    @Test func allHasNineDigits() {
        #expect(CandidateSet.all.digits == Array(1...9))
        #expect(CandidateSet.all.single == nil)
        #expect(CandidateSet.empty.isEmpty)
    }

    @Test func setAlgebra() {
        let a = CandidateSet([1, 2, 3])
        let b = CandidateSet([2, 3, 4])
        #expect(a.union(b).digits == [1, 2, 3, 4])
        #expect(a.intersection(b).digits == [2, 3])
        #expect(a.subtracting(b).digits == [1])
    }

    @Test func rawInitIgnoresBitsOutsideOneToNine() {
        #expect(CandidateSet(raw: 0xFFFF).digits == Array(1...9))
    }
}
```

`SudokuCore/Tests/SudokuCoreTests/GeometryTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct GeometryTests {
    @Test func rowColBox() {
        #expect(Geometry.row(40) == 4)
        #expect(Geometry.col(40) == 4)
        #expect(Geometry.box(0) == 0)
        #expect(Geometry.box(Geometry.cell(4, 4)) == 4)
        #expect(Geometry.box(Geometry.cell(2, 6)) == 2)
        #expect(Geometry.box(80) == 8)
    }

    @Test func housesCoverEveryCellThreeTimes() {
        var counts = [Int](repeating: 0, count: 81)
        for house in Geometry.houses { for c in house { counts[c] += 1 } }
        #expect(Geometry.houses.count == 27)
        #expect(counts.allSatisfy { $0 == 3 })
    }

    @Test func everyCellHasTwentyPeers() {
        #expect(Geometry.peers.allSatisfy { $0.count == 20 })
        #expect(Geometry.sees(0, 8))
        #expect(Geometry.sees(0, 20))
        #expect(!Geometry.sees(0, 40))
        #expect(!Geometry.sees(5, 5))
    }

    @Test func regionFromHouse() {
        #expect(Region(house: 0) == .row(0))
        #expect(Region(house: 10) == .column(1))
        #expect(Region(house: 26) == .box(8))
        #expect(Region.box(4).cells == Geometry.boxes[4])
        #expect(Region.column(2).cells == Geometry.cols[2])
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore`
Expected: build FAILS with errors such as `cannot find 'CandidateSet' in scope`.

- [ ] **Step 4: Implement CandidateSet**

`SudokuCore/Sources/SudokuCore/Model/CandidateSet.swift`:
```swift
/// A set of Sudoku digits 1...9 stored as a bitmask (bit d = digit d).
public struct CandidateSet: Hashable, Sendable, Codable, CustomStringConvertible {
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
```

- [ ] **Step 5: Implement Geometry and Region**

`SudokuCore/Sources/SudokuCore/Model/Geometry.swift`:
```swift
/// Static board geometry. Cells are 0..<81, row-major.
public enum Geometry {
    public static func row(_ cell: Int) -> Int { cell / 9 }
    public static func col(_ cell: Int) -> Int { cell % 9 }
    public static func box(_ cell: Int) -> Int { (cell / 27) * 3 + (cell % 9) / 3 }
    public static func cell(_ row: Int, _ col: Int) -> Int { row * 9 + col }

    public static let rows: [[Int]] = (0..<9).map { r in (0..<9).map { r * 9 + $0 } }
    public static let cols: [[Int]] = (0..<9).map { c in (0..<9).map { $0 * 9 + c } }
    public static let boxes: [[Int]] = (0..<9).map { b in
        let r0 = (b / 3) * 3, c0 = (b % 3) * 3
        return (0..<9).map { (r0 + $0 / 3) * 9 + c0 + $0 % 3 }
    }

    /// All 27 houses: indices 0–8 are rows, 9–17 columns, 18–26 boxes.
    public static let houses: [[Int]] = rows + cols + boxes

    public static let peers: [[Int]] = (0..<81).map { c in
        Set(rows[row(c)] + cols[col(c)] + boxes[box(c)]).subtracting([c]).sorted()
    }

    /// True when two different cells share a row, column or box.
    public static func sees(_ a: Int, _ b: Int) -> Bool {
        a != b && (row(a) == row(b) || col(a) == col(b) || box(a) == box(b))
    }
}

public enum Region: Hashable, Sendable, Codable {
    case row(Int)
    case column(Int)
    case box(Int)

    /// Maps a `Geometry.houses` index to its region.
    public init(house: Int) {
        switch house {
        case 0..<9: self = .row(house)
        case 9..<18: self = .column(house - 9)
        default: self = .box(house - 18)
        }
    }

    public var cells: [Int] {
        switch self {
        case .row(let i): return Geometry.rows[i]
        case .column(let i): return Geometry.cols[i]
        case .box(let i): return Geometry.boxes[i]
        }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore`
Expected: PASS — all `CandidateSetTests` and `GeometryTests` tests pass.

- [ ] **Step 7: Commit**

```bash
git add .gitignore SudokuCore
git commit -m "feat(core): add package scaffold, CandidateSet and Geometry"
```

---

### Task 2: Board model, Tier/Mode, TechniqueID, Cage, Step

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Model/Tier.swift`
- Create: `SudokuCore/Sources/SudokuCore/Model/TechniqueID.swift`
- Create: `SudokuCore/Sources/SudokuCore/Model/Cage.swift`
- Create: `SudokuCore/Sources/SudokuCore/Model/Step.swift`
- Create: `SudokuCore/Sources/SudokuCore/Model/Board.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/TestSupport.swift`, `SudokuCore/Tests/SudokuCoreTests/BoardTests.swift`

**Interfaces:**
- Consumes: `CandidateSet`, `Geometry`, `Region` (Task 1).
- Produces:
  - `enum Tier: Int, Codable, CaseIterable, Comparable, Sendable` — `easy...nightmare`, `name: String`, `init?(name:)`.
  - `enum Mode: String, Codable, CaseIterable, Sendable` — `classic`, `killer`.
  - `enum TechniqueID: String, Codable, CaseIterable, Sendable` — `fullHouse, nakedSingle, hiddenSingle, pointing, boxLineReduction, nakedPair, hiddenPair, nakedTriple, hiddenTriple, nakedQuad, hiddenQuad`; `tier: Tier`, `weight: Int`, `displayName: String`.
  - `struct Cage: Hashable, Sendable, Codable { cells: [Int]; sum: Int }`.
  - `struct CellDigit: Hashable, Sendable, Codable { cell: Int; digit: Int }`.
  - `struct Step: Hashable, Sendable` — `technique, patternCells, patternCandidates, placements, eliminations, regions, digits`; memberwise init with defaults for all but `technique`.
  - `struct Board: Hashable, Sendable` — `values: [Int]` (read-only outside), `givens: [Bool]`, `candidates: [CandidateSet]`, `cages: [Cage]`; `init(values:cages:)`, `init?(string:cages:)`, `static parse(_:) -> [Int]?`, `string`, `isSolved`, `place(_:at:)`, `eliminate(_:at:)`, `apply(_ step:)`.
  - Test helpers: `wikiPuzzle`, `wikiSolution`, `inkalaPuzzle` (strings), `emptyBoard()`, `isValidSolution(_:)`.

- [ ] **Step 1: Write the test support file and failing tests**

`SudokuCore/Tests/SudokuCoreTests/TestSupport.swift`:
```swift
import SudokuCore

/// Wikipedia's example puzzle; solvable with singles only.
let wikiPuzzle = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
let wikiSolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
/// Arto Inkala's "world's hardest sudoku"; unique, needs far more than Hard-tier techniques.
let inkalaPuzzle = "800000000003600000070090200050007000000045700000100030001000068008500010090000400"

func emptyBoard() -> Board { Board(values: Array(repeating: 0, count: 81)) }

func values(_ s: String) -> [Int] { Board.parse(s)! }

func isValidSolution(_ v: [Int]) -> Bool {
    v.count == 81 && Geometry.houses.allSatisfy { house in Set(house.map { v[$0] }) == Set(1...9) }
}
```

`SudokuCore/Tests/SudokuCoreTests/BoardTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct BoardTests {
    @Test func parsesAndRoundTrips() throws {
        let board = try #require(Board(string: wikiPuzzle))
        #expect(board.values[0] == 5)
        #expect(board.values[2] == 0)
        #expect(board.givens[0])
        #expect(!board.givens[2])
        #expect(board.string == wikiPuzzle.replacing("0", with: "."))
        #expect(Board(string: board.string)?.values == board.values)
    }

    @Test func computesCandidatesFromGivens() throws {
        let board = try #require(Board(string: wikiPuzzle))
        #expect(board.candidates[2].digits == [1, 2, 4])
        #expect(board.candidates[0].isEmpty)
    }

    @Test(arguments: [
        String(repeating: "0", count: 80),
        String(repeating: "0", count: 82),
        "x" + String(repeating: "0", count: 80),
        "",
    ])
    func rejectsMalformedText(_ text: String) {
        #expect(Board.parse(text) == nil)
        #expect(Board(string: text) == nil)
    }

    @Test func placeUpdatesPeers() {
        var board = emptyBoard()
        board.place(5, at: 0)
        #expect(board.values[0] == 5)
        #expect(board.candidates[0].isEmpty)
        #expect(!board.candidates[1].contains(5))   // same row
        #expect(!board.candidates[9].contains(5))   // same column
        #expect(!board.candidates[20].contains(5))  // same box
        #expect(board.candidates[80].contains(5))   // unrelated
        #expect(!board.givens[0])
    }

    @Test func applyStep() {
        var board = emptyBoard()
        let step = Step(
            technique: .nakedSingle,
            placements: [CellDigit(cell: 0, digit: 1)],
            eliminations: [CellDigit(cell: 40, digit: 9)]
        )
        board.apply(step)
        #expect(board.values[0] == 1)
        #expect(!board.candidates[40].contains(9))
        #expect(!board.isSolved)
    }

    @Test func tierNamesAndOrder() {
        #expect(Tier(name: "Nightmare") == .nightmare)
        #expect(Tier(name: "bogus") == nil)
        #expect(Tier.easy < Tier.hard)
        #expect(TechniqueID.nakedPair.tier == .medium)
        #expect(TechniqueID.hiddenQuad.tier == .hard)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore`
Expected: build FAILS with `cannot find 'Board' in scope`.

- [ ] **Step 3: Implement Tier and Mode**

`SudokuCore/Sources/SudokuCore/Model/Tier.swift`:
```swift
public enum Tier: Int, Codable, CaseIterable, Comparable, Sendable {
    case easy, medium, hard, expert, fiendish, diabolical, nightmare

    public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

    public var name: String { String(describing: self) }

    /// Case-insensitive lookup, e.g. "Nightmare" → `.nightmare`.
    public init?(name: String) {
        guard let tier = Tier.allCases.first(where: { $0.name == name.lowercased() }) else { return nil }
        self = tier
    }
}

public enum Mode: String, Codable, CaseIterable, Sendable {
    case classic, killer
}
```

- [ ] **Step 4: Implement TechniqueID**

`SudokuCore/Sources/SudokuCore/Model/TechniqueID.swift`:
```swift
/// Every technique the engine knows. Later plans append cases.
public enum TechniqueID: String, Codable, CaseIterable, Sendable {
    case fullHouse, nakedSingle, hiddenSingle
    case pointing, boxLineReduction, nakedPair, hiddenPair
    case nakedTriple, hiddenTriple, nakedQuad, hiddenQuad

    public var tier: Tier {
        switch self {
        case .fullHouse, .nakedSingle, .hiddenSingle:
            return .easy
        case .pointing, .boxLineReduction, .nakedPair, .hiddenPair:
            return .medium
        case .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad:
            return .hard
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
        }
    }
}
```

- [ ] **Step 5: Implement Cage and Step**

`SudokuCore/Sources/SudokuCore/Model/Cage.swift`:
```swift
/// A Killer Sudoku cage: its cells sum to `sum` and contain no repeated digit.
public struct Cage: Hashable, Sendable, Codable {
    public var cells: [Int]
    public var sum: Int

    public init(cells: [Int], sum: Int) {
        self.cells = cells
        self.sum = sum
    }
}
```

`SudokuCore/Sources/SudokuCore/Model/Step.swift`:
```swift
public struct CellDigit: Hashable, Sendable, Codable {
    public let cell: Int
    public let digit: Int

    public init(cell: Int, digit: Int) {
        self.cell = cell
        self.digit = digit
    }
}

/// One logical deduction. Drives grading, hints, Spotlight and "Show me".
public struct Step: Hashable, Sendable {
    public let technique: TechniqueID
    /// Cells forming the pattern (highlighted by Spotlight).
    public let patternCells: [Int]
    /// Candidates forming the pattern.
    public let patternCandidates: [CellDigit]
    public let placements: [CellDigit]
    public let eliminations: [CellDigit]
    /// Houses the pattern lives in, used for Nudge text ("in row 4").
    public let regions: [Region]
    /// Digits the pattern is about.
    public let digits: [Int]

    public init(
        technique: TechniqueID,
        patternCells: [Int] = [],
        patternCandidates: [CellDigit] = [],
        placements: [CellDigit] = [],
        eliminations: [CellDigit] = [],
        regions: [Region] = [],
        digits: [Int] = []
    ) {
        self.technique = technique
        self.patternCells = patternCells
        self.patternCandidates = patternCandidates
        self.placements = placements
        self.eliminations = eliminations
        self.regions = regions
        self.digits = digits
    }
}
```

- [ ] **Step 6: Implement Board**

`SudokuCore/Sources/SudokuCore/Model/Board.swift`:
```swift
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
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore`
Expected: PASS (all suites so far).

- [ ] **Step 8: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add Board, Tier, TechniqueID, Cage and Step models"
```

---

### Task 3: SplitMix64 and BruteForceSolver

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Generation/SplitMix64.swift`
- Create: `SudokuCore/Sources/SudokuCore/Solvers/BruteForceSolver.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/BruteForceSolverTests.swift`

**Interfaces:**
- Consumes: `Geometry` (Task 1), `Board.parse` (Task 2, tests only).
- Produces:
  - `struct SplitMix64: RandomNumberGenerator, Sendable` — `init(seed: UInt64)`.
  - `enum BruteForceSolver` — `static func countSolutions(_ values: [Int], limit: Int = 2) -> Int`, `static func solve(_ values: [Int]) -> [Int]?`, `static func randomSolution<R: RandomNumberGenerator>(using rng: inout R) -> [Int]`.

- [ ] **Step 1: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/BruteForceSolverTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct BruteForceSolverTests {
    @Test func solvesUniquePuzzle() {
        #expect(BruteForceSolver.countSolutions(values(wikiPuzzle)) == 1)
        #expect(BruteForceSolver.solve(values(wikiPuzzle)) == values(wikiSolution))
    }

    @Test func hardestKnownPuzzleIsUnique() {
        #expect(BruteForceSolver.countSolutions(values(inkalaPuzzle)) == 1)
    }

    @Test func emptyGridHasManySolutions() {
        let empty = Array(repeating: 0, count: 81)
        #expect(BruteForceSolver.countSolutions(empty, limit: 2) == 2)
    }

    @Test func conflictingGivensHaveNoSolution() {
        var v = Array(repeating: 0, count: 81)
        v[0] = 5
        v[1] = 5
        #expect(BruteForceSolver.countSolutions(v) == 0)
        #expect(BruteForceSolver.solve(v) == nil)
    }

    @Test func outOfRangeDigitHasNoSolution() {
        var v = Array(repeating: 0, count: 81)
        v[0] = 10
        #expect(BruteForceSolver.countSolutions(v) == 0)
    }

    @Test func randomSolutionsAreValidAndSeeded() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 1)
        var c = SplitMix64(seed: 2)
        let s1 = BruteForceSolver.randomSolution(using: &a)
        let s2 = BruteForceSolver.randomSolution(using: &b)
        let s3 = BruteForceSolver.randomSolution(using: &c)
        #expect(isValidSolution(s1))
        #expect(isValidSolution(s3))
        #expect(s1 == s2)
        #expect(s1 != s3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter BruteForceSolverTests`
Expected: build FAILS with `cannot find 'BruteForceSolver' in scope`.

- [ ] **Step 3: Implement SplitMix64**

`SudokuCore/Sources/SudokuCore/Generation/SplitMix64.swift`:
```swift
/// Small, fast, seedable RNG so generation is reproducible in tests and the CLI.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
```

- [ ] **Step 4: Implement BruteForceSolver**

`SudokuCore/Sources/SudokuCore/Solvers/BruteForceSolver.swift`:
```swift
/// Bitmask backtracking. Used only to prove uniqueness and to build random full grids — never for hints.
public enum BruteForceSolver {
    /// Counts solutions, stopping once `limit` is reached. Invalid givens → 0.
    public static func countSolutions(_ values: [Int], limit: Int = 2) -> Int {
        guard var state = SearchState(values) else { return 0 }
        var count = 0
        var first: [Int]?
        search(&state, limit: limit, count: &count, first: &first) { _ in }
        return count
    }

    /// The first solution found, or nil when there is none.
    public static func solve(_ values: [Int]) -> [Int]? {
        guard var state = SearchState(values) else { return nil }
        var count = 0
        var first: [Int]?
        search(&state, limit: 1, count: &count, first: &first) { _ in }
        return first
    }

    /// A uniformly shuffled complete valid grid.
    public static func randomSolution<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        var state = SearchState(Array(repeating: 0, count: 81))!
        var count = 0
        var first: [Int]?
        search(&state, limit: 1, count: &count, first: &first) { $0.shuffle(using: &rng) }
        return first!
    }

    private static func search(
        _ s: inout SearchState,
        limit: Int,
        count: inout Int,
        first: inout [Int]?,
        order: (inout [Int]) -> Void
    ) {
        // Pick the empty cell with the fewest options.
        var best = -1
        var bestMask: UInt16 = 0
        var bestCount = 10
        for c in 0..<81 where s.grid[c] == 0 {
            let mask = s.available(c)
            let n = mask.nonzeroBitCount
            if n == 0 { return }
            if n < bestCount {
                best = c
                bestMask = mask
                bestCount = n
                if n == 1 { break }
            }
        }
        if best < 0 {
            count += 1
            if first == nil { first = s.grid }
            return
        }
        var digits = (1...9).filter { bestMask & (1 << $0) != 0 }
        order(&digits)
        for d in digits {
            s.set(best, d)
            search(&s, limit: limit, count: &count, first: &first, order: order)
            s.unset(best, d)
            if count >= limit { return }
        }
    }
}

private struct SearchState {
    var grid: [Int]
    var rowUsed = [UInt16](repeating: 0, count: 9)
    var colUsed = [UInt16](repeating: 0, count: 9)
    var boxUsed = [UInt16](repeating: 0, count: 9)

    /// Nil when the givens are malformed or already conflict.
    init?(_ values: [Int]) {
        guard values.count == 81 else { return nil }
        grid = Array(repeating: 0, count: 81)
        for c in 0..<81 where values[c] != 0 {
            let d = values[c]
            guard (1...9).contains(d), available(c) & (1 << d) != 0 else { return nil }
            set(c, d)
        }
    }

    func available(_ c: Int) -> UInt16 {
        ~(rowUsed[Geometry.row(c)] | colUsed[Geometry.col(c)] | boxUsed[Geometry.box(c)]) & 0b11_1111_1110
    }

    mutating func set(_ c: Int, _ d: Int) {
        grid[c] = d
        let bit: UInt16 = 1 << d
        rowUsed[Geometry.row(c)] |= bit
        colUsed[Geometry.col(c)] |= bit
        boxUsed[Geometry.box(c)] |= bit
    }

    mutating func unset(_ c: Int, _ d: Int) {
        grid[c] = 0
        let mask: UInt16 = ~(1 << d)
        rowUsed[Geometry.row(c)] &= mask
        colUsed[Geometry.col(c)] &= mask
        boxUsed[Geometry.box(c)] &= mask
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter BruteForceSolverTests`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add SplitMix64 and bitmask brute-force solver"
```

---

### Task 4: Technique protocol and singles

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Solvers/Technique.swift`
- Create: `SudokuCore/Sources/SudokuCore/Techniques/Singles.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/SinglesTests.swift`

**Interfaces:**
- Consumes: `Board`, `Step`, `CellDigit`, `Region`, `TechniqueID` (Task 2).
- Produces: `protocol Technique: Sendable { var id: TechniqueID { get }; func find(in board: Board) -> Step? }`; `FullHouse()`, `NakedSingle()`, `HiddenSingle()`.

Search order rules (tests depend on them): houses are scanned in `Geometry.houses` order (rows, then columns, then boxes); cells in ascending index; digits 1→9.

- [ ] **Step 1: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/SinglesTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct SinglesTests {
    @Test func fullHouseFillsLastCellOfRow() {
        var v = values(wikiSolution)
        v[0] = 0
        let step = FullHouse().find(in: Board(values: v))
        #expect(step?.technique == .fullHouse)
        #expect(step?.placements == [CellDigit(cell: 0, digit: 5)])
        #expect(step?.regions == [.row(0)])
    }

    @Test func nakedSingle() {
        var v = values(wikiSolution)
        for c in [0, 1, 9, 10] { v[c] = 0 }   // two empties per row/col: no full house
        let board = Board(values: v)
        #expect(FullHouse().find(in: board) == nil)
        let step = NakedSingle().find(in: board)
        #expect(step?.technique == .nakedSingle)
        #expect(step?.placements == [CellDigit(cell: 0, digit: 5)])
        #expect(step?.patternCells == [0])
    }

    @Test func hiddenSingleInRow() {
        var board = emptyBoard()
        for col in 0..<9 where col != 4 { board.eliminate(7, at: Geometry.cell(0, col)) }
        #expect(NakedSingle().find(in: board) == nil)
        let step = HiddenSingle().find(in: board)
        #expect(step?.technique == .hiddenSingle)
        #expect(step?.placements == [CellDigit(cell: 4, digit: 7)])
        #expect(step?.regions == [.row(0)])
        #expect(step?.digits == [7])
    }

    @Test func nothingOnEmptyBoard() {
        let board = emptyBoard()
        #expect(FullHouse().find(in: board) == nil)
        #expect(NakedSingle().find(in: board) == nil)
        #expect(HiddenSingle().find(in: board) == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter SinglesTests`
Expected: build FAILS with `cannot find 'FullHouse' in scope`.

- [ ] **Step 3: Implement the Technique protocol**

`SudokuCore/Sources/SudokuCore/Solvers/Technique.swift`:
```swift
/// A human solving technique. `find` returns the first instance on the board
/// that makes progress (at least one placement or elimination), or nil.
public protocol Technique: Sendable {
    var id: TechniqueID { get }
    func find(in board: Board) -> Step?
}
```

- [ ] **Step 4: Implement the singles**

`SudokuCore/Sources/SudokuCore/Techniques/Singles.swift`:
```swift
/// A house with exactly one empty cell.
public struct FullHouse: Technique {
    public init() {}
    public var id: TechniqueID { .fullHouse }

    public func find(in board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            let empty = house.filter { board.values[$0] == 0 }
            guard empty.count == 1, let digit = board.candidates[empty[0]].single else { continue }
            return Step(
                technique: id,
                patternCells: house,
                placements: [CellDigit(cell: empty[0], digit: digit)],
                regions: [Region(house: h)],
                digits: [digit]
            )
        }
        return nil
    }
}

/// A cell with exactly one candidate.
public struct NakedSingle: Technique {
    public init() {}
    public var id: TechniqueID { .nakedSingle }

    public func find(in board: Board) -> Step? {
        for c in 0..<81 where board.values[c] == 0 {
            guard let digit = board.candidates[c].single else { continue }
            return Step(
                technique: id,
                patternCells: [c],
                placements: [CellDigit(cell: c, digit: digit)],
                digits: [digit]
            )
        }
        return nil
    }
}

/// A digit with exactly one possible cell in a house.
public struct HiddenSingle: Technique {
    public init() {}
    public var id: TechniqueID { .hiddenSingle }

    public func find(in board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            for digit in 1...9 {
                var spot = -1
                var n = 0
                for c in house where board.values[c] == 0 && board.candidates[c].contains(digit) {
                    spot = c
                    n += 1
                }
                guard n == 1 else { continue }
                return Step(
                    technique: id,
                    patternCells: house,
                    placements: [CellDigit(cell: spot, digit: digit)],
                    regions: [Region(house: h)],
                    digits: [digit]
                )
            }
        }
        return nil
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter SinglesTests`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add Technique protocol and singles"
```

---

### Task 5: Intersections (Pointing, Box/Line Reduction)

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/Intersections.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/IntersectionsTests.swift`

**Interfaces:**
- Consumes: `Technique`, `Board`, `Step`, `Geometry`, `Region`.
- Produces: `Pointing()`, `BoxLineReduction()`.

- [ ] **Step 1: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/IntersectionsTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct IntersectionsTests {
    @Test func pointingPairInBoxClearsRow() throws {
        var board = emptyBoard()
        // In box 0, digit 5 survives only in row 0.
        for c in Geometry.boxes[0] where Geometry.row(c) != 0 { board.eliminate(5, at: c) }
        let step = try #require(Pointing().find(in: board))
        #expect(step.technique == .pointing)
        #expect(step.patternCells == [0, 1, 2])
        #expect(Set(step.eliminations) == Set((3..<9).map { CellDigit(cell: $0, digit: 5) }))
        #expect(step.regions == [.box(0), .row(0)])
        #expect(step.digits == [5])
    }

    @Test func boxLineReductionClearsBox() throws {
        var board = emptyBoard()
        // In row 0, digit 4 survives only in box 0.
        for col in 3..<9 { board.eliminate(4, at: Geometry.cell(0, col)) }
        let step = try #require(BoxLineReduction().find(in: board))
        #expect(step.technique == .boxLineReduction)
        #expect(step.patternCells == [0, 1, 2])
        #expect(Set(step.eliminations) == Set([9, 10, 11, 18, 19, 20].map { CellDigit(cell: $0, digit: 4) }))
        #expect(step.regions == [.row(0), .box(0)])
    }

    @Test func nothingOnEmptyBoard() {
        #expect(Pointing().find(in: emptyBoard()) == nil)
        #expect(BoxLineReduction().find(in: emptyBoard()) == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter IntersectionsTests`
Expected: build FAILS with `cannot find 'Pointing' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/Intersections.swift`:
```swift
/// A digit confined to one row/column inside a box: remove it from the rest of that line.
public struct Pointing: Technique {
    public init() {}
    public var id: TechniqueID { .pointing }

    public func find(in board: Board) -> Step? {
        for b in 0..<9 {
            for digit in 1...9 {
                let cells = Geometry.boxes[b].filter { board.values[$0] == 0 && board.candidates[$0].contains(digit) }
                guard cells.count >= 2 else { continue }
                let line: Int
                if Set(cells.map(Geometry.row)).count == 1 {
                    line = Geometry.row(cells[0])
                } else if Set(cells.map(Geometry.col)).count == 1 {
                    line = 9 + Geometry.col(cells[0])
                } else {
                    continue
                }
                let eliminations = Geometry.houses[line]
                    .filter { Geometry.box($0) != b && board.values[$0] == 0 && board.candidates[$0].contains(digit) }
                    .map { CellDigit(cell: $0, digit: digit) }
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: cells,
                    patternCandidates: cells.map { CellDigit(cell: $0, digit: digit) },
                    eliminations: eliminations,
                    regions: [.box(b), Region(house: line)],
                    digits: [digit]
                )
            }
        }
        return nil
    }
}

/// A digit confined to one box inside a row/column: remove it from the rest of that box.
public struct BoxLineReduction: Technique {
    public init() {}
    public var id: TechniqueID { .boxLineReduction }

    public func find(in board: Board) -> Step? {
        for line in 0..<18 {
            let house = Geometry.houses[line]
            for digit in 1...9 {
                let cells = house.filter { board.values[$0] == 0 && board.candidates[$0].contains(digit) }
                guard cells.count >= 2 else { continue }
                let b = Geometry.box(cells[0])
                guard cells.allSatisfy({ Geometry.box($0) == b }) else { continue }
                let eliminations = Geometry.boxes[b]
                    .filter { !house.contains($0) && board.values[$0] == 0 && board.candidates[$0].contains(digit) }
                    .map { CellDigit(cell: $0, digit: digit) }
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: cells,
                    patternCandidates: cells.map { CellDigit(cell: $0, digit: digit) },
                    eliminations: eliminations,
                    regions: [Region(house: line), .box(b)],
                    digits: [digit]
                )
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter IntersectionsTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add pointing and box/line reduction"
```

---

### Task 6: Naked and hidden subsets (pairs, triples, quads)

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Support/Combinations.swift`
- Create: `SudokuCore/Sources/SudokuCore/Techniques/Subsets.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/SubsetsTests.swift`

**Interfaces:**
- Consumes: `Technique`, `Board`, `Step`, `CandidateSet`, `Geometry`, `Region`.
- Produces: `NakedSubset(size: 2|3|4)` (ids `.nakedPair/.nakedTriple/.nakedQuad`), `HiddenSubset(size: 2|3|4)` (ids `.hiddenPair/.hiddenTriple/.hiddenQuad`); internal `Array.combinations(of:)`.

- [ ] **Step 1: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/SubsetsTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct SubsetsTests {
    @Test func nakedPair() throws {
        var board = emptyBoard()
        board.candidates[0] = CandidateSet([1, 2])
        board.candidates[1] = CandidateSet([1, 2])
        let step = try #require(NakedSubset(size: 2).find(in: board))
        #expect(step.technique == .nakedPair)
        #expect(step.patternCells == [0, 1])
        #expect(step.digits == [1, 2])
        #expect(step.regions == [.row(0)])
        let expected = (2..<9).flatMap { c in [CellDigit(cell: c, digit: 1), CellDigit(cell: c, digit: 2)] }
        #expect(Set(step.eliminations) == Set(expected))
    }

    @Test func nakedTriple() throws {
        var board = emptyBoard()
        board.candidates[0] = CandidateSet([1, 2])
        board.candidates[1] = CandidateSet([2, 3])
        board.candidates[2] = CandidateSet([1, 3])
        #expect(NakedSubset(size: 2).find(in: board) == nil)
        let step = try #require(NakedSubset(size: 3).find(in: board))
        #expect(step.technique == .nakedTriple)
        #expect(step.patternCells == [0, 1, 2])
        #expect(step.eliminations.count == 18)
        #expect(step.regions == [.row(0)])
    }

    @Test func hiddenPair() throws {
        var board = emptyBoard()
        for col in 2..<9 {
            board.eliminate(6, at: col)
            board.eliminate(7, at: col)
        }
        let step = try #require(HiddenSubset(size: 2).find(in: board))
        #expect(step.technique == .hiddenPair)
        #expect(step.patternCells == [0, 1])
        #expect(step.digits == [6, 7])
        let others = [1, 2, 3, 4, 5, 8, 9]
        let expected = [0, 1].flatMap { c in others.map { CellDigit(cell: c, digit: $0) } }
        #expect(Set(step.eliminations) == Set(expected))
    }

    @Test func hiddenTriple() throws {
        var board = emptyBoard()
        for col in 3..<9 {
            for d in [4, 5, 6] { board.eliminate(d, at: col) }
        }
        #expect(HiddenSubset(size: 2).find(in: board) == nil)
        let step = try #require(HiddenSubset(size: 3).find(in: board))
        #expect(step.technique == .hiddenTriple)
        #expect(step.patternCells == [0, 1, 2])
        #expect(step.digits == [4, 5, 6])
        #expect(step.eliminations.count == 18)
    }

    @Test func idsBySize() {
        #expect(NakedSubset(size: 4).id == .nakedQuad)
        #expect(HiddenSubset(size: 4).id == .hiddenQuad)
    }

    @Test func nothingOnEmptyBoard() {
        for size in 2...4 {
            #expect(NakedSubset(size: size).find(in: emptyBoard()) == nil)
            #expect(HiddenSubset(size: size).find(in: emptyBoard()) == nil)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter SubsetsTests`
Expected: build FAILS with `cannot find 'NakedSubset' in scope`.

- [ ] **Step 3: Implement combinations**

`SudokuCore/Sources/SudokuCore/Support/Combinations.swift`:
```swift
extension Array {
    /// All `k`-element combinations, in lexicographic index order.
    func combinations(of k: Int) -> [[Element]] {
        guard k > 0 else { return [[]] }
        guard count >= k else { return [] }
        var result: [[Element]] = []
        var idx = Array<Int>(0..<k)
        while true {
            result.append(idx.map { self[$0] })
            var i = k - 1
            while i >= 0 && idx[i] == count - k + i { i -= 1 }
            if i < 0 { return result }
            idx[i] += 1
            for j in (i + 1)..<k { idx[j] = idx[j - 1] + 1 }
        }
    }
}
```

- [ ] **Step 4: Implement subsets**

`SudokuCore/Sources/SudokuCore/Techniques/Subsets.swift`:
```swift
/// N cells in a house whose candidates together are exactly N digits:
/// those digits leave every other cell of the house.
public struct NakedSubset: Technique {
    public let size: Int

    public init(size: Int) {
        precondition((2...4).contains(size), "Subset size must be 2, 3 or 4")
        self.size = size
    }

    public var id: TechniqueID {
        switch size {
        case 2: return .nakedPair
        case 3: return .nakedTriple
        default: return .nakedQuad
        }
    }

    public func find(in board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            let empties = house.filter { board.values[$0] == 0 }
            guard empties.count > size else { continue }
            let pool = empties.filter { (2...size).contains(board.candidates[$0].count) }
            for combo in pool.combinations(of: size) {
                let union = combo.reduce(CandidateSet.empty) { $0.union(board.candidates[$1]) }
                guard union.count == size else { continue }
                var eliminations: [CellDigit] = []
                for c in empties where !combo.contains(c) {
                    for d in board.candidates[c].intersection(union).digits {
                        eliminations.append(CellDigit(cell: c, digit: d))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: combo,
                    patternCandidates: combo.flatMap { c in board.candidates[c].digits.map { CellDigit(cell: c, digit: $0) } },
                    eliminations: eliminations,
                    regions: [Region(house: h)],
                    digits: union.digits
                )
            }
        }
        return nil
    }
}

/// N digits that, within a house, appear only in the same N cells:
/// every other candidate leaves those cells.
public struct HiddenSubset: Technique {
    public let size: Int

    public init(size: Int) {
        precondition((2...4).contains(size), "Subset size must be 2, 3 or 4")
        self.size = size
    }

    public var id: TechniqueID {
        switch size {
        case 2: return .hiddenPair
        case 3: return .hiddenTriple
        default: return .hiddenQuad
        }
    }

    public func find(in board: Board) -> Step? {
        for (h, house) in Geometry.houses.enumerated() {
            let empties = house.filter { board.values[$0] == 0 }
            guard empties.count > size else { continue }
            var positions: [Int: [Int]] = [:]
            for d in 1...9 {
                let cells = empties.filter { board.candidates[$0].contains(d) }
                if (2...size).contains(cells.count) { positions[d] = cells }
            }
            for combo in positions.keys.sorted().combinations(of: size) {
                let cells = Set(combo.flatMap { positions[$0]! }).sorted()
                guard cells.count == size else { continue }
                let digits = CandidateSet(combo)
                var eliminations: [CellDigit] = []
                for c in cells {
                    for d in board.candidates[c].subtracting(digits).digits {
                        eliminations.append(CellDigit(cell: c, digit: d))
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return Step(
                    technique: id,
                    patternCells: cells,
                    patternCandidates: cells.flatMap { c in
                        combo.filter { board.candidates[c].contains($0) }.map { CellDigit(cell: c, digit: $0) }
                    },
                    eliminations: eliminations,
                    regions: [Region(house: h)],
                    digits: combo
                )
            }
        }
        return nil
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter SubsetsTests`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add naked and hidden subsets"
```

---

### Task 7: LogicalSolver, Grader, Puzzle model

**Files:**
- Modify: `SudokuCore/Sources/SudokuCore/Solvers/Technique.swift` (append `TechniqueCatalog`)
- Create: `SudokuCore/Sources/SudokuCore/Solvers/LogicalSolver.swift`
- Create: `SudokuCore/Sources/SudokuCore/Solvers/Grader.swift`
- Create: `SudokuCore/Sources/SudokuCore/Model/Puzzle.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/LogicalSolverTests.swift`, `SudokuCore/Tests/SudokuCoreTests/PuzzleCodingTests.swift`

**Interfaces:**
- Consumes: all techniques (Tasks 4–6), `BruteForceSolver` (Task 3).
- Produces:
  - `enum TechniqueCatalog { static let classic: [any Technique] }` (easiest first).
  - `struct LogicalSolver: Sendable` — `init(techniques:)`, `static let classic`, `maxTier: Tier`, `nextStep(on:) -> Step?`, `solve(_:maxSteps:) -> SolveResult`.
  - `struct SolveResult: Sendable` — `board: Board`, `steps: [Step]`, `solved: Bool`.
  - `struct Grade: Codable, Hashable, Sendable` — `tier: Tier`, `score: Int`.
  - `struct GradeReport: Hashable, Sendable` — `grade: Grade`, `techniquesRequired: [TechniqueID]`.
  - `enum Grader` — `grade(_ givens: [Int], solver:) -> GradeReport?` (checks uniqueness), `grade(_ givens: [Int], solution: [Int], solver:) -> GradeReport?` (caller already proved uniqueness).
  - `struct Puzzle: Codable, Hashable, Sendable, Identifiable` — `id: String`, `mode: Mode`, `givens: [Int]`, `cages: [Cage]`, `solution: [Int]`, `grade: Grade`, `techniquesRequired: [TechniqueID]`; JSON encodes `givens`/`solution` as 81-digit strings and omits empty `cages`.

- [ ] **Step 1: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/LogicalSolverTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct LogicalSolverTests {
    @Test func solvesEasyPuzzleWithSingles() {
        let result = LogicalSolver.classic.solve(Board(values: values(wikiPuzzle)))
        #expect(result.solved)
        #expect(result.board.values == values(wikiSolution))
        #expect(result.steps.allSatisfy { $0.technique.tier == .easy })
    }

    @Test func gradesEasyPuzzle() throws {
        let report = try #require(Grader.grade(values(wikiPuzzle)))
        #expect(report.grade.tier == .easy)
        #expect(report.grade.score > 0)
        #expect(report.techniquesRequired.allSatisfy { $0.tier == .easy })
    }

    @Test func stuckPuzzleHasNoGrade() {
        // Needs techniques far beyond this plan's catalog.
        #expect(LogicalSolver.classic.solve(Board(values: values(inkalaPuzzle))).solved == false)
        #expect(Grader.grade(values(inkalaPuzzle)) == nil)
    }

    @Test func multipleSolutionsHaveNoGrade() {
        #expect(Grader.grade(Array(repeating: 0, count: 81)) == nil)
    }

    @Test func contradictoryGivensHaveNoGrade() {
        var v = values(wikiPuzzle)
        v[2] = 5   // second 5 in row 0
        #expect(Grader.grade(v) == nil)
    }

    @Test func maxTierOfClassicCatalog() {
        #expect(LogicalSolver.classic.maxTier == .hard)
    }

    @Test func nextStepPrefersEasiestTechnique() throws {
        var v = values(wikiSolution)
        v[0] = 0
        let step = try #require(LogicalSolver.classic.nextStep(on: Board(values: v)))
        #expect(step.technique == .fullHouse)
    }
}
```

`SudokuCore/Tests/SudokuCoreTests/PuzzleCodingTests.swift`:
```swift
import Foundation
import Testing
import SudokuCore

@Suite struct PuzzleCodingTests {
    let puzzle = Puzzle(
        id: "abc",
        mode: .classic,
        givens: values(wikiPuzzle),
        cages: [],
        solution: values(wikiSolution),
        grade: Grade(tier: .easy, score: 120),
        techniquesRequired: [.nakedSingle, .hiddenSingle]
    )

    @Test func roundTrips() throws {
        let data = try JSONEncoder().encode(puzzle)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"givens\":\"\(wikiPuzzle)\""))
        #expect(!json.contains("cages"))
        #expect(try JSONDecoder().decode(Puzzle.self, from: data) == puzzle)
    }

    @Test func roundTripsCages() throws {
        var killer = puzzle
        killer.mode = .killer
        killer.cages = [Cage(cells: [0, 1], sum: 8)]
        let data = try JSONEncoder().encode(killer)
        #expect(try JSONDecoder().decode(Puzzle.self, from: data) == killer)
    }

    @Test func corruptGivensThrow() {
        let json = """
        {"id":"x","mode":"classic","givens":"123","solution":"\(wikiSolution)",
         "grade":{"tier":0,"score":1},"techniquesRequired":[]}
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Puzzle.self, from: Data(json.utf8))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter "LogicalSolverTests|PuzzleCodingTests"`
Expected: build FAILS with `cannot find 'LogicalSolver' in scope`.

- [ ] **Step 3: Add the technique catalog**

Append to `SudokuCore/Sources/SudokuCore/Solvers/Technique.swift`:
```swift

public enum TechniqueCatalog {
    /// Classic techniques in the order the solver tries them (easiest first).
    public static let classic: [any Technique] = [
        FullHouse(),
        NakedSingle(),
        HiddenSingle(),
        Pointing(),
        BoxLineReduction(),
        NakedSubset(size: 2),
        HiddenSubset(size: 2),
        NakedSubset(size: 3),
        HiddenSubset(size: 3),
        NakedSubset(size: 4),
        HiddenSubset(size: 4),
    ]
}
```

- [ ] **Step 4: Implement LogicalSolver**

`SudokuCore/Sources/SudokuCore/Solvers/LogicalSolver.swift`:
```swift
public struct SolveResult: Sendable {
    public let board: Board
    public let steps: [Step]
    public var solved: Bool { board.isSolved }
}

/// Solves like a human: always applies the easiest technique that makes progress.
public struct LogicalSolver: Sendable {
    public let techniques: [any Technique]

    public init(techniques: [any Technique]) {
        self.techniques = techniques
    }

    public static let classic = LogicalSolver(techniques: TechniqueCatalog.classic)

    /// The hardest tier this solver can grade.
    public var maxTier: Tier { techniques.map { $0.id.tier }.max() ?? .easy }

    public func nextStep(on board: Board) -> Step? {
        for technique in techniques {
            if let step = technique.find(in: board) { return step }
        }
        return nil
    }

    /// Steps until solved, stuck, or `maxSteps` (a guard against malformed boards).
    public func solve(_ start: Board, maxSteps: Int = 1000) -> SolveResult {
        var board = start
        var steps: [Step] = []
        while !board.isSolved, steps.count < maxSteps, let step = nextStep(on: board) {
            board.apply(step)
            steps.append(step)
        }
        return SolveResult(board: board, steps: steps)
    }
}
```

- [ ] **Step 5: Implement Puzzle and Grade**

`SudokuCore/Sources/SudokuCore/Model/Puzzle.swift`:
```swift
public struct Grade: Codable, Hashable, Sendable {
    public var tier: Tier
    public var score: Int

    public init(tier: Tier, score: Int) {
        self.tier = tier
        self.score = score
    }
}

public struct Puzzle: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var mode: Mode
    public var givens: [Int]
    public var cages: [Cage]
    public var solution: [Int]
    public var grade: Grade
    public var techniquesRequired: [TechniqueID]

    public init(
        id: String,
        mode: Mode,
        givens: [Int],
        cages: [Cage],
        solution: [Int],
        grade: Grade,
        techniquesRequired: [TechniqueID]
    ) {
        self.id = id
        self.mode = mode
        self.givens = givens
        self.cages = cages
        self.solution = solution
        self.grade = grade
        self.techniquesRequired = techniquesRequired
    }

    enum CodingKeys: String, CodingKey {
        case id, mode, givens, cages, solution, grade, techniquesRequired
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        mode = try c.decode(Mode.self, forKey: .mode)
        guard let givens = Board.parse(try c.decode(String.self, forKey: .givens)) else {
            throw DecodingError.dataCorruptedError(forKey: .givens, in: c, debugDescription: "Expected 81 digits")
        }
        guard let solution = Board.parse(try c.decode(String.self, forKey: .solution)) else {
            throw DecodingError.dataCorruptedError(forKey: .solution, in: c, debugDescription: "Expected 81 digits")
        }
        self.givens = givens
        self.solution = solution
        cages = try c.decodeIfPresent([Cage].self, forKey: .cages) ?? []
        grade = try c.decode(Grade.self, forKey: .grade)
        techniquesRequired = try c.decode([TechniqueID].self, forKey: .techniquesRequired)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(mode, forKey: .mode)
        try c.encode(givens.map(String.init).joined(), forKey: .givens)
        try c.encode(solution.map(String.init).joined(), forKey: .solution)
        if !cages.isEmpty { try c.encode(cages, forKey: .cages) }
        try c.encode(grade, forKey: .grade)
        try c.encode(techniquesRequired, forKey: .techniquesRequired)
    }
}
```

- [ ] **Step 6: Implement Grader**

`SudokuCore/Sources/SudokuCore/Solvers/Grader.swift`:
```swift
public struct GradeReport: Hashable, Sendable {
    public let grade: Grade
    /// Distinct techniques used, in `TechniqueID` declaration order (easiest first).
    public let techniquesRequired: [TechniqueID]
}

public enum Grader {
    /// Grades a puzzle. Nil unless it has exactly one solution and the solver finishes it.
    public static func grade(_ givens: [Int], solver: LogicalSolver = .classic) -> GradeReport? {
        guard BruteForceSolver.countSolutions(givens) == 1,
              let solution = BruteForceSolver.solve(givens) else { return nil }
        return grade(givens, solution: solution, solver: solver)
    }

    /// Grades a puzzle whose uniqueness the caller has already proved.
    public static func grade(_ givens: [Int], solution: [Int], solver: LogicalSolver = .classic) -> GradeReport? {
        let result = solver.solve(Board(values: givens))
        guard result.solved, result.board.values == solution else { return nil }
        let used = Set(result.steps.map(\.technique))
        let techniques = TechniqueID.allCases.filter(used.contains)
        let tier = techniques.map(\.tier).max() ?? .easy
        let score = result.steps.reduce(0) { $0 + $1.technique.weight }
        return GradeReport(grade: Grade(tier: tier, score: score), techniquesRequired: techniques)
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore`
Expected: PASS (all suites).

- [ ] **Step 8: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add logical solver, grader and Puzzle model"
```

---

### Task 8: Grid transforms

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Generation/GridTransform.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/GridTransformTests.swift`

**Interfaces:**
- Consumes: `Puzzle`, `Cage`, `Geometry`, `SplitMix64`.
- Produces: `struct GridTransform: Sendable, Equatable` — `init(digitMap:rowOrder:colOrder:transpose:)`, `static let identity`, `static func random<R>(using: inout R, relabelDigits: Bool = true) -> GridTransform`, `static func random<R>(for puzzle: Puzzle, using: inout R) -> GridTransform` (disables relabelling when the puzzle has cages), `newCell(for:) -> Int`, `apply(to: [Int]) -> [Int]`, `apply(to: Cage) -> Cage`, `apply(to: Puzzle) -> Puzzle`.

- [ ] **Step 1: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/GridTransformTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct GridTransformTests {
    func samplePuzzle(cages: [Cage] = []) -> Puzzle {
        Puzzle(
            id: "p", mode: cages.isEmpty ? .classic : .killer,
            givens: values(wikiPuzzle), cages: cages, solution: values(wikiSolution),
            grade: Grade(tier: .easy, score: 1), techniquesRequired: [.nakedSingle]
        )
    }

    @Test func identityChangesNothing() {
        #expect(GridTransform.identity.apply(to: samplePuzzle()) == samplePuzzle())
    }

    @Test func transposeMovesCells() {
        let t = GridTransform(digitMap: Array(0...9), rowOrder: Array(0..<9), colOrder: Array(0..<9), transpose: true)
        #expect(t.newCell(for: 1) == 9)
        #expect(t.newCell(for: 0) == 0)
    }

    @Test(arguments: 1...20)
    func randomTransformsPreserveValidityAndUniqueness(seed: Int) {
        var rng = SplitMix64(seed: UInt64(seed))
        let t = GridTransform.random(using: &rng)
        let p = t.apply(to: samplePuzzle())
        #expect(isValidSolution(p.solution))
        #expect(BruteForceSolver.countSolutions(p.givens) == 1)
        #expect(BruteForceSolver.solve(p.givens) == p.solution)
        for c in 0..<81 where p.givens[c] != 0 { #expect(p.givens[c] == p.solution[c]) }
        #expect(Grader.grade(p.givens)?.grade.tier == .easy)
    }

    @Test func randomTransformsDiffer() {
        var rng = SplitMix64(seed: 7)
        let a = GridTransform.random(using: &rng)
        let b = GridTransform.random(using: &rng)
        #expect(a != b)
    }

    @Test func killerPuzzlesKeepDigitsAndCageSums() {
        // Cage of row-0 cells 0 and 1 (digits 5 and 3 in the solution).
        let cage = Cage(cells: [0, 1], sum: 8)
        var rng = SplitMix64(seed: 3)
        let puzzle = samplePuzzle(cages: [cage])
        let t = GridTransform.random(for: puzzle, using: &rng)
        #expect(t.digitMap == Array(0...9))
        let p = t.apply(to: puzzle)
        #expect(p.cages.count == 1)
        #expect(p.cages[0].sum == 8)
        #expect(p.cages[0].cells == [t.newCell(for: 0), t.newCell(for: 1)].sorted())
        #expect(p.cages[0].cells.map { p.solution[$0] }.reduce(0, +) == 8)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter GridTransformTests`
Expected: build FAILS with `cannot find 'GridTransform' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Generation/GridTransform.swift`:
```swift
/// A validity- and grade-preserving remapping of a puzzle:
/// digit relabelling, row/column shuffles within bands/stacks, band/stack shuffles, transpose.
public struct GridTransform: Sendable, Equatable {
    /// `digitMap[old] = new`; index 0 always maps to 0.
    public let digitMap: [Int]
    /// New row `i` is old row `rowOrder[i]`.
    public let rowOrder: [Int]
    /// New column `i` is old column `colOrder[i]`.
    public let colOrder: [Int]
    public let transpose: Bool

    private let rowInverse: [Int]
    private let colInverse: [Int]

    public init(digitMap: [Int], rowOrder: [Int], colOrder: [Int], transpose: Bool) {
        self.digitMap = digitMap
        self.rowOrder = rowOrder
        self.colOrder = colOrder
        self.transpose = transpose
        var rowInverse = [Int](repeating: 0, count: 9)
        var colInverse = [Int](repeating: 0, count: 9)
        for i in 0..<9 {
            rowInverse[rowOrder[i]] = i
            colInverse[colOrder[i]] = i
        }
        self.rowInverse = rowInverse
        self.colInverse = colInverse
    }

    public static let identity = GridTransform(
        digitMap: Array(0...9), rowOrder: Array(0..<9), colOrder: Array(0..<9), transpose: false
    )

    public static func random<R: RandomNumberGenerator>(using rng: inout R, relabelDigits: Bool = true) -> GridTransform {
        var digits = Array(1...9)
        if relabelDigits { digits.shuffle(using: &rng) }
        let rows = lineOrder(using: &rng)
        let cols = lineOrder(using: &rng)
        return GridTransform(digitMap: [0] + digits, rowOrder: rows, colOrder: cols, transpose: Bool.random(using: &rng))
    }

    /// Random transform suitable for `puzzle`: Killer puzzles keep their digits, since relabelling changes cage sums.
    public static func random<R: RandomNumberGenerator>(for puzzle: Puzzle, using rng: inout R) -> GridTransform {
        random(using: &rng, relabelDigits: puzzle.cages.isEmpty)
    }

    /// Shuffles the three bands (or stacks) and the three lines inside each.
    static func lineOrder<R: RandomNumberGenerator>(using rng: inout R) -> [Int] {
        var bands = [0, 1, 2]
        bands.shuffle(using: &rng)
        var order: [Int] = []
        for band in bands {
            var lines = [0, 1, 2]
            lines.shuffle(using: &rng)
            order += lines.map { band * 3 + $0 }
        }
        return order
    }

    /// Where an old cell ends up.
    public func newCell(for old: Int) -> Int {
        let r = rowInverse[Geometry.row(old)]
        let c = colInverse[Geometry.col(old)]
        return transpose ? Geometry.cell(c, r) : Geometry.cell(r, c)
    }

    public func apply(to values: [Int]) -> [Int] {
        var out = [Int](repeating: 0, count: 81)
        for old in 0..<81 { out[newCell(for: old)] = digitMap[values[old]] }
        return out
    }

    public func apply(to cage: Cage) -> Cage {
        Cage(cells: cage.cells.map { newCell(for: $0) }.sorted(), sum: cage.sum)
    }

    public func apply(to puzzle: Puzzle) -> Puzzle {
        precondition(puzzle.cages.isEmpty || digitMap == Array(0...9), "Killer puzzles must not relabel digits")
        var p = puzzle
        p.givens = apply(to: puzzle.givens)
        p.solution = apply(to: puzzle.solution)
        p.cages = puzzle.cages.map { apply(to: $0) }
        return p
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter GridTransformTests`
Expected: PASS (24 test cases including the 20 parameterised ones).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add grade-preserving grid transforms"
```

---

### Task 9: Classic generator

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Generation/ClassicGenerator.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/ClassicGeneratorTests.swift`

**Interfaces:**
- Consumes: `BruteForceSolver`, `Grader`, `LogicalSolver`, `Puzzle`, `SplitMix64`.
- Produces: `struct ClassicGenerator: Sendable` — `init(solver: LogicalSolver = .classic)`, `func generate<R: RandomNumberGenerator>(tier: Tier, using rng: inout R, deadline: ContinuousClock.Instant? = nil) -> Puzzle?`.

Algorithm: random full grid → visit the 41 symmetric cell pairs (`c`, `80 - c`; centre 40 alone) in random order → remove a pair if the puzzle stays unique and its grade is at or below the target tier, otherwise restore → accept the result if its tier equals the target, else start a new grid. Tiers above `solver.maxTier` return nil immediately.

- [ ] **Step 1: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/ClassicGeneratorTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct ClassicGeneratorTests {
    @Test(arguments: [Tier.easy, .medium, .hard])
    func generatesRequestedTier(tier: Tier) throws {
        var rng = SplitMix64(seed: 42)
        let p = try #require(ClassicGenerator().generate(tier: tier, using: &rng))
        #expect(p.mode == .classic)
        #expect(p.grade.tier == tier)
        #expect(p.cages.isEmpty)
        #expect(isValidSolution(p.solution))
        #expect(BruteForceSolver.countSolutions(p.givens) == 1)
        #expect(Grader.grade(p.givens)?.grade == p.grade)
        for c in 0..<81 {
            if p.givens[c] != 0 { #expect(p.givens[c] == p.solution[c]) }
            #expect((p.givens[c] == 0) == (p.givens[80 - c] == 0), "not symmetric at \(c)")
        }
    }

    @Test func unsupportedTierReturnsNilImmediately() {
        var rng = SplitMix64(seed: 1)
        let start = ContinuousClock.now
        #expect(ClassicGenerator().generate(tier: .expert, using: &rng) == nil)
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    @Test func expiredDeadlineReturnsNil() {
        var rng = SplitMix64(seed: 1)
        let past = ContinuousClock.now - .seconds(1)
        #expect(ClassicGenerator().generate(tier: .easy, using: &rng, deadline: past) == nil)
    }

    @Test func sameSeedSamePuzzle() {
        var a = SplitMix64(seed: 9)
        var b = SplitMix64(seed: 9)
        #expect(ClassicGenerator().generate(tier: .medium, using: &a) == ClassicGenerator().generate(tier: .medium, using: &b))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter ClassicGeneratorTests`
Expected: build FAILS with `cannot find 'ClassicGenerator' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Generation/ClassicGenerator.swift`:
```swift
public struct ClassicGenerator: Sendable {
    public let solver: LogicalSolver

    public init(solver: LogicalSolver = .classic) {
        self.solver = solver
    }

    /// A unique, logic-solvable puzzle of exactly `tier`, or nil when the deadline passes
    /// or the solver has no techniques for that tier.
    public func generate<R: RandomNumberGenerator>(
        tier: Tier,
        using rng: inout R,
        deadline: ContinuousClock.Instant? = nil
    ) -> Puzzle? {
        guard tier <= solver.maxTier else { return nil }
        while deadline.map({ ContinuousClock.now < $0 }) ?? true {
            if let puzzle = attempt(tier: tier, using: &rng) { return puzzle }
        }
        return nil
    }

    private func attempt<R: RandomNumberGenerator>(tier: Tier, using rng: inout R) -> Puzzle? {
        let solution = BruteForceSolver.randomSolution(using: &rng)
        var givens = solution
        var accepted: GradeReport?
        // Cell c pairs with 80 - c (180° symmetry); 40 is the centre.
        var order = Array(0...40)
        order.shuffle(using: &rng)
        for c in order {
            let pair = c == 40 ? [40] : [c, 80 - c]
            let saved = pair.map { givens[$0] }
            for p in pair { givens[p] = 0 }
            if BruteForceSolver.countSolutions(givens) == 1,
               let report = Grader.grade(givens, solution: solution, solver: solver),
               report.grade.tier <= tier {
                accepted = report
            } else {
                for (p, v) in zip(pair, saved) { givens[p] = v }
            }
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
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter ClassicGeneratorTests`
Expected: PASS (6 test cases). The Hard case may take several seconds in debug builds.

- [ ] **Step 5: Run the whole suite**

Run: `swift test --package-path SudokuCore`
Expected: PASS (all suites).

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): add symmetric classic generator"
```

---

### Task 10: sudoku-forge CLI

**Files:**
- Modify: `SudokuCore/Package.swift`
- Create: `SudokuCore/Sources/sudoku-forge/main.swift`

**Interfaces:**
- Consumes: `ClassicGenerator`, `LogicalSolver.classic.maxTier`, `Tier(name:)`, `Mode`, `SplitMix64`, `Puzzle` (Codable).
- Produces: executable `sudoku-forge --tier <tier> --out <file> [--mode classic|killer] [--count N] [--seed N] [--timeout SECONDS]`. Exit codes: 0 success, 1 unsupported mode/tier, 2 bad arguments.

- [ ] **Step 1: Add the executable target**

Replace `SudokuCore/Package.swift` with:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SudokuCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SudokuCore", targets: ["SudokuCore"]),
        .executable(name: "sudoku-forge", targets: ["sudoku-forge"]),
    ],
    targets: [
        .target(name: "SudokuCore"),
        .executableTarget(name: "sudoku-forge", dependencies: ["SudokuCore"]),
        .testTarget(name: "SudokuCoreTests", dependencies: ["SudokuCore"]),
    ]
)
```

- [ ] **Step 2: Write main.swift**

`SudokuCore/Sources/sudoku-forge/main.swift`:
```swift
import Foundation
import SudokuCore

struct Options {
    var mode = Mode.classic
    var tier: Tier?
    var count = 10
    var out: String?
    var seed: UInt64?
    var timeout = 60.0
}

func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func usage() -> Never {
    log("""
    usage: sudoku-forge --tier easy|medium|hard|expert|fiendish|diabolical|nightmare --out FILE
                        [--mode classic|killer] [--count N] [--seed N] [--timeout SECONDS]
    """)
    exit(2)
}

func parse(_ args: [String]) -> Options {
    var o = Options()
    var i = 0
    while i < args.count {
        guard i + 1 < args.count else { usage() }
        let value = args[i + 1]
        switch args[i] {
        case "--mode":
            guard let m = Mode(rawValue: value) else { usage() }
            o.mode = m
        case "--tier":
            guard let t = Tier(name: value) else { usage() }
            o.tier = t
        case "--count":
            guard let n = Int(value), n > 0 else { usage() }
            o.count = n
        case "--out":
            o.out = value
        case "--seed":
            guard let s = UInt64(value) else { usage() }
            o.seed = s
        case "--timeout":
            guard let t = Double(value), t > 0 else { usage() }
            o.timeout = t
        default:
            usage()
        }
        i += 2
    }
    guard o.tier != nil, o.out != nil else { usage() }
    return o
}

let options = parse(Array(CommandLine.arguments.dropFirst()))
let tier = options.tier!

guard options.mode == .classic else {
    log("killer generation is not implemented yet")
    exit(1)
}
guard tier <= LogicalSolver.classic.maxTier else {
    log("tier \(tier.name) is not supported yet (max: \(LogicalSolver.classic.maxTier.name))")
    exit(1)
}

var rng = SplitMix64(seed: options.seed ?? UInt64.random(in: .min ... .max))
let generator = ClassicGenerator()
var puzzles: [Puzzle] = []

while puzzles.count < options.count {
    let deadline = ContinuousClock.now + .seconds(options.timeout)
    guard let puzzle = generator.generate(tier: tier, using: &rng, deadline: deadline) else {
        log("timed out after \(options.timeout)s on puzzle \(puzzles.count + 1); writing \(puzzles.count)")
        break
    }
    puzzles.append(puzzle)
    let techniques = puzzle.techniquesRequired.map(\.rawValue).joined(separator: ",")
    log("[\(puzzles.count)/\(options.count)] score \(puzzle.grade.score) \(techniques)")
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
do {
    try encoder.encode(puzzles).write(to: URL(fileURLWithPath: options.out!))
} catch {
    log("failed to write \(options.out!): \(error)")
    exit(1)
}
```

- [ ] **Step 3: Build and generate a small library**

Run:
```bash
swift build --package-path SudokuCore -c release
SudokuCore/.build/release/sudoku-forge --tier medium --count 3 --seed 1 --out "$TMPDIR/medium.json"
python3 -c "import json,os; d=json.load(open(os.environ['TMPDIR']+'/medium.json')); print(len(d), {p['grade']['tier'] for p in d}, len(d[0]['givens']))"
```
Expected: three `[n/3] score …` lines on stderr, then `3 {1} 81`.

- [ ] **Step 4: Check the error paths**

Run:
```bash
SudokuCore/.build/release/sudoku-forge --tier medium; echo "exit=$?"
SudokuCore/.build/release/sudoku-forge --tier bogus --out x.json; echo "exit=$?"
SudokuCore/.build/release/sudoku-forge --tier expert --out x.json; echo "exit=$?"
SudokuCore/.build/release/sudoku-forge --mode killer --tier easy --out x.json; echo "exit=$?"
```
Expected: usage + `exit=2`; usage + `exit=2`; `tier expert is not supported yet (max: hard)` + `exit=1`; `killer generation is not implemented yet` + `exit=1`. No `x.json` is created.

- [ ] **Step 5: Run the full test suite once more**

Run: `swift test --package-path SudokuCore`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add SudokuCore
git commit -m "feat(forge): add sudoku-forge CLI for classic libraries"
```
