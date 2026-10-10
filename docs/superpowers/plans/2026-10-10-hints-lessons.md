# Hints & Lessons Implementation Plan (Plan 6 of 7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teaching hints (spec §7): diagnose the player's board, then Nudge → Spotlight → Lesson modal (animated example board, explanation, "Show me" on the player's board), every level logged for stats.

**Architecture:** First the solver is hardened for player boards (Plan 1 review): singles and hidden-digit techniques ignore digits already placed in a house, and "solved" requires a valid grid. `Step` becomes `Codable` and gains `groups` (secondary highlights: colours, fins, subset cells) so hints can draw everything a technique uses. `HintEngine` (SudokuGame) turns a `GameSession` into a diagnosis — solved, mistake, incomplete candidates in a region, a step, or beyond the engine — by building a board from the player's entries and notes. Lessons are pre-found example states per technique (written by `sudoku-forge --lessons`) plus hand-written explanations. The app adds a hint bar, spotlight overlay and a lesson sheet that animates the example step.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-10-10-hard-sudoku-design.md` (§7)

## Global Constraints

- Hints never place or eliminate on the player's board except via "Show me", which is logged as a reveal.
- Diagnosis order (spec §7.1): mistake → incomplete candidates → step (easiest technique on the player's own marks).
- A wrong placed digit, or notes in a cell that omit its solution digit, counts as a mistake. Empty notes mean "not pencilled", never a mistake.
- Notes are sanitised before solving: a note for a digit already placed in a peer or cage mate is dropped (stale, not wrong).
- Steps whose technique isn't a single (full house, naked/hidden single, cage completion) need the player's notes in every cell they touch; otherwise the diagnosis is "incomplete candidates".
- Hint levels logged in `AssistLog.hints`: `nudge`, `spotlight`, `lesson`, `showMe`.

## Review Focus

1. **Stale candidates on player boards** (a note for a digit already in the row) → no hint built on it. Tasks 1 and 3 tests.
2. **Notes missing the solution digit** → "mistake", not a misleading hint. Task 3 test.
3. **Player with no notes at all** → singles still hinted; harder techniques ask for candidates. Task 3 test.
4. **Show me** → undoable, logs `showMe` and a reveal, applies exactly the step. Task 3 test.
5. **Techniques with no lesson example found** → lesson modal shows the explanation without a board, no crash. Task 5 code.

## File Structure

```
SudokuCore/Sources/SudokuCore/
├── Techniques/Singles.swift, Intersections.swift, Subsets.swift   (modify: ignore placed digits)
├── Solvers/LogicalSolver.swift                                    (modify: solved = valid)
├── Model/Step.swift                                               (modify: Codable, groups)
├── Techniques/UniqueRectangles.swift, Coloring.swift, Fish.swift  (modify: groups/regions/digits)
└── Lessons/LessonExample.swift, LessonFinder.swift                (new)
SudokuCore/Sources/sudoku-forge/main.swift                         (modify: --lessons)
SudokuCore/Sources/SudokuGame/
├── HintEngine.swift, HintText.swift, LessonText.swift             (new)
└── GameSession+Hints.swift                                        (new)
App/Views/HintBar.swift, LessonView.swift (new); BoardView.swift, GameView.swift, ControlsView.swift (modify)
App/Lessons/lessons.json                                           (generated)
```

---

### Task 1: Harden the solver for player boards

**Files:**
- Modify: `Singles.swift`, `Intersections.swift`, `Subsets.swift`, `LogicalSolver.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/PlayerBoardTests.swift`

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/PlayerBoardTests.swift`:
```swift
import Testing
import SudokuCore

@Suite struct PlayerBoardTests {
    @Test func fullHouseUsesTheMissingDigitNotStaleCandidates() {
        var v = values(wikiSolution)
        v[0] = 0
        var b = Board(values: v)
        b.candidates[0] = CandidateSet([9])          // stale/wrong mark
        #expect(FullHouse().find(in: b)?.placements == [CellDigit(cell: 0, digit: 5)])
    }

    @Test func hiddenTechniquesIgnorePlacedDigits() {
        var b = emptyBoard()
        b.place(4, at: rc(0, 0))
        b.candidates[rc(0, 5)].insert(4)             // stale 4 elsewhere in row 0
        #expect(HiddenSingle().find(in: b).map { $0.digits != [4] || $0.regions != [.row(0)] } ?? true)
        b.candidates[rc(0, 6)].insert(4)
        #expect(HiddenSubset(size: 2).find(in: b).map { !$0.digits.contains(4) } ?? true)
        #expect(Pointing().find(in: b).map { $0.digits != [4] } ?? true)
        #expect(BoxLineReduction().find(in: b).map { $0.digits != [4] } ?? true)
    }

    @Test func fullGridWithDuplicatesIsNotSolved() {
        var v = values(wikiSolution)
        v[0] = 3   // duplicate 3 in row 0
        #expect(!LogicalSolver.classic.solve(Board(values: v)).solved)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test -c release --package-path SudokuCore --filter PlayerBoardTests`
Expected: FAIL (FullHouse places 9; duplicates report solved).

- [ ] **Step 3: Implement**

In `Singles.swift`, `FullHouse.find`: replace the `guard … let digit = board.candidates[empty[0]].single` logic with the house's single missing digit:
```swift
            let empty = house.filter { board.values[$0] == 0 }
            guard empty.count == 1 else { continue }
            let missing = CandidateSet.all.subtracting(CandidateSet(house.map { board.values[$0] }.filter { $0 != 0 }))
            guard let digit = missing.single else { continue }
```
In `HiddenSingle.find`, skip digits already placed in the house: before counting, add
```swift
                guard !house.contains(where: { board.values[$0] == digit }) else { continue }
```
In `HiddenSubset.find`, only consider digits not placed in the house: change the digit loop to
```swift
            for d in 1...9 where !house.contains(where: { board.values[$0] == d }) {
```
In `Pointing.find` and `BoxLineReduction.find`, after computing `cells`, add
```swift
                guard !Geometry.boxes[b].contains(where: { board.values[$0] == digit }) else { continue }
```
(for `BoxLineReduction`, check `house` instead of the box).

In `LogicalSolver.swift`, change `SolveResult.solved` to:
```swift
    public var solved: Bool { board.isSolved && !board.isContradictory }
```

- [ ] **Step 4: Run all tests**

Run: `swift test -c release --package-path SudokuCore`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "fix(core): techniques ignore placed digits; solved requires a valid grid"
```

---

### Task 2: Codable steps with secondary highlight groups

**Files:**
- Modify: `Step.swift`, `UniqueRectangles.swift`, `Coloring.swift`, `Fish.swift`
- Test: `SudokuCore/Tests/SudokuCoreTests/StepMetadataTests.swift`

**Interfaces:**
- Produces: `Step: Codable` with `groups: [[CellDigit]]` (default `[]`): coloring = [colour A, colour B]; finned fish = [fins]; UR type 3 = [subset cells' candidates]. UR type 2 `digits` include the extra digit; UR types 3/4 `regions` include the house used.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuCoreTests/StepMetadataTests.swift`:
```swift
import Foundation
import Testing
import SudokuCore

@Suite struct StepMetadataTests {
    @Test func stepsRoundTripAsJSON() throws {
        let step = Step(technique: .xWing, patternCells: [1], eliminations: [CellDigit(cell: 2, digit: 3)],
                        regions: [.row(0)], digits: [3], groups: [[CellDigit(cell: 1, digit: 3)]])
        #expect(try JSONDecoder().decode(Step.self, from: JSONEncoder().encode(step)) == step)
    }

    @Test func coloringReportsBothColours() throws {
        let b = board(digit: 1, onlyIn: [rc(0, 0), rc(1, 2), rc(5, 2), rc(5, 6), rc(0, 6), rc(0, 3), rc(8, 6)])
        let step = try #require(SimpleColoring().find(in: b))
        #expect(step.groups.count == 2)
        #expect(Set(step.groups[0].map(\.cell)) == [rc(0, 0), rc(5, 2)])
    }

    @Test func finnedFishMarksFins() throws {
        let b = board(digit: 2, onlyIn: [rc(1, 2), rc(1, 6), rc(4, 2), rc(4, 6), rc(4, 7), rc(3, 6)])
        let step = try #require(FinnedFish(size: 2).find(in: b))
        #expect(step.groups == [[CellDigit(cell: rc(4, 7), digit: 2)]])
    }

    @Test func uniqueRectangleTypesNameTheirExtras() throws {
        var b = emptyBoard()
        b.candidates[rc(0, 0)] = CandidateSet([1, 2])
        b.candidates[rc(1, 0)] = CandidateSet([1, 2])
        b.candidates[rc(0, 3)] = CandidateSet([1, 2, 3])
        b.candidates[rc(1, 3)] = CandidateSet([1, 2, 4])
        b.candidates[rc(5, 3)] = CandidateSet([3, 4])
        let t3 = try #require(UniqueRectangle(type: 3).find(in: b))
        #expect(t3.groups == [[CellDigit(cell: rc(5, 3), digit: 3), CellDigit(cell: rc(5, 3), digit: 4)]])
        #expect(t3.regions.contains(.column(3)))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test -c release --package-path SudokuCore --filter StepMetadataTests`
Expected: build FAILS (`extra argument 'groups' in call`).

- [ ] **Step 3: Implement**

In `Step.swift`: make `Step` conform to `Codable`; add `public let groups: [[CellDigit]]` with an init parameter `groups: [[CellDigit]] = []` (last) assigned in the initialiser.

In `Coloring.swift`, inside `step(_:)` pass `groups: groups.map { $0.map { CellDigit(cell: $0, digit: digit) } }`.

In `Fish.swift`, `FinnedFish` step: pass `groups: [fins.map { CellDigit(cell: $0, digit: digit) }]`.

In `UniqueRectangles.swift`: give `make` two extra parameters `extraRegions: [Region] = []`, `groups: [[CellDigit]] = []`, `extraDigits: [Int] = []`, used as `regions: regions + extraRegions`, `groups: groups`, `digits: ab.digits + extraDigits`. Type 2 calls `make(…, extraDigits: [z])`; type 3 calls `make(eliminations, extraRegions: [Region(house: h)], groups: [board.candidateDigits(of: combo)])`; type 4 calls `make(…, extraRegions: [Region(house: h)])` and compares `Set(board.cells(with: kept, in: Geometry.houses[h])) == Set(roof)`.

- [ ] **Step 4: Run all tests**

Run: `swift test -c release --package-path SudokuCore`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(core): Codable steps with highlight groups for hints"
```

---

### Task 3: Hint engine, hint text and Show me

**Files:**
- Create: `SudokuCore/Sources/SudokuGame/HintEngine.swift`, `SudokuCore/Sources/SudokuGame/HintText.swift`, `SudokuCore/Sources/SudokuGame/GameSession+Hints.swift`
- Test: `SudokuCore/Tests/SudokuGameTests/HintEngineTests.swift`

**Interfaces:**
- Produces: `HintDiagnosis` (`.solved`, `.mistake`, `.incomplete(Region)`, `.step(Step)`, `.beyond`); `HintEngine.diagnose(_ session: GameSession) -> HintDiagnosis`; `HintEngine.playerBoard(_:) -> Board`; `HintText.nudge(_ step: Step) -> String`, `HintText.message(_ diagnosis:) -> String`, `HintText.region(_:) -> String`; `GameSession.useHint(_ level: String)`, `GameSession.showMe(_ step: Step)`.

- [ ] **Step 1: Write the failing test**

`SudokuCore/Tests/SudokuGameTests/HintEngineTests.swift`:
```swift
import Testing
import SudokuCore
import SudokuGame

@Suite struct HintEngineTests {
    @Test func singlesNeedNoNotes() {
        let g = GameSession(puzzle: classicPuzzle())
        guard case .step(let step) = HintEngine.diagnose(g) else { Issue.record("expected a step"); return }
        #expect(step.technique.tier == .easy)
        #expect(HintText.nudge(step).contains(step.technique.displayName))
    }

    @Test func wrongDigitIsAMistake() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.input(9, settings: GameSettings())
        #expect(HintEngine.diagnose(g) == .mistake)
    }

    @Test func notesMissingTheAnswerAreAMistake() {
        var g = GameSession(puzzle: classicPuzzle())
        g.selected = 2
        g.inputMode = .candidate
        g.input(1, settings: GameSettings())   // answer is 4
        #expect(HintEngine.diagnose(g) == .mistake)
    }

    @Test func staleNotesAreIgnored() {
        var g = GameSession(puzzle: classicPuzzle())
        g.fillAllCandidates()
        g.selected = 2
        g.inputMode = .candidate
        g.input(5, settings: GameSettings())   // 5 is already in row 0: stale, not wrong
        let board = HintEngine.playerBoard(g)
        #expect(!board.candidates[2].contains(5))
    }

    @Test func harderStepsAskForCandidates() {
        // Medium puzzle state where singles are exhausted: use a board needing a pair with no notes.
        let g = GameSession(puzzle: classicPuzzle())
        var solved = g
        for c in 0..<81 where wikiGivens[c] == 0 {
            solved.selected = c
            solved.input(wikiAnswer[c], settings: GameSettings())
        }
        #expect(HintEngine.diagnose(solved) == .solved)
        #expect(HintText.region(.box(4)) == "box 5")
        #expect(HintText.message(.incomplete(.row(3))).contains("row 4"))
    }

    @Test func showMeAppliesTheStepAndLogs() {
        var g = GameSession(puzzle: classicPuzzle())
        guard case .step(let step) = HintEngine.diagnose(g) else { Issue.record("expected a step"); return }
        g.showMe(step)
        for p in step.placements { #expect(g.entries[p.cell] == p.digit) }
        #expect(g.log.hints["showMe"] == 1)
        #expect(g.log.reveals == 1)
        g.undo()
        for p in step.placements { #expect(g.entries[p.cell] == 0) }
        g.useHint("nudge")
        #expect(g.log.hints["nudge"] == 1)
        #expect(!g.log.isClean)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test -c release --package-path SudokuCore --filter HintEngineTests`
Expected: build FAILS with `cannot find 'HintEngine' in scope`.

- [ ] **Step 3: Implement the engine**

`SudokuCore/Sources/SudokuGame/HintEngine.swift`:
```swift
import SudokuCore

public enum HintDiagnosis: Equatable, Sendable {
    case solved
    /// A wrong digit, or notes that leave out a cell's answer.
    case mistake
    /// The next step needs pencil marks the player hasn't made yet.
    case incomplete(Region)
    case step(Step)
    /// Nothing in the catalog applies (beyond Nightmare).
    case beyond
}

public enum HintEngine {
    static let singles: Set<TechniqueID> = [.fullHouse, .nakedSingle, .hiddenSingle, .cageCompletion]

    public static func diagnose(_ session: GameSession) -> HintDiagnosis {
        if session.isComplete { return .solved }
        for c in 0..<81 where session.entries[c] != 0 && session.isWrong(c) { return .mistake }
        for c in 0..<81 where session.entries[c] == 0 && !session.notes[c].isEmpty {
            if !session.notes[c].contains(session.puzzle.solution[c]) { return .mistake }
        }
        let board = playerBoard(session)
        let solver: LogicalSolver = session.puzzle.mode == .classic ? .classic : .killer
        guard let step = solver.nextStep(on: board) else { return .beyond }
        if !singles.contains(step.technique) {
            let touched = step.patternCells + step.patternCandidates.map(\.cell) + step.eliminations.map(\.cell)
            if let bare = touched.first(where: { session.entries[$0] == 0 && session.notes[$0].isEmpty }) {
                return .incomplete(step.regions.first ?? .row(Geometry.row(bare)))
            }
        }
        return .step(step)
    }

    /// The player's position: their digits, and their notes (minus stale digits) where they made any.
    public static func playerBoard(_ session: GameSession) -> Board {
        var board = Board(values: session.entries, cages: session.puzzle.cages)
        for c in 0..<81 where session.entries[c] == 0 && !session.notes[c].isEmpty {
            board.candidates[c] = session.notes[c].intersection(board.candidates[c])
        }
        return board
    }
}
```

`SudokuCore/Sources/SudokuGame/HintText.swift`:
```swift
import SudokuCore

public enum HintText {
    /// "row 4", "column 2", "box 5" (1-based, as players count).
    public static func region(_ r: Region) -> String {
        switch r {
        case .row(let i): return "row \(i + 1)"
        case .column(let i): return "column \(i + 1)"
        case .box(let i): return "box \(i + 1)"
        }
    }

    public static func cell(_ c: Int) -> String { "r\(Geometry.row(c) + 1)c\(Geometry.col(c) + 1)" }

    public static func nudge(_ step: Step) -> String {
        let name = step.technique.displayName
        let digits = step.digits.isEmpty ? "" : " on \(step.digits.map(String.init).joined(separator: "/"))"
        if !step.regions.isEmpty {
            let places = step.regions.prefix(2).map(region).joined(separator: " and ")
            return "Look for a\(name.first.map { "AEIOU".contains($0) } == true ? "n" : "") \(name)\(digits) in \(places)."
        }
        let around = step.patternCells.first.map { " around \(cell($0))" } ?? ""
        return "Look for a\(name.first.map { "AEIOU".contains($0) } == true ? "n" : "") \(name)\(digits)\(around)."
    }

    public static func message(_ d: HintDiagnosis) -> String {
        switch d {
        case .solved: return "The puzzle is solved."
        case .mistake: return "There's a mistake on your board. Use Check to find it."
        case .incomplete(let r): return "Your candidates in \(region(r)) are incomplete — fill those in first."
        case .step(let s): return nudge(s)
        case .beyond: return "This position needs reasoning beyond the hint engine."
        }
    }
}
```

`SudokuCore/Sources/SudokuGame/GameSession+Hints.swift`:
```swift
import SudokuCore

extension GameSession {
    /// Records a hint level for stats: "nudge", "spotlight", "lesson" or "showMe".
    public mutating func useHint(_ level: String) {
        log.hints[level, default: 0] += 1
    }

    /// Applies a hint's step to the board (undoable). Logged as a reveal.
    public mutating func showMe(_ step: Step) {
        record()
        let board = HintEngine.playerBoard(self)
        var e = entries
        var n = notes
        for cd in step.eliminations where e[cd.cell] == 0 {
            if n[cd.cell].isEmpty { n[cd.cell] = board.candidates[cd.cell] }
            n[cd.cell].remove(cd.digit)
        }
        for cd in step.placements {
            e[cd.cell] = cd.digit
            n[cd.cell] = .empty
        }
        restore(Snapshot(entries: e, notes: n))
        log.hints["showMe", default: 0] += 1
        log.reveals += 1
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test -c release --package-path SudokuCore --filter "HintEngineTests|SudokuGameTests"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add SudokuCore
git commit -m "feat(game): hint engine, hint text and show me"
```

---

### Task 4: Lesson examples and explanations

**Files:**
- Create: `SudokuCore/Sources/SudokuCore/Lessons/LessonExample.swift`, `SudokuCore/Sources/SudokuCore/Lessons/LessonFinder.swift`
- Create: `SudokuCore/Sources/SudokuGame/LessonText.swift`
- Modify: `SudokuCore/Sources/sudoku-forge/main.swift` (`--lessons FILE`)
- Test: `SudokuCore/Tests/SudokuCoreTests/LessonTests.swift`, `SudokuCore/Tests/SudokuGameTests/LessonTextTests.swift`

**Interfaces:**
- Produces: `LessonExample: Codable { technique, values, candidates: [UInt16], cages, step }` with `board: Board`; `LessonFinder.find(_ id: TechniqueID, seeds: Range<UInt64>) -> LessonExample?` (walks random puzzle solve paths, classic or Killer as the technique needs, and returns the first state where the technique finds a step); `LessonText.explanation(for:) -> String` for every `TechniqueID`.

- [ ] **Step 1: Write the failing tests**

`SudokuCore/Tests/SudokuCoreTests/LessonTests.swift`:
```swift
import Foundation
import Testing
import SudokuCore

@Suite struct LessonTests {
    @Test(arguments: [TechniqueID.nakedPair, .xWing, .xyWing, .cageCombination])
    func findsAnExampleWhoseStepIsReproducible(id: TechniqueID) throws {
        let lesson = try #require(LessonFinder.find(id, seeds: 1..<200))
        #expect(lesson.technique == id)
        let again = LessonFinder.technique(for: id)?.find(in: lesson.board)
        #expect(again == lesson.step)
        let back = try JSONDecoder().decode(LessonExample.self, from: JSONEncoder().encode(lesson))
        #expect(back == lesson)
    }
}
```

`SudokuCore/Tests/SudokuGameTests/LessonTextTests.swift`:
```swift
import Testing
import SudokuCore
import SudokuGame

@Suite struct LessonTextTests {
    @Test func everyTechniqueHasAnExplanation() {
        for id in TechniqueID.allCases {
            #expect(LessonText.explanation(for: id).count > 60, "\(id)")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test -c release --package-path SudokuCore --filter "LessonTests|LessonTextTests"`
Expected: build FAILS with `cannot find 'LessonFinder' in scope`.

- [ ] **Step 3: Implement examples and the finder**

`SudokuCore/Sources/SudokuCore/Lessons/LessonExample.swift`:
```swift
/// A board state where a technique applies, used as the lesson's demo.
public struct LessonExample: Codable, Equatable, Sendable {
    public let technique: TechniqueID
    public let values: [Int]
    public let candidates: [UInt16]
    public let cages: [Cage]
    public let step: Step

    public init(technique: TechniqueID, board: Board, step: Step) {
        self.technique = technique
        self.values = board.values
        self.candidates = board.candidates.map(\.raw)
        self.cages = board.cages
        self.step = step
    }

    public var board: Board {
        var b = Board(values: values, cages: cages)
        for c in 0..<81 { b.candidates[c] = CandidateSet(raw: candidates[c]) }
        return b
    }
}
```

`SudokuCore/Sources/SudokuCore/Lessons/LessonFinder.swift`:
```swift
public enum LessonFinder {
    public static func technique(for id: TechniqueID) -> (any Technique)? {
        (TechniqueCatalog.classic + TechniqueCatalog.killer).first { $0.id == id }
    }

    /// The first solve-path state (over the given seeds) where `id` finds a step.
    public static func find(_ id: TechniqueID, seeds: Range<UInt64>) -> LessonExample? {
        guard let technique = technique(for: id) else { return nil }
        let killer = id.isKillerOnly
        let solver = killer ? LogicalSolver.killer : LogicalSolver.classic
        for seed in seeds {
            var rng = SplitMix64(seed: seed)
            let solution = BruteForceSolver.randomSolution(using: &rng)
            var givens = solution
            var cages: [Cage] = []
            if killer {
                cages = KillerCages.partition(solution: solution, sizes: 2...5, using: &rng)
                givens = Array(repeating: 0, count: 81)
            } else {
                for c in Array(0..<81).shuffled(using: &rng) {
                    let saved = givens[c]
                    givens[c] = 0
                    if BruteForceSolver.countSolutions(givens) != 1 { givens[c] = saved }
                }
            }
            var board = Board(values: givens, cages: cages)
            for _ in 0..<400 {
                if let step = technique.find(in: board) { return LessonExample(technique: id, board: board, step: step) }
                guard let next = solver.nextStep(on: board) else { break }
                board.apply(next)
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Write the explanations**

`SudokuCore/Sources/SudokuGame/LessonText.swift`:
```swift
import SudokuCore

public enum LessonText {
    public static func explanation(for id: TechniqueID) -> String {
        switch id {
        case .fullHouse: return "A row, column or box with only one empty cell: that cell takes the one digit the house is still missing."
        case .nakedSingle: return "A cell whose candidates are down to a single digit. Every other digit is already used by a peer in its row, column or box, so this digit goes here."
        case .hiddenSingle: return "Within a house, a digit that fits in only one cell. Even if that cell has other candidates, the digit must go there because the house needs it somewhere."
        case .pointing: return "Inside a box, all candidates for a digit lie in one row (or column). The box's copy of the digit will be on that line, so remove it from the rest of the line outside the box."
        case .boxLineReduction: return "Inside a row or column, all candidates for a digit lie in one box. The line's copy will be in that box, so remove the digit from the rest of the box."
        case .nakedPair: return "Two cells in a house holding the same two candidates and nothing else. Those two digits are used up by the pair, so remove them from every other cell in the house."
        case .hiddenPair: return "Two digits that, within a house, appear only in the same two cells. Those cells must hold those digits, so every other candidate in the two cells can go."
        case .nakedTriple: return "Three cells in a house whose candidates together are only three digits (each cell needn't hold all three). The three digits are locked into those cells; remove them from the rest of the house."
        case .hiddenTriple: return "Three digits that, within a house, appear only in the same three cells. Those cells must hold them, so remove every other candidate from the three cells."
        case .nakedQuad: return "Four cells in a house whose candidates together are only four digits. Those digits are locked in; remove them from every other cell in the house."
        case .hiddenQuad: return "Four digits confined to the same four cells of a house. Clear every other candidate from those four cells."
        case .xWing: return "For one digit, two rows each have exactly two candidates, and they line up in the same two columns. The digit must be at opposite corners of that rectangle, so remove it from the rest of both columns (or rows, for the transposed pattern)."
        case .uniqueRectangle1: return "Four cells forming a rectangle across two boxes, three of them holding only the same two candidates. If the fourth were also just those two, the puzzle would have two solutions, so remove both digits from the fourth cell."
        case .skyscraper: return "Two parallel strong links on one digit share one end line. One of the two loose ends (the roofs) must hold the digit, so any cell seeing both roofs loses it."
        case .twoStringKite: return "A row strong link and a column strong link on a digit, with one end of each in the same box. One of the two far ends must be the digit; remove it from cells seeing both."
        case .xyWing: return "A pivot cell {A,B} sees two pincers {A,C} and {B,C}. Whatever the pivot is, one pincer becomes C, so any cell seeing both pincers can't be C."
        case .swordfish: return "The three-line version of the X-Wing: for one digit, three rows have all their candidates in the same three columns. Remove the digit from the rest of those columns."
        case .emptyRectangle: return "In a box, a digit's candidates sit on one row and one column (a cross). Combined with a strong link that ends on that row or column, the digit is forced away from one cell where the link and the cross meet."
        case .xyzWing: return "A pivot {A,B,C} sees pincers {A,C} and {B,C}. C must be in one of the three cells, so cells seeing all three lose C."
        case .wWing: return "Two identical bivalue cells {A,B} that don't see each other, joined by a strong link on A whose ends each see one of them. One of the two cells must be B, so cells seeing both lose B."
        case .uniqueRectangle2: return "A rectangle whose two floor cells are {A,B} and whose two roof cells are {A,B,C}. To avoid two solutions one roof must be C, so cells seeing both roof cells lose C."
        case .uniqueRectangle4: return "A rectangle with floor {A,B} where, in a house shared by the two roof cells, A appears only on the roof. One roof is A, so neither roof can be B."
        case .uniqueRectangle3: return "A rectangle whose roof cells carry extra digits. Treat those extras as one virtual cell and look for a naked subset with other cells of a house the roof shares; eliminate as for any naked subset."
        case .finnedXWing: return "An X-Wing with a few extra candidates (fins) in one box. Either a fin is true or the X-Wing holds, so only cells that see the fins and lie in the X-Wing's cover lines lose the digit."
        case .simpleColoring: return "Follow the strong links of one digit and colour them alternately. Exactly one colour is true. If a colour sees itself it's false everywhere; a cell seeing both colours loses the digit."
        case .finnedSwordfish: return "A Swordfish with fins confined to one box. Cells in the cover lines inside the fin box lose the digit."
        case .jellyfish: return "The four-line fish: one digit's candidates in four rows fit into four columns. Remove the digit from the rest of those columns."
        case .xCycle: return "A chain on a single digit that alternates strong links (only two places in a house) and weak links. If the first candidate is false the last is true, so cells seeing both ends lose the digit."
        case .xyChain: return "A chain through bivalue cells: each cell's other digit links to the next cell. The two ends can't both be false, so a digit they share leaves every cell that sees both ends."
        case .sueDeCoq: return "Two or three cells where a box meets a line hold two more digits than cells. A bivalue cell in the line and one in the box use up the extras, so each set of digits leaves the rest of its line or box."
        case .alsXZ: return "Two almost-locked sets (N cells, N+1 digits) share a digit X that can only be in one of them. Another shared digit Z must then be in one set, so cells seeing every Z in both lose Z."
        case .aic: return "An alternating inference chain mixes cell links and house links. Starting with a strong link and ending with one, at least one end is true, so anything that conflicts with both ends is false."
        case .cellForcingChain: return "Try each candidate of one cell in turn and follow the consequences. Any result that every possibility leads to must be true."
        case .unitForcingChain: return "Try each place a digit could go in a house and follow the consequences. A result shared by all of them must be true."
        case .digitForcingChain: return "Assume a candidate is true and follow the singles; then assume it's false. If one assumption breaks the puzzle, the other holds; if both agree on something, that's true."
        case .nestedForcingChain: return "A forcing chain whose follow-through uses pairs, triples and intersections, not just singles. It reaches deductions plain forcing chains can't."
        case .cageCompletion: return "A cage with one empty cell: that cell is the cage total minus the digits already in it."
        case .uniqueCageCombination: return "Some totals allow only one set of digits for their cage size (3 in two cells is 1+2; 24 in three cells is 7+8+9). Remove every other digit from the cage."
        case .cageCombination: return "List the digit sets that make the cage total, then keep only those that fit the cells' candidates. Digits that appear in no workable set can go."
        case .innieOutie1: return "The 45 rule: every row, column and box sums to 45. Subtract the cages that lie fully inside the house; what's left is the sum of the cells poking in from other cages (innies) or out of the house (outies)."
        case .cageLockedDigit: return "A digit every possible combination of a cage needs. If the cage's possible places for it lie in one row, column or box, that house's other cells lose the digit."
        case .innieOutie2: return "The 45 rule across two houses (90): add up the cages inside two adjacent rows, columns or boxes to pin down the cells that stick in or out."
        case .innieOutieMulti: return "The 45 rule across three or four lines (135 or 180). Bigger regions catch innies and outies that smaller ones can't."
        }
    }
}
```

- [ ] **Step 5: CLI `--lessons`**

In `sudoku-forge/main.swift`, before parsing options, handle a lessons run:
```swift
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--lessons" {
    var lessons: [LessonExample] = []
    for id in TechniqueID.allCases {
        if let lesson = LessonFinder.find(id, seeds: 1..<400) {
            lessons.append(lesson)
            log("lesson \(id.rawValue): found")
        } else {
            log("lesson \(id.rawValue): none")
        }
    }
    try JSONEncoder().encode(lessons).write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
    exit(0)
}
```

- [ ] **Step 6: Run tests, then generate lessons**

Run:
```bash
swift test -c release --package-path SudokuCore --filter "LessonTests|LessonTextTests"
swift build --package-path SudokuCore -c release && mkdir -p App/Lessons
SudokuCore/.build/release/sudoku-forge --lessons App/Lessons/lessons.json
```
Expected: tests PASS; most techniques report `found` (record any `none` in the ledger).

- [ ] **Step 7: Commit**

```bash
git add SudokuCore App/Lessons
git commit -m "feat(hints): lesson examples, explanations and lessons file"
```

---

### Task 5: Hint UI — hint bar, spotlight, lesson sheet, Show me

**Files:**
- Modify: `App/Views/BoardView.swift`, `App/Views/ControlsView.swift`, `App/Views/GameView.swift`, `App/AppModel.swift`
- Create: `App/Views/HintBar.swift`, `App/Views/LessonView.swift`

- [ ] **Step 1: Board overlays**

In `BoardView`, add properties `var spotlight: Set<Int> = []`, `var marks: [CellDigit] = []` (candidates to strike red) and `var pattern: [CellDigit] = []` (candidates to ring green). In `draw`, after highlights, fill spotlight cells with `Color.yellow.opacity(0.35)`; when drawing notes, draw pattern notes in green and marked notes in red with a strike line.

- [ ] **Step 2: Lessons in the model**

In `AppModel`, add:
```swift
    let lessons: [TechniqueID: LessonExample] = {
        guard let url = Bundle.main.url(forResource: "lessons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([LessonExample].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.technique, $0) }, uniquingKeysWith: { a, _ in a })
    }()
```

- [ ] **Step 3: Hint bar and lesson sheet**

`App/Views/HintBar.swift`:
```swift
import SwiftUI
import SudokuCore
import SudokuGame

/// Escalating hint: message → Show where (spotlight) → Lesson.
struct HintBar: View {
    let diagnosis: HintDiagnosis
    let level: Int
    let onSpotlight: () -> Void
    let onLesson: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                Text(HintText.message(diagnosis)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose).labelStyle(.iconOnly)
            }
            if case .step = diagnosis {
                HStack {
                    if level < 2 { Button("Show where", action: onSpotlight).buttonStyle(.bordered).accessibilityIdentifier("hintSpotlight") }
                    Button("Lesson", action: onLesson).buttonStyle(.borderedProminent).accessibilityIdentifier("hintLesson")
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("hintBar")
    }
}
```

`App/Views/LessonView.swift`:
```swift
import SwiftUI
import SudokuCore
import SudokuGame

/// The lesson modal: animated example, explanation, and "Show me" on the player's board.
struct LessonView: View {
    let technique: TechniqueID
    let example: LessonExample?
    let onShowMe: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var phase = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let example {
                        BoardView(session: exampleSession(example), settings: GameSettings(),
                                  spotlight: phase >= 1 ? Set(example.step.patternCells) : [],
                                  marks: phase >= 2 ? example.step.eliminations : [],
                                  pattern: phase >= 1 ? example.step.patternCandidates : []) { _ in }
                            .frame(maxWidth: .infinity)
                            .task {
                                while !Task.isCancelled {
                                    for p in 0...2 {
                                        withAnimation { phase = p }
                                        try? await Task.sleep(for: .seconds(1.6))
                                    }
                                }
                            }
                        Text(caption).font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(LessonText.explanation(for: technique)).font(.body)
                    Button {
                        onShowMe()
                        dismiss()
                    } label: {
                        Label("Show me on my board", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("showMe")
                    Text("Show me counts as a reveal.").font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle(technique.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private var caption: String {
        switch phase {
        case 0: return "The position."
        case 1: return "The pattern."
        default: return "What it removes."
        }
    }

    private func exampleSession(_ e: LessonExample) -> GameSession {
        let puzzle = Puzzle(id: "lesson", mode: e.cages.isEmpty ? .classic : .killer, givens: e.values, cages: e.cages,
                            solution: e.values, grade: Grade(tier: e.technique.tier, score: 0), techniquesRequired: [])
        return GameSession(lessonPuzzle: puzzle, notes: e.candidates.map { CandidateSet(raw: $0) })
    }
}
```

Add to `GameSession+Hints.swift` (SudokuGame):
```swift
extension GameSession {
    /// A display-only session for lesson boards, with the example's candidates as notes.
    public init(lessonPuzzle: Puzzle, notes: [CandidateSet]) {
        self.init(puzzle: lessonPuzzle)
        restore(Snapshot(entries: lessonPuzzle.givens, notes: notes))
    }
}
```

- [ ] **Step 4: Wire into the game screen**

In `ControlsView`, enable the Hint tool and call a new `onHint: () -> Void` closure (add the property; remove `enabled: false`).

In `GameView`: add `@State private var diagnosis: HintDiagnosis?`, `@State private var hintLevel = 0`, `@State private var showLesson = false`. On hint: `diagnosis = HintEngine.diagnose(s)`, `hintLevel = 1`, log `useHint("nudge")` only when the diagnosis is `.step`. Show `HintBar` above the controls when `diagnosis != nil`. "Show where": `hintLevel = 2`, `useHint("spotlight")`, pass the step's `patternCells` as `spotlight` and `groups.flatMap { $0 }` + `patternCandidates` as `pattern` to the main `BoardView`. "Lesson": `useHint("lesson")`, `showLesson = true`, sheet `LessonView(technique:, example: model.lessons[technique], onShowMe: { s.showMe(step); changed(s) })`. Any board input clears `diagnosis`.

- [ ] **Step 5: Build, run, screenshot a hint**

Run `xcodegen generate` and the Plan 5 build/install commands. Start an Easy game, tap Hint, Show where, Lesson; capture screenshots.
Expected: hint bar text names a technique and region; spotlight highlights cells; lesson sheet animates and Show me fills the board.

- [ ] **Step 6: Commit**

```bash
git add App
git commit -m "feat(app): hint bar, spotlight, lesson sheet and show me"
```
