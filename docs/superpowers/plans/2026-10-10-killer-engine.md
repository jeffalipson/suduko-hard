# Killer Engine Implementation Plan (Plan 4 of 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Killer Sudoku support in `SudokuCore`: cage-aware board and brute-force solver, cage techniques and the 45 rule, a Killer catalog, a Killer generator, and `sudoku-forge --mode killer`.

**Architecture:** `Board` learns which cage each cell is in; placing a digit also removes it from cage mates. The brute-force solver tracks each cage's used digits and remaining sum and prunes digits that leave the cage unfillable. Killer techniques are ordinary `Technique`s that read `board.cages`. The Killer catalog is the classic catalog minus unique rectangles (swapping digits changes cage sums, so the deadly-pattern argument fails) plus the cage techniques, ordered by tier then weight. The Killer generator partitions a random solution into connected cages sized for the tier, then removes givens while the puzzle stays unique and solvable with techniques up to the tier.

**Tech Stack:** Swift 6.2, SwiftPM, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-10-hard-sudoku-design.md` (§4.6, §5.2)

## Global Constraints

- Killer rules: every cell belongs to exactly one cage; cage digits sum to the cage sum and never repeat.
- Killer catalog must not contain unique rectangles.
- Tier ladder (spec §4.6): Easy = cage completion, unique cage combinations; Medium = cage combination restriction; Hard = 45 rule on one house; Expert = 45 rule across two houses, cage-locked digits (killer pairs); Fiendish = 45 rule across three or four houses; Diabolical/Nightmare = classic chains/forcing chains on Killer boards.
- Structure per tier (spec §4.6 table): givens and cage-size ranges as listed in `KillerRules`.
- Spec deviation (ruled here, amended in Task 4): a Killer puzzle's tier is its technique tier, and its givens/cage sizes must fit that tier's ranges. Taking the max of technique tier and a "structural tier" would label logically easy puzzles Nightmare just for having an 8-cell cage.

## Review Focus

1. **Cage sums in the brute-force solver** (wrong sums, overlapping cages, cells outside 0..<81) → 0 solutions, never a crash. Task 1 tests.
2. **Unique rectangles leaking into Killer** → catalog test in Task 4.
3. **45-rule regions that aren't fully caged** → skipped. Task 3 code + fuzz on partly caged boards.
4. **Large cages blowing up enumeration** → cages with more than 5 empty cells use digit-level combination filtering, not per-cell assignment. Task 2.
5. **Killer generation time and reliability per tier** → measured in Task 4; CLI `--timeout` bounds library builds.

## File Structure

```
SudokuCore/Sources/SudokuCore/
├── Model/Board.swift                    (modify: cageOf, cageMates, cage-aware candidates/place)
├── Model/Board+Contradiction.swift      (modify: cage checks)
├── Model/TechniqueID.swift              (modify: 7 killer cases, isKillerOnly)
├── Solvers/BruteForceSolver.swift       (modify: cages)
├── Solvers/Grader.swift                 (modify: cages parameter)
├── Solvers/Technique.swift              (modify: TechniqueCatalog.killer)
├── Solvers/LogicalSolver.swift          (modify: LogicalSolver.killer)
├── Techniques/CageMath.swift            (new)
├── Techniques/CageTechniques.swift      (new: CageCompletion, UniqueCageCombination, CageCombination, CageLockedDigit)
├── Techniques/InnieOutie.swift          (new: KillerRegions, InnieOutie)
├── Generation/KillerCages.swift         (new: partition)
├── Generation/KillerGenerator.swift     (new: KillerRules, KillerGenerator)
└── sudoku-forge/main.swift              (modify: killer mode)
SudokuCore/Tests/SudokuCoreTests/
├── TestSupport.swift (modify), KillerBoardTests.swift, CageTechniqueTests.swift,
├── InnieOutieTests.swift, KillerGeneratorTests.swift (new), LogicalSolverTests.swift (modify)
```

---

### Task 1: Cage-aware board, brute force, grader, partition

**Files:**
- Modify: `Board.swift`, `Board+Contradiction.swift`, `BruteForceSolver.swift`, `Grader.swift`
- Create: `SudokuCore/Sources/SudokuCore/Generation/KillerCages.swift`
- Modify: `SudokuCore/Tests/SudokuCoreTests/TestSupport.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/KillerBoardTests.swift`

**Interfaces:**
- Produces: `Board.cageOf: [Int]`, `Board.cageMates(of:) -> [Int]`; `BruteForceSolver.countSolutions(_:cages:limit:)`, `solve(_:cages:)`; `Grader.grade(_:cages:solver:)`, `Grader.grade(_:cages:solution:solver:)`; `KillerCages.partition(solution:sizes:using:) -> [Cage]`; test helpers `dominoCages(for:)`, `randomKillerPuzzle(seed:)`, `killerSoundnessViolations(of:seeds:)`.

- [ ] **Step 1: Write the failing tests**

Append to `SudokuCore/Tests/SudokuCoreTests/TestSupport.swift`:
```swift

/// Horizontal dominoes (r, 2k)-(r, 2k+1) plus a single cell in column 8, summed from `solution`.
func dominoCages(for solution: [Int]) -> [Cage] {
    var cages: [Cage] = []
    for r in 0..<9 {
        for k in 0..<4 {
            let cells = [rc(r, 2 * k), rc(r, 2 * k + 1)]
            cages.append(Cage(cells: cells, sum: cells.map { solution[$0] }.reduce(0, +)))
        }
        cages.append(Cage(cells: [rc(r, 8)], sum: solution[rc(r, 8)]))
    }
    return cages
}

/// A random Killer board (not necessarily unique): cages of 2–5 cells and 20 revealed cells.
func randomKillerPuzzle(seed: UInt64) -> (givens: [Int], cages: [Cage], solution: [Int]) {
    var rng = SplitMix64(seed: seed)
    let solution = BruteForceSolver.randomSolution(using: &rng)
    let cages = KillerCages.partition(solution: solution, sizes: 2...5, using: &rng)
    var givens = Array(repeating: 0, count: 81)
    for c in Array(0..<81).shuffled(using: &rng).prefix(20) { givens[c] = solution[c] }
    return (givens, cages, solution)
}

/// Killer counterpart of `soundnessViolations`: walks random Killer boards with the classic
/// catalog minus unique rectangles plus `technique`. Non-uniqueness techniques never remove a
/// digit of any solution, so multi-solution boards are fine here.
func killerSoundnessViolations(of technique: any Technique, seeds: ClosedRange<Int>) -> [String] {
    let base = TechniqueCatalog.classic.filter { !$0.id.rawValue.hasPrefix("uniqueRectangle") }
    let solver = LogicalSolver(techniques: base + [technique])
    var failures: [String] = []
    for seed in seeds {
        let (givens, cages, solution) = randomKillerPuzzle(seed: UInt64(seed))
        var board = Board(values: givens, cages: cages)
        for _ in 0..<300 {
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

`SudokuCore/Tests/SudokuCoreTests/KillerBoardTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct KillerBoardTests {
    @Test func cageMatesLoseTheDigit() {
        var v = Array(repeating: 0, count: 81)
        v[0] = 5
        let board = Board(values: v, cages: [Cage(cells: [0, 40], sum: 10)])
        #expect(board.cageOf[40] == 0)
        #expect(board.cageOf[1] == -1)
        #expect(board.cageMates(of: 40) == [0])
        #expect(!board.candidates[40].contains(5))   // cage mate, not a peer
        var b = Board(values: Array(repeating: 0, count: 81), cages: [Cage(cells: [1, 50], sum: 9)])
        b.place(3, at: 1)
        #expect(!b.candidates[50].contains(3))
    }

    @Test func bruteForceRespectsCages() {
        let solution = values(wikiSolution)
        let cages = dominoCages(for: solution)
        #expect(BruteForceSolver.countSolutions(values(wikiPuzzle), cages: cages) == 1)
        #expect(BruteForceSolver.solve(values(wikiPuzzle), cages: cages) == solution)
        var wrong = cages
        wrong[0] = Cage(cells: wrong[0].cells, sum: wrong[0].sum + 1)
        #expect(BruteForceSolver.countSolutions(values(wikiPuzzle), cages: wrong) == 0)
    }

    @Test func malformedCagesHaveNoSolution() {
        let empty = Array(repeating: 0, count: 81)
        #expect(BruteForceSolver.countSolutions(empty, cages: [Cage(cells: [0, 1], sum: 3), Cage(cells: [1, 2], sum: 3)]) == 0)
        #expect(BruteForceSolver.countSolutions(empty, cages: [Cage(cells: [0, 81], sum: 3)]) == 0)
    }

    @Test func dominoCagesAloneLeaveFewSolutions() {
        let cages = dominoCages(for: values(wikiSolution))
        #expect(BruteForceSolver.countSolutions(Array(repeating: 0, count: 81), cages: cages, limit: 1) == 1)
    }

    @Test func cageOverflowIsContradictory() {
        var v = Array(repeating: 0, count: 81)
        v[0] = 9
        v[1] = 8
        #expect(Board(values: v, cages: [Cage(cells: [0, 1], sum: 10)]).isContradictory)
        #expect(!Board(values: v, cages: [Cage(cells: [0, 1], sum: 17)]).isContradictory)
    }

    @Test func gradesWithCages() throws {
        let cages = dominoCages(for: values(wikiSolution))
        let report = try #require(Grader.grade(values(wikiPuzzle), cages: cages))
        #expect(report.grade.tier == .easy)
    }

    @Test(arguments: 1...10)
    func partitionCoversBoardWithValidCages(seed: Int) {
        var rng = SplitMix64(seed: UInt64(seed))
        let solution = BruteForceSolver.randomSolution(using: &rng)
        let cages = KillerCages.partition(solution: solution, sizes: 2...5, using: &rng)
        #expect(cages.flatMap(\.cells).sorted() == Array(0..<81))
        for cage in cages {
            let digits = cage.cells.map { solution[$0] }
            #expect(Set(digits).count == digits.count)
            #expect(digits.reduce(0, +) == cage.sum)
            #expect(cage.cells.count <= 5)
        }
        #expect(BruteForceSolver.countSolutions(solution, cages: cages) == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter KillerBoardTests`
Expected: build FAILS with `value of type 'Board' has no member 'cageOf'`.

- [ ] **Step 3: Make Board cage-aware**

In `SudokuCore/Sources/SudokuCore/Model/Board.swift`:
- Add a stored property after `public let cages: [Cage]`:
```swift
    /// Index into `cages` for each cell, or -1 when the cell has no cage.
    public let cageOf: [Int]
```
- Replace the body of `init(values:cages:)` with:
```swift
        precondition(values.count == 81, "A board needs 81 values")
        self.values = values
        self.givens = values.map { $0 != 0 }
        self.cages = cages
        var cageOf = [Int](repeating: -1, count: 81)
        for (i, cage) in cages.enumerated() {
            for c in cage.cells where (0..<81).contains(c) { cageOf[c] = i }
        }
        self.cageOf = cageOf
        self.candidates = Array(repeating: .empty, count: 81)
        for c in 0..<81 where values[c] == 0 {
            var set = CandidateSet.all
            for p in Geometry.peers[c] where values[p] != 0 { set.remove(values[p]) }
            if cageOf[c] >= 0 {
                for p in cages[cageOf[c]].cells where (0..<81).contains(p) && values[p] != 0 { set.remove(values[p]) }
            }
            candidates[c] = set
        }
```
- Add after `isSolved`:
```swift
    /// Other cells in `cell`'s cage.
    public func cageMates(of cell: Int) -> [Int] {
        cageOf[cell] < 0 ? [] : cages[cageOf[cell]].cells.filter { $0 != cell }
    }
```
- In `place(_:at:)`, after the peers loop add:
```swift
        for p in cageMates(of: cell) { candidates[p].remove(digit) }
```

In `Board+Contradiction.swift`, before the final `return false` add:
```swift
        for cage in cages {
            let placed = cage.cells.map { values[$0] }.filter { $0 != 0 }
            let total = placed.reduce(0, +)
            if Set(placed).count != placed.count || total > cage.sum { return true }
            if placed.count == cage.cells.count && total != cage.sum { return true }
        }
```

- [ ] **Step 4: Make the brute-force solver cage-aware**

In `BruteForceSolver.swift`:
- Change the public API to:
```swift
    public static func countSolutions(_ values: [Int], cages: [Cage] = [], limit: Int = 2) -> Int {
        guard var state = SearchState(values, cages: cages) else { return 0 }
        var count = 0
        var first: [Int]?
        search(&state, limit: limit, count: &count, first: &first) { _ in }
        return count
    }

    public static func solve(_ values: [Int], cages: [Cage] = []) -> [Int]? {
        guard var state = SearchState(values, cages: cages) else { return nil }
        var count = 0
        var first: [Int]?
        search(&state, limit: 1, count: &count, first: &first) { _ in }
        return first
    }
```
- In `randomSolution`, change `SearchState(Array(repeating: 0, count: 81))!` to `SearchState(Array(repeating: 0, count: 81), cages: [])!`.
- Replace `SearchState` with:
```swift
private struct SearchState {
    var grid: [Int]
    var rowUsed = [UInt16](repeating: 0, count: 9)
    var colUsed = [UInt16](repeating: 0, count: 9)
    var boxUsed = [UInt16](repeating: 0, count: 9)
    var cageOf = [Int](repeating: -1, count: 81)
    var cageUsed: [UInt16] = []
    var cageSumLeft: [Int] = []
    var cageCellsLeft: [Int] = []

    /// Nil when the givens or cages are malformed or already conflict.
    init?(_ values: [Int], cages: [Cage]) {
        guard values.count == 81 else { return nil }
        grid = Array(repeating: 0, count: 81)
        cageUsed = Array(repeating: 0, count: cages.count)
        cageSumLeft = cages.map(\.sum)
        cageCellsLeft = cages.map(\.cells.count)
        for (i, cage) in cages.enumerated() {
            for c in cage.cells {
                guard (0..<81).contains(c), cageOf[c] == -1 else { return nil }
                cageOf[c] = i
            }
        }
        for c in 0..<81 where values[c] != 0 {
            let d = values[c]
            guard (1...9).contains(d), available(c) & (1 << d) != 0 else { return nil }
            set(c, d)
        }
    }

    func available(_ c: Int) -> UInt16 {
        var mask = ~(rowUsed[Geometry.row(c)] | colUsed[Geometry.col(c)] | boxUsed[Geometry.box(c)]) & 0b11_1111_1110
        let k = cageOf[c]
        guard k >= 0 else { return mask }
        mask &= ~cageUsed[k]
        var ok: UInt16 = 0
        for d in 1...9 where mask & (1 << d) != 0 {
            if SearchState.fillable(sum: cageSumLeft[k] - d, cells: cageCellsLeft[k] - 1, used: cageUsed[k] | (1 << d)) {
                ok |= 1 << d
            }
        }
        return ok
    }

    /// Whether `cells` distinct digits outside `used` can sum to `sum`.
    static func fillable(sum: Int, cells: Int, used: UInt16) -> Bool {
        if cells == 0 { return sum == 0 }
        var low = 0, high = 0, n = 0
        for d in 1...9 where used & (1 << d) == 0 && n < cells {
            low += d
            n += 1
        }
        guard n == cells else { return false }
        n = 0
        for d in stride(from: 9, through: 1, by: -1) where used & (1 << d) == 0 && n < cells {
            high += d
            n += 1
        }
        return low <= sum && sum <= high
    }

    mutating func set(_ c: Int, _ d: Int) {
        grid[c] = d
        let bit: UInt16 = 1 << d
        rowUsed[Geometry.row(c)] |= bit
        colUsed[Geometry.col(c)] |= bit
        boxUsed[Geometry.box(c)] |= bit
        let k = cageOf[c]
        if k >= 0 {
            cageUsed[k] |= bit
            cageSumLeft[k] -= d
            cageCellsLeft[k] -= 1
        }
    }

    mutating func unset(_ c: Int, _ d: Int) {
        grid[c] = 0
        let mask: UInt16 = ~(1 << d)
        rowUsed[Geometry.row(c)] &= mask
        colUsed[Geometry.col(c)] &= mask
        boxUsed[Geometry.box(c)] &= mask
        let k = cageOf[c]
        if k >= 0 {
            cageUsed[k] &= mask
            cageSumLeft[k] += d
            cageCellsLeft[k] += 1
        }
    }
}
```

- [ ] **Step 5: Let the grader take cages**

Replace `Grader` in `Grader.swift` with:
```swift
public enum Grader {
    /// Grades a puzzle. Nil unless it has exactly one solution and the solver finishes it.
    public static func grade(_ givens: [Int], cages: [Cage] = [], solver: LogicalSolver = .classic) -> GradeReport? {
        guard BruteForceSolver.countSolutions(givens, cages: cages) == 1,
              let solution = BruteForceSolver.solve(givens, cages: cages) else { return nil }
        return grade(givens, cages: cages, solution: solution, solver: solver)
    }

    /// Grades a puzzle whose uniqueness the caller has already proved.
    public static func grade(_ givens: [Int], cages: [Cage] = [], solution: [Int], solver: LogicalSolver = .classic) -> GradeReport? {
        let result = solver.solve(Board(values: givens, cages: cages))
        guard result.solved, result.board.values == solution else { return nil }
        let used = Set(result.steps.map(\.technique))
        let techniques = TechniqueID.allCases.filter(used.contains)
        let tier = techniques.map(\.tier).max() ?? .easy
        let score = result.steps.reduce(0) { $0 + $1.technique.weight }
        return GradeReport(grade: Grade(tier: tier, score: score), techniquesRequired: techniques)
    }
}
```

- [ ] **Step 6: Add the cage partition**

`SudokuCore/Sources/SudokuCore/Generation/KillerCages.swift`:
```swift
public enum KillerCages {
    static func neighbours(_ cell: Int) -> [Int] {
        let r = Geometry.row(cell), c = Geometry.col(cell)
        var out: [Int] = []
        if r > 0 { out.append(cell - 9) }
        if r < 8 { out.append(cell + 9) }
        if c > 0 { out.append(cell - 1) }
        if c < 8 { out.append(cell + 1) }
        return out
    }

    /// Splits the grid into orthogonally connected cages whose digits (from `solution`) never repeat.
    /// Cages aim for a random size in `sizes`; leftover single cells merge into a neighbouring cage
    /// when that keeps the cage valid and within the maximum size.
    public static func partition<R: RandomNumberGenerator>(solution: [Int], sizes: ClosedRange<Int>, using rng: inout R) -> [Cage] {
        var cageOf = [Int](repeating: -1, count: 81)
        var groups: [[Int]] = []
        for start in Array(0..<81).shuffled(using: &rng) where cageOf[start] == -1 {
            let target = Int.random(in: sizes, using: &rng)
            var cells = [start]
            var digits = CandidateSet([solution[start]])
            cageOf[start] = groups.count
            while cells.count < target {
                let frontier = Set(cells.flatMap(neighbours))
                    .filter { cageOf[$0] == -1 && !digits.contains(solution[$0]) }
                    .sorted()
                guard let next = frontier.randomElement(using: &rng) else { break }
                cells.append(next)
                digits.insert(solution[next])
                cageOf[next] = groups.count
            }
            groups.append(cells)
        }
        for i in groups.indices where groups[i].count == 1 {
            let cell = groups[i][0]
            let options = neighbours(cell).map { cageOf[$0] }.filter { j in
                j != i && groups[j].count < sizes.upperBound && !groups[j].contains { solution[$0] == solution[cell] }
            }
            guard let j = options.first else { continue }
            groups[j].append(cell)
            groups[i] = []
            cageOf[cell] = j
        }
        return groups.filter { !$0.isEmpty }.map { cells in
            Cage(cells: cells.sorted(), sum: cells.map { solution[$0] }.reduce(0, +))
        }
    }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore`
Expected: PASS (everything, including the classic suites — the brute-force and grader changes keep their default behaviour).

- [ ] **Step 8: Commit**

```bash
git add SudokuCore
git commit -m "feat(killer): cage-aware board, brute force, grader and cage partition"
```

---

### Task 2: Cage math and cage techniques

**Files:**
- Modify: `SudokuCore/Sources/SudokuCore/Model/TechniqueID.swift`
- Create: `SudokuCore/Sources/SudokuCore/Techniques/CageMath.swift`
- Create: `SudokuCore/Sources/SudokuCore/Techniques/CageTechniques.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/CageTechniqueTests.swift`

**Interfaces:**
- Produces: `TechniqueID` cases `cageCompletion, uniqueCageCombination, cageCombination, innieOutie1, cageLockedDigit, innieOutie2, innieOutieMulti` and `isKillerOnly: Bool`; `CageCompletion()`, `UniqueCageCombination()`, `CageCombination()`, `CageLockedDigit()`; internal `CageMath.combinations(sum:count:allowed:)`, `CageMath.possibilities(of:sum:on:mustDiffer:)`, `CageMath.state(of:on:)`.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/CageTechniqueTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct CageTechniqueTests {
    func board(_ cages: [Cage], placing placed: [Int: Int] = [:]) -> Board {
        var v = Array(repeating: 0, count: 81)
        for (c, d) in placed { v[c] = d }
        return Board(values: v, cages: cages)
    }

    @Test func cageCompletion() throws {
        let b = board([Cage(cells: [0, 1], sum: 8)], placing: [0: 5])
        let step = try #require(CageCompletion().find(in: b))
        #expect(step.technique == .cageCompletion)
        #expect(step.placements == [CellDigit(cell: 1, digit: 3)])
    }

    @Test func uniqueCageCombination() throws {
        let b = board([Cage(cells: [0, 1], sum: 3)])
        let step = try #require(UniqueCageCombination().find(in: b))
        #expect(step.technique == .uniqueCageCombination)
        #expect(Set(step.eliminations) == Set([0, 1].flatMap { c in (3...9).map { CellDigit(cell: c, digit: $0) } }))
    }

    @Test func cageCombinationUsesCandidates() throws {
        var b = board([Cage(cells: [0, 9], sum: 10)])
        b.candidates[0] = CandidateSet([1, 2])
        #expect(UniqueCageCombination().find(in: b) == nil)
        let step = try #require(CageCombination().find(in: b))
        #expect(step.technique == .cageCombination)
        #expect(Set(step.eliminations) == Set((1...7).map { CellDigit(cell: 9, digit: $0) }))
    }

    @Test func cageLockedDigit() throws {
        let b = board([Cage(cells: [0, 1], sum: 3)])
        let step = try #require(CageLockedDigit().find(in: b))
        #expect(step.technique == .cageLockedDigit)
        #expect(step.digits == [1])
        #expect(step.eliminations.count == 13)   // rest of row 0 (7) + rest of box 0 (6)
        #expect(step.eliminations.allSatisfy { $0.digit == 1 })
    }

    @Test func classicBoardsHaveNoCageSteps() {
        for t in [CageCompletion(), UniqueCageCombination(), CageCombination(), CageLockedDigit()] as [any Technique] {
            #expect(t.find(in: emptyBoard()) == nil)
        }
    }

    @Test func killerOnlyIDs() {
        #expect(TechniqueID.innieOutie2.isKillerOnly)
        #expect(!TechniqueID.xWing.isKillerOnly)
        #expect(TechniqueID.cageCombination.tier == .medium)
        #expect(TechniqueID.innieOutieMulti.tier == .fiendish)
    }

    @Test func sound() {
        for t in [CageCompletion(), UniqueCageCombination(), CageCombination(), CageLockedDigit()] as [any Technique] {
            #expect(killerSoundnessViolations(of: t, seeds: 1...25).isEmpty, "\(t.id)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter CageTechniqueTests`
Expected: build FAILS with `cannot find 'CageCompletion' in scope`.

- [ ] **Step 3: Extend TechniqueID**

In `TechniqueID.swift`:
- After `case cellForcingChain, unitForcingChain, digitForcingChain, nestedForcingChain` add:
```swift
    case cageCompletion, uniqueCageCombination, cageCombination
    case innieOutie1, cageLockedDigit, innieOutie2, innieOutieMulti
```
- In `tier` add:
```swift
        case .cageCompletion, .uniqueCageCombination:
            return .easy
        case .cageCombination:
            return .medium
        case .innieOutie1:
            return .hard
        case .cageLockedDigit, .innieOutie2:
            return .expert
        case .innieOutieMulti:
            return .fiendish
```
- In `weight` add:
```swift
        case .cageCompletion: return 1
        case .uniqueCageCombination: return 3
        case .cageCombination: return 12
        case .innieOutie1: return 40
        case .cageLockedDigit: return 102
        case .innieOutie2: return 105
        case .innieOutieMulti: return 155
```
- In `displayName` add:
```swift
        case .cageCompletion: return "Cage Completion"
        case .uniqueCageCombination: return "Unique Cage Combination"
        case .cageCombination: return "Cage Combinations"
        case .innieOutie1: return "45 Rule (One House)"
        case .cageLockedDigit: return "Cage-Locked Digit"
        case .innieOutie2: return "45 Rule (Two Houses)"
        case .innieOutieMulti: return "45 Rule (Three+ Houses)"
```
- Add the property:
```swift
    /// Techniques that only apply to Killer puzzles.
    public var isKillerOnly: Bool {
        switch self {
        case .cageCompletion, .uniqueCageCombination, .cageCombination,
             .innieOutie1, .cageLockedDigit, .innieOutie2, .innieOutieMulti:
            return true
        default:
            return false
        }
    }
```

- [ ] **Step 4: Implement cage math**

`SudokuCore/Sources/SudokuCore/Techniques/CageMath.swift`:
```swift
enum CageMath {
    /// What's left of a cage: its empty cells, the sum they need, and the digits still unused.
    struct CageState {
        let empties: [Int]
        let sumLeft: Int
        let allowed: CandidateSet
    }

    static func state(of cage: Cage, on board: Board) -> CageState {
        let placed = cage.cells.map { board.values[$0] }.filter { $0 != 0 }
        return CageState(
            empties: cage.cells.filter { board.values[$0] == 0 },
            sumLeft: cage.sum - placed.reduce(0, +),
            allowed: CandidateSet.all.subtracting(CandidateSet(placed))
        )
    }

    /// Sets of `count` distinct digits from `allowed` that sum to `sum`.
    static func combinations(sum: Int, count: Int, allowed: CandidateSet = .all) -> [CandidateSet] {
        var out: [CandidateSet] = []
        func go(_ from: Int, _ left: Int, _ n: Int, _ acc: CandidateSet) {
            if n == 0 {
                if left == 0 { out.append(acc) }
                return
            }
            guard from <= 9 else { return }
            for d in from...9 where allowed.contains(d) && d <= left {
                var next = acc
                next.insert(d)
                go(d + 1, left - d, n - 1, next)
            }
        }
        go(1, sum, count, .empty)
        return out
    }

    /// For each cell, the digits it takes in at least one assignment where the cells sum to `sum`,
    /// fit their candidates (placed cells are fixed), and pairs that `mustDiffer` differ.
    static func possibilities(of cells: [Int], sum: Int, on board: Board, mustDiffer: (Int, Int) -> Bool) -> [CandidateSet] {
        var result = [CandidateSet](repeating: .empty, count: cells.count)
        var chosen = [Int](repeating: 0, count: cells.count)
        func options(_ i: Int) -> [Int] {
            board.values[cells[i]] != 0 ? [board.values[cells[i]]] : board.candidates[cells[i]].digits
        }
        func go(_ i: Int, _ left: Int) {
            if i == cells.count {
                if left == 0 { for j in cells.indices { result[j].insert(chosen[j]) } }
                return
            }
            let after = cells.count - i - 1
            for d in options(i) where d <= left && left - d <= 9 * after {
                guard (0..<i).allSatisfy({ chosen[$0] != d || !mustDiffer(cells[$0], cells[i]) }) else { continue }
                chosen[i] = d
                go(i + 1, left - d)
            }
        }
        go(0, sum)
        return result
    }
}
```

- [ ] **Step 5: Implement the cage techniques**

`SudokuCore/Sources/SudokuCore/Techniques/CageTechniques.swift`:
```swift
/// A cage with one empty cell: it takes whatever the sum still needs.
public struct CageCompletion: Technique {
    public init() {}
    public var id: TechniqueID { .cageCompletion }

    public func find(in board: Board) -> Step? {
        for cage in board.cages {
            let s = CageMath.state(of: cage, on: board)
            guard s.empties.count == 1, (1...9).contains(s.sumLeft), board.has(s.sumLeft, at: s.empties[0]) else { continue }
            return Step(technique: id, patternCells: cage.cells, placements: [CellDigit(cell: s.empties[0], digit: s.sumLeft)], digits: [s.sumLeft])
        }
        return nil
    }
}

/// A cage whose sum and size allow only one set of digits (e.g. 3 in two cells = 1+2).
public struct UniqueCageCombination: Technique {
    public init() {}
    public var id: TechniqueID { .uniqueCageCombination }

    public func find(in board: Board) -> Step? {
        for cage in board.cages {
            let s = CageMath.state(of: cage, on: board)
            guard s.empties.count >= 2 else { continue }
            let combos = CageMath.combinations(sum: s.sumLeft, count: s.empties.count, allowed: s.allowed)
            guard combos.count == 1 else { continue }
            let eliminations = s.empties.flatMap { c in
                board.candidates[c].subtracting(combos[0]).digits.map { CellDigit(cell: c, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            return Step(technique: id, patternCells: cage.cells, eliminations: eliminations, digits: combos[0].digits)
        }
        return nil
    }
}

/// Keeps only digits that appear in some way of filling the cage that fits the candidates.
public struct CageCombination: Technique {
    public init() {}
    public var id: TechniqueID { .cageCombination }

    public func find(in board: Board) -> Step? {
        for cage in board.cages {
            let s = CageMath.state(of: cage, on: board)
            guard s.empties.count >= 2 else { continue }
            let possible: [CandidateSet]
            if s.empties.count <= 5 {
                possible = CageMath.possibilities(of: s.empties, sum: s.sumLeft, on: board) { _, _ in true }
            } else {
                // Large cages: digit-level filtering keeps the search small.
                let union = CageMath.combinations(sum: s.sumLeft, count: s.empties.count, allowed: s.allowed)
                    .filter { combo in combo.digits.allSatisfy { d in s.empties.contains { board.candidates[$0].contains(d) } } }
                    .reduce(CandidateSet.empty) { $0.union($1) }
                possible = s.empties.map { _ in union }
            }
            let eliminations = zip(s.empties, possible).flatMap { c, ok in
                board.candidates[c].subtracting(ok).digits.map { CellDigit(cell: c, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            return Step(technique: id, patternCells: cage.cells, patternCandidates: board.candidateDigits(of: s.empties),
                        eliminations: eliminations)
        }
        return nil
    }
}

/// A digit every possible combination of a cage needs, whose places in the cage all lie in one
/// house: it leaves the rest of that house (a killer pair is the two-digit case).
public struct CageLockedDigit: Technique {
    public init() {}
    public var id: TechniqueID { .cageLockedDigit }

    public func find(in board: Board) -> Step? {
        for cage in board.cages {
            let s = CageMath.state(of: cage, on: board)
            guard s.empties.count >= 2 else { continue }
            let combos = CageMath.combinations(sum: s.sumLeft, count: s.empties.count, allowed: s.allowed)
                .filter { combo in combo.digits.allSatisfy { d in s.empties.contains { board.candidates[$0].contains(d) } } }
            guard let first = combos.first else { continue }
            let required = combos.reduce(first) { $0.intersection($1) }
            for d in required.digits {
                let hosts = s.empties.filter { board.candidates[$0].contains(d) }
                guard !hosts.isEmpty else { continue }
                let houses = Geometry.houses.indices.filter { h in hosts.allSatisfy { Geometry.houses[h].contains($0) } }
                var eliminations: [CellDigit] = []
                for h in houses {
                    for c in Geometry.houses[h] where !cage.cells.contains(c) && board.has(d, at: c) {
                        let cd = CellDigit(cell: c, digit: d)
                        if !eliminations.contains(cd) { eliminations.append(cd) }
                    }
                }
                guard !eliminations.isEmpty else { continue }
                return Step(technique: id, patternCells: cage.cells, patternCandidates: hosts.map { CellDigit(cell: $0, digit: d) },
                            eliminations: eliminations, regions: houses.map(Region.init(house:)), digits: [d])
            }
        }
        return nil
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter CageTechniqueTests`
Expected: PASS (7 tests).

- [ ] **Step 7: Commit**

```bash
git add SudokuCore
git commit -m "feat(killer): add cage completion, cage combinations and cage-locked digits"
```

---

### Task 3: The 45 rule (innies and outies)

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Techniques/InnieOutie.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/InnieOutieTests.swift`

**Interfaces:**
- Produces: `InnieOutie.oneHouse`, `.twoHouses`, `.manyHouses` (each a `Technique`); internal `KillerRegions.pairs`, `KillerRegions.lines(_:)`.

A region of k disjoint houses sums to 45k. Cages fully inside contribute their sums; the cells of partly-inside cages that lie inside ("innies") sum to 45k − those sums, and the cells outside ("outies") sum to (sum of partly-inside cages) − (innie sum). One unknown cell → placement; up to five cells → keep only digits that fit some assignment (cells that see each other or share a cage must differ). Regions with an uncaged cell are skipped.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/InnieOutieTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct InnieOutieTests {
    func cages(_ list: [([Int], Int)]) -> Board {
        Board(values: Array(repeating: 0, count: 81), cages: list.map { Cage(cells: $0.0, sum: $0.1) })
    }

    @Test func innie() throws {
        let b = cages([
            ([rc(0, 0), rc(0, 1), rc(0, 2)], 6), ([rc(0, 3), rc(0, 4), rc(0, 5)], 15),
            ([rc(0, 6), rc(0, 7)], 15), ([rc(0, 8), rc(1, 8)], 10),
        ])
        let step = try #require(InnieOutie.oneHouse.find(in: b))
        #expect(step.technique == .innieOutie1)
        #expect(step.placements == [CellDigit(cell: rc(0, 8), digit: 9)])
        #expect(step.regions == [.row(0)])
    }

    @Test func outie() throws {
        let b = cages([
            ([rc(0, 0), rc(0, 1), rc(0, 2)], 6), ([rc(0, 3), rc(0, 4), rc(0, 5)], 15),
            ([rc(0, 6), rc(0, 7), rc(0, 8), rc(1, 8)], 30),
        ])
        let step = try #require(InnieOutie.oneHouse.find(in: b))
        #expect(step.placements == [CellDigit(cell: rc(1, 8), digit: 6)])
    }

    @Test func twoHouses() throws {
        let rows01 = (0..<18).filter { $0 != rc(1, 8) }
        let b = cages([(rows01, 81), ([rc(1, 8), rc(2, 8)], 10)])
        #expect(InnieOutie.oneHouse.find(in: b) == nil)
        let step = try #require(InnieOutie.twoHouses.find(in: b))
        #expect(step.technique == .innieOutie2)
        #expect(step.placements == [CellDigit(cell: rc(1, 8), digit: 9)])
        #expect(step.regions == [.row(0), .row(1)])
    }

    @Test func partlyCagedRegionsAreSkipped() {
        let b = cages([([rc(0, 0), rc(0, 1)], 3)])
        #expect(InnieOutie.oneHouse.find(in: b) == nil)
        #expect(InnieOutie.twoHouses.find(in: b) == nil)
        #expect(InnieOutie.manyHouses.find(in: b) == nil)
    }

    @Test func sound() {
        for t in [InnieOutie.oneHouse, .twoHouses, .manyHouses] {
            #expect(killerSoundnessViolations(of: t, seeds: 1...25).isEmpty, "\(t.id)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter InnieOutieTests`
Expected: build FAILS with `cannot find 'InnieOutie' in scope`.

- [ ] **Step 3: Implement**

`SudokuCore/Sources/SudokuCore/Techniques/InnieOutie.swift`:
```swift
enum KillerRegions {
    /// Two adjacent houses: consecutive rows, consecutive columns, side-by-side boxes.
    static let pairs: [[Int]] =
        (0..<8).map { [$0, $0 + 1] }
        + (9..<17).map { [$0, $0 + 1] }
        + (0..<9).filter { $0 % 3 != 2 }.map { [18 + $0, 19 + $0] }
        + (0..<6).map { [18 + $0, 21 + $0] }

    /// `k` consecutive rows, then `k` consecutive columns.
    static func lines(_ k: Int) -> [[Int]] {
        (0...(9 - k)).map { Array($0..<($0 + k)) } + (0...(9 - k)).map { Array((9 + $0)..<(9 + $0 + k)) }
    }
}

/// The 45 rule: k disjoint houses sum to 45k.
public struct InnieOutie: Technique {
    public let id: TechniqueID
    let regions: [[Int]]

    public static let oneHouse = InnieOutie(id: .innieOutie1, regions: (0..<27).map { [$0] })
    public static let twoHouses = InnieOutie(id: .innieOutie2, regions: KillerRegions.pairs)
    public static let manyHouses = InnieOutie(id: .innieOutieMulti, regions: KillerRegions.lines(3) + KillerRegions.lines(4))

    public func find(in board: Board) -> Step? {
        guard !board.cages.isEmpty else { return nil }
        var groups: [(cells: [Int], sum: Int, region: [Int])] = []
        for region in regions {
            let inRegion = Set(region.flatMap { Geometry.houses[$0] })
            guard inRegion.allSatisfy({ board.cageOf[$0] >= 0 }) else { continue }
            let touching = Set(inRegion.map { board.cageOf[$0] }).sorted()
            let inside = touching.filter { board.cages[$0].cells.allSatisfy(inRegion.contains) }
            let partial = touching.filter { !inside.contains($0) }
            guard !partial.isEmpty else { continue }
            let innieSum = 45 * region.count - inside.map { board.cages[$0].sum }.reduce(0, +)
            let innies = partial.flatMap { board.cages[$0].cells.filter(inRegion.contains) }.sorted()
            let outies = partial.flatMap { board.cages[$0].cells.filter { !inRegion.contains($0) } }.sorted()
            let outieSum = partial.map { board.cages[$0].sum }.reduce(0, +) - innieSum
            groups.append((innies, innieSum, region))
            groups.append((outies, outieSum, region))
        }
        // Single unknown cells first, then small groups.
        for g in groups {
            let empties = g.cells.filter { board.values[$0] == 0 }
            guard empties.count == 1 else { continue }
            let d = g.sum - g.cells.map { board.values[$0] }.reduce(0, +)
            guard (1...9).contains(d), board.has(d, at: empties[0]) else { continue }
            return Step(technique: id, patternCells: g.cells, placements: [CellDigit(cell: empties[0], digit: d)],
                        regions: g.region.map(Region.init(house:)), digits: [d])
        }
        for g in groups where g.cells.count <= 5 {
            let empties = g.cells.filter { board.values[$0] == 0 }
            guard empties.count >= 2 else { continue }
            let possible = CageMath.possibilities(of: g.cells, sum: g.sum, on: board) { a, b in
                Geometry.sees(a, b) || board.cageOf[a] == board.cageOf[b]
            }
            let eliminations = zip(g.cells, possible).flatMap { c, ok in
                board.values[c] != 0 ? [] : board.candidates[c].subtracting(ok).digits.map { CellDigit(cell: c, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            return Step(technique: id, patternCells: g.cells, patternCandidates: board.candidateDigits(of: empties),
                        eliminations: eliminations, regions: g.region.map(Region.init(house:)))
        }
        return nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path SudokuCore --filter InnieOutieTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(killer): add the 45 rule across one, two and several houses"
```

---

### Task 4: Killer catalog, rules, generator and CLI

**Files:**
- Modify: `Technique.swift` (add `TechniqueCatalog.killer`), `LogicalSolver.swift` (add `LogicalSolver.killer`)
- Create: `SudokuCore/Sources/SudokuCore/Generation/KillerGenerator.swift`
- Modify: `SudokuCore/Sources/sudoku-forge/main.swift`
- Modify: `SudokuCore/Tests/SudokuCoreTests/LogicalSolverTests.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/KillerGeneratorTests.swift`
- Modify: spec §4.6 (tier rule)

**Interfaces:**
- Produces: `TechniqueCatalog.killer`, `LogicalSolver.killer`, `KillerRules.forTier(_:)` (`givens`, `cageSizes`), `KillerGenerator(solver:)` with `generate(tier:using:deadline:) -> Puzzle?`.

- [ ] **Step 1: Write the failing tests**

In `LogicalSolverTests.swift`, replace `catalogCoversEveryTechniqueOnceInTierOrder` with:
```swift
    @Test func catalogCoversEveryTechniqueOnceInTierOrder() {
        let classic = TechniqueCatalog.classic.map(\.id)
        let killer = TechniqueCatalog.killer.map(\.id)
        #expect(Set(classic) == Set(TechniqueID.allCases.filter { !$0.isKillerOnly }))
        #expect(classic.count == Set(classic).count)
        #expect(classic.map(\.tier) == classic.map(\.tier).sorted())
        #expect(killer.count == Set(killer).count)
        #expect(killer.map(\.tier) == killer.map(\.tier).sorted())
        #expect(Set(killer) == Set(TechniqueID.allCases.filter { !$0.rawValue.hasPrefix("uniqueRectangle") }))
    }
```

`SudokuCore/Tests/SudokuCoreTests/KillerGeneratorTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct KillerGeneratorTests {
    @Test(arguments: [Tier.easy, .medium, .hard])
    func generatesRequestedTier(tier: Tier) throws {
        var rng = SplitMix64(seed: 5)
        let p = try #require(KillerGenerator().generate(tier: tier, using: &rng))
        let rules = KillerRules.forTier(tier)
        #expect(p.mode == .killer)
        #expect(p.grade.tier == tier)
        #expect(p.cages.flatMap(\.cells).sorted() == Array(0..<81))
        for cage in p.cages {
            #expect(cage.cells.map { p.solution[$0] }.reduce(0, +) == cage.sum)
            #expect(cage.cells.count <= rules.cageSizes.upperBound)
        }
        let revealed = (0..<81).filter { c in p.givens[c] != 0 || p.cages.contains { $0.cells == [c] } }.count
        #expect(rules.givens.contains(revealed))
        #expect(BruteForceSolver.countSolutions(p.givens, cages: p.cages) == 1)
        #expect(Grader.grade(p.givens, cages: p.cages, solver: .killer)?.grade == p.grade)
    }

    @Test func rulesFollowTheSpec() {
        #expect(KillerRules.forTier(.easy).givens == 6...12)
        #expect(KillerRules.forTier(.expert).givens == 0...0)
        #expect(KillerRules.forTier(.nightmare).cageSizes == 3...8)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path SudokuCore --filter "KillerGeneratorTests|LogicalSolverTests"`
Expected: build FAILS with `type 'TechniqueCatalog' has no member 'killer'`.

- [ ] **Step 3: Add the Killer catalog and solver**

Append inside `enum TechniqueCatalog` (after `classic`):
```swift

    /// Killer techniques: the classic catalog minus unique rectangles (swapping digits changes
    /// cage sums, so the deadly-pattern argument fails) plus the cage techniques, by tier then weight.
    public static let killer: [any Technique] = {
        let cageTechniques: [any Technique] = [
            CageCompletion(), UniqueCageCombination(), CageCombination(),
            InnieOutie.oneHouse, CageLockedDigit(), InnieOutie.twoHouses, InnieOutie.manyHouses,
        ]
        let pool = cageTechniques + classic.filter { !$0.id.rawValue.hasPrefix("uniqueRectangle") }
        return pool.enumerated()
            .sorted { ($0.element.id.tier, $0.element.id.weight, $0.offset) < ($1.element.id.tier, $1.element.id.weight, $1.offset) }
            .map(\.element)
    }()
```

In `LogicalSolver.swift`, after `public static let classic …` add:
```swift
    public static let killer = LogicalSolver(techniques: TechniqueCatalog.killer)
```

- [ ] **Step 4: Implement the Killer generator**

`SudokuCore/Sources/SudokuCore/Generation/KillerGenerator.swift`:
```swift
/// Structure allowed at each Killer tier (spec §4.6).
public struct KillerRules: Sendable, Equatable {
    public let givens: ClosedRange<Int>
    public let cageSizes: ClosedRange<Int>

    public static func forTier(_ tier: Tier) -> KillerRules {
        switch tier {
        case .easy: return KillerRules(givens: 6...12, cageSizes: 2...3)
        case .medium: return KillerRules(givens: 0...6, cageSizes: 2...4)
        case .hard: return KillerRules(givens: 0...3, cageSizes: 2...5)
        case .expert: return KillerRules(givens: 0...0, cageSizes: 2...5)
        case .fiendish: return KillerRules(givens: 0...0, cageSizes: 2...6)
        case .diabolical: return KillerRules(givens: 0...0, cageSizes: 3...7)
        case .nightmare: return KillerRules(givens: 0...0, cageSizes: 3...8)
        }
    }
}

public struct KillerGenerator: Sendable {
    public let solver: LogicalSolver

    public init(solver: LogicalSolver = .killer) {
        self.solver = solver
    }

    /// A unique, logic-solvable Killer puzzle of exactly `tier` whose givens and cages fit the
    /// tier's rules, or nil when the deadline passes.
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
        let rules = KillerRules.forTier(tier)
        let capped = LogicalSolver(techniques: solver.techniques.filter { $0.id.tier <= tier })
        let solution = BruteForceSolver.randomSolution(using: &rng)
        let cages = KillerCages.partition(solution: solution, sizes: rules.cageSizes, using: &rng)
        // A one-cell cage gives its digit away, so it counts as a given.
        let singletonCells = Set(cages.filter { $0.cells.count == 1 }.map { $0.cells[0] })
        guard singletonCells.count <= rules.givens.upperBound else { return nil }

        var givens = solution
        func revealed() -> Int { (0..<81).filter { givens[$0] != 0 || singletonCells.contains($0) }.count }
        var accepted: GradeReport?
        for c in Array(0..<81).shuffled(using: &rng) where revealed() > rules.givens.lowerBound {
            givens[c] = 0
            if BruteForceSolver.countSolutions(givens, cages: cages) == 1,
               let report = Grader.grade(givens, cages: cages, solution: solution, solver: capped) {
                accepted = report
            } else {
                givens[c] = solution[c]
            }
        }
        guard let report = accepted, report.grade.tier == tier, rules.givens.contains(revealed()) else { return nil }
        return Puzzle(
            id: String(rng.next(), radix: 16),
            mode: .killer,
            givens: givens,
            cages: cages,
            solution: solution,
            grade: report.grade,
            techniquesRequired: report.techniquesRequired
        )
    }
}
```

- [ ] **Step 5: Killer mode in the CLI**

In `SudokuCore/Sources/sudoku-forge/main.swift`:
- Delete the `guard options.mode == .classic else { … }` block.
- Replace the `guard tier <= LogicalSolver.classic.maxTier …` block's condition with `tier <= (options.mode == .classic ? LogicalSolver.classic.maxTier : LogicalSolver.killer.maxTier)` (message unchanged apart from the max shown the same way).
- Replace `let generator = ClassicGenerator()` and the `generator.generate(...)` call with:
```swift
func generate(_ tier: Tier, _ deadline: ContinuousClock.Instant) -> Puzzle? {
    switch options.mode {
    case .classic: return ClassicGenerator().generate(tier: tier, using: &rng, deadline: deadline)
    case .killer: return KillerGenerator().generate(tier: tier, using: &rng, deadline: deadline)
    }
}
```
and inside the loop use `guard let puzzle = generate(tier, deadline) else { … }`.

- [ ] **Step 6: Amend the spec**

In spec §4.6, replace "A Killer puzzle's tier is the maximum of its hardest technique's tier and the tier implied by givens/cage sizes." with "A Killer puzzle's tier is its hardest technique's tier; its givens and cage sizes must also fit that tier's row of the table. Unique rectangles are never used in Killer (swapping digits changes cage sums)."

- [ ] **Step 7: Run the whole suite**

Run: `swift test --package-path SudokuCore`
Expected: PASS. Record Killer generation times; if Easy/Medium/Hard generation is unreliable for the spec's givens ranges, rule on the range (spec amendment) rather than weakening the tier assertion.

- [ ] **Step 8: CLI check across tiers**

Run:
```bash
swift build --package-path SudokuCore -c release
for t in easy medium hard expert fiendish diabolical nightmare; do
  /usr/bin/time -p SudokuCore/.build/release/sudoku-forge --mode killer --tier $t --count 2 --seed 1 --timeout 120 --out "$TMPDIR/killer-$t.json" 2>&1 | grep -E "score|timed out|real"
done
```
Expected: two puzzles per tier, or a recorded timeout for tiers that need longer library builds (record the times in the ledger).

- [ ] **Step 9: Commit**

```bash
git add SudokuCore docs
git commit -m "feat(killer): killer catalog, generator and CLI mode"
```
