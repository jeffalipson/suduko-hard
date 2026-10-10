# Hard Sudoku — Design Spec

Date: 2026-10-10
Status: Draft for review

## 1. Purpose

A native iPhone app offering Classic and Killer Sudoku that goes well past NYT "Hard". Built primarily for one demanding player. Puzzles are graded by the hardest human technique required, always have a unique solution, and are always solvable by logic (no guessing). Hints teach techniques rather than give answers. Everything is tracked on a stats page.

**Success criteria**
- Every puzzle has exactly one solution and is solved by the app's logical solver with no backtracking.
- Difficulty tiers are consistent: a puzzle's tier, its hints, and its "techniques required" list all come from the same engine.
- A puzzle is always ready instantly for every mode × tier, offline, with no server.
- Two installs essentially never see the same puzzle; one user never sees a recognisable repeat.

## 2. Platform & constraints

- iOS 17+, Swift, SwiftUI, SwiftData, Swift Charts. Light and dark mode.
- No server, no accounts, no iCloud sync (possible future work).
- Fully offline.

## 3. Architecture

```
SudokuCore (Swift package, no UI)
├── Model: Board, Cage, Puzzle, Grade
├── BruteForceSolver   — uniqueness only
├── LogicalSolver      — technique-by-technique; grading, hints
├── Techniques/        — one type per technique, conforming to `Technique`
├── Generators         — ClassicGenerator, KillerGenerator
└── Transforms         — validity- and grade-preserving randomisation

sudoku-forge (macOS CLI, depends on SudokuCore)
└── builds the bundled puzzle library

HardSudoku (iOS app, depends on SudokuCore)
├── PuzzleQueue / background generation
├── Game UI
├── Hint engine UI + Lessons
├── Settings
└── Stats (SwiftData)
```

The app, the CLI, and the tests all share one SudokuCore, so grades, hints and the library never disagree.

## 4. SudokuCore engine

### 4.1 Model
- `Board`: 81 cells; each has a value (0 = empty), a `given` flag, and a candidate set as a `UInt16` bitmask.
- `Cage` (Killer): set of cells + target sum. Cages never repeat a digit.
- `Puzzle`: `mode` (classic/killer), givens, cages (killer), solution, `Grade` (tier + score), `techniquesRequired: [TechniqueID]`, `id`.
- `Tier`: `easy, medium, hard, expert, fiendish, diabolical, nightmare`.

### 4.2 Solvers
- **BruteForceSolver**: bitmask backtracking (with cage-sum pruning for Killer). API: `countSolutions(puzzle, limit: 2) -> Int`. Used only to prove uniqueness.
- **LogicalSolver**: loop — find the easiest applicable technique, apply its `Step`, repeat until solved or stuck. Returns the ordered list of steps. Stuck ⇒ puzzle rejected by the generator.

### 4.3 Technique protocol
```swift
protocol Technique {
    var id: TechniqueID { get }
    var tier: Tier { get }
    var weight: Int { get }          // contribution to score
    func find(in board: Board, cages: [Cage]) -> Step?
}

struct Step {
    let technique: TechniqueID
    let patternCells: [CellRef]          // cells forming the pattern (Spotlight)
    let patternCandidates: [CellDigit]   // candidates forming the pattern
    let placements: [CellDigit]
    let eliminations: [CellDigit]
    let region: RegionHint               // e.g. "columns 2 and 7", "box 5"
    let explanation: Explanation         // structured data → text in app
}
```
One `Step` type drives grading, Nudge, Spotlight, and "Show me".

Techniques are tried in a fixed order (easiest first, ties broken by weight).

### 4.4 Grading
- **Tier** = tier of the hardest technique used by the LogicalSolver.
- **Score** = sum of step weights; orders puzzles within a tier.
- `techniquesRequired` = distinct techniques used.

### 4.5 Classic tier ladder

| Tier | Techniques introduced |
|---|---|
| Easy | Full house, naked single, hidden single |
| Medium | Naked pair, hidden pair, pointing pair/triple, box/line reduction |
| Hard | Naked triple/quad, hidden triple/quad |
| Expert | X-Wing, Swordfish, XY-Wing, Skyscraper, 2-String Kite, Unique Rectangle type 1 |
| Fiendish | XYZ-Wing, W-Wing, Jellyfish, finned X-Wing/Swordfish, simple coloring, empty rectangle, UR types 2–4 |
| Diabolical | X-Cycles, XY-Chain, AIC, ALS-XZ, Sue de Coq |
| Nightmare | Forcing chains (cell, unit, digit), ALS chains, nested chains |

### 4.6 Killer techniques and tiers
Killer puzzles may use every classic technique, plus:

| Tier | Killer-specific techniques introduced | Givens | Cage sizes |
|---|---|---|---|
| Easy | Unique cage combinations (e.g. 3 in 2 = {1,2}), cage completion | 6–12 | mostly 2–3 |
| Medium | Cage combination candidate restriction | 0–6 | 2–4 |
| Hard | 45-rule innies/outies (single house) | 0–3 | 2–5 |
| Expert | 45-rule across two houses, killer pairs/hidden cages | 0 | 2–5 |
| Fiendish | 45-rule across 3+ houses, cage splitting | 0 | 2–6 |
| Diabolical | Cage-combination interactions across overlapping regions | 0 | 3–7 |
| Nightmare | Requires a classic Diabolical/Nightmare technique or chains involving cage combinations | 0 | 3–8 |

A Killer puzzle's tier is the maximum of its hardest technique's tier and the tier implied by givens/cage sizes.

## 5. Generation, library, and queues

### 5.1 Classic generator
1. Generate a random complete solution grid.
2. Remove clues in random order, preferring 180° rotational symmetry; after each removal confirm `countSolutions == 1`, otherwise restore.
3. Grade with the LogicalSolver. Reject if stuck. Accept if tier == target.
4. If below target, continue removing clues (symmetry may be dropped for Diabolical/Nightmare); if above, restart.

### 5.2 Killer generator
1. Generate a random complete solution grid.
2. Grow cages randomly within the target tier's size range (no repeated digit within a cage).
3. Choose givens per the tier's range.
4. Confirm uniqueness with the cage-aware BruteForceSolver; grade; accept if tier == target, otherwise retry.

### 5.3 Library (sudoku-forge CLI)
- `sudoku-forge --mode <classic|killer> --tier <tier> --count <n> --out <file>`
- Target 300 puzzles per mode × tier (4,200 total), stored as compact JSON in the app bundle.
- Each library puzzle stores givens, cages, solution, grade, techniquesRequired.

### 5.4 Randomisation (transforms)
Applied to every puzzle before it is shown, with a fresh random seed:
- Digit relabelling (9!)
- Row permutation within each band, column permutation within each stack (6⁶)
- Band and stack permutation (6²)
- Transpose (×2)

That gives ~1.2 × 10¹² variants per classic puzzle. Cages transform with their cells. Killer puzzles skip digit relabelling (it would change cage sums), leaving ~3.4 × 10⁶ geometric variants per puzzle. Transforms preserve uniqueness and tier exactly (verified by tests). Score and `techniquesRequired` can vary slightly with orientation (scan order decides e.g. Full House vs Naked Single), so the stored values describe the library's canonical orientation and are carried forward unchanged.

### 5.5 Queue manager
- 14 queues (2 modes × 7 tiers), each kept at **3** ready puzzles, persisted on disk.
- Refill source priority: (1) freshly generated puzzle, (2) next unused library puzzle; the library draw order is shuffled once per install, with no repeats until exhausted, then reshuffled.
- A transform is applied to every puzzle as it enters the queue.
- Generation runs on a background task while the app is open, and via `BGProcessingTask` (requires external power) when the app is closed.
- Each generation attempt for a tier has a 60-second budget; on timeout, refill from the library. Queues therefore never empty.
- Starting a game pops from the queue and triggers a refill.

## 6. Game UI

### 6.1 Screens
- **Home**: Classic / Killer segmented control → list of 7 tiers. Each tier shows "Resume" if an unfinished game exists, otherwise "New".
- **Game**: board + controls (below).
- **Lesson modal** (see §7).
- **Completion screen**: time, mistakes, assists/hints used, clean-solve badge, techniques the puzzle required.
- **Stats** (see §8).
- **Settings**.

### 6.2 Game screen
- 9×9 grid, thick box borders. Killer: dashed cage outlines with the sum in each cage's top-left cell.
- Candidates are shown as a 3×3 mini-grid inside each cell.
- Controls: Normal / Candidate mode toggle; number pad 1–9 (a digit dims once all nine are placed); Undo, Redo (unlimited); Erase; Hint.
- Top bar: timer; pause (hides board, stops timer); menu with Check cell, Check puzzle, Reveal cell (all logged).
- Haptic feedback on placement, error, completion.
- Autosave on every move; one unfinished game per mode × tier.

### 6.3 Settings (all toggles)

| Setting | Default |
|---|---|
| Auto-candidates button (fills all candidates; logged as assist) | Off |
| Auto-remove candidates on placement | Off |
| Mistake highlighting (wrong digits shown red immediately) | Off |
| Killer cage helper (tap cage → valid combinations, impossible ones struck out; logged as assist) | Off |
| Killer remaining-sum display | Off |
| Highlight matching digits and selected row/column/box | **On** |

When a setting is off, its UI is hidden entirely.

## 7. Hints

### 7.1 Board-state diagnosis (runs first)
The hint engine compares the player's board with the true solution and with the true candidate state:

| Player board state | Response |
|---|---|
| Any placed digit is wrong, or a correct candidate has been erased | "There's a mistake on your board." (Location not shown; use Check.) |
| Candidates missing in cells the next step needs | "Your candidates in <row/col/box> are incomplete — fill those in first." |
| A simpler technique is available on the player's own marks than the engine's next step | Hint for that simpler step instead. |
| Marks complete and correct | Normal hint flow for the next step. |

The "next step" is computed by running the LogicalSolver on the player's current board, using the player's candidates where present and complete.

### 7.2 Hint levels (each tap escalates)
1. **Nudge**: technique name + region. "Look for an X-Wing on 7s in the columns."
2. **Spotlight**: highlights `patternCells` on the player's board. Eliminations are not shown.
3. **Lesson modal** containing:
   - A curated example board with an animated step-by-step demonstration of the technique (pattern → reasoning → eliminations).
   - A written explanation: what the pattern is, why it works, what to look for.
   - A **"Show me"** button: closes the modal and animates the actual step on the player's board (pattern, then eliminations/placement applied). Logged as a reveal.

### 7.3 Lessons
One curated example board plus explanation per technique (~35 lessons). Stored as data (board, step, text) in the app bundle and verified by tests to produce the intended step.

## 8. Stats

### 8.1 Recorded per game (SwiftData `GameRecord`)
mode, tier, puzzle id, start/end date, elapsed time, outcome (won/abandoned), mistakes (wrong digits placed; counted only while mistake highlighting is on, otherwise recorded as nil and excluded from mistake stats), hint counts per level (nudge/spotlight/lesson/show-me), checks, reveals, assists used (auto-candidates, cage helper), clean solve flag (won with zero hints, checks, reveals, and assists), techniquesRequired.

A game counts as abandoned when the player starts a new game in the same mode × tier while one is unfinished.

### 8.2 Stats page
- **Per mode × tier**: played, won, win %, best time, average time, current streak, best streak (streak = consecutive wins in that mode × tier with no abandon in between).
- **Progress**: Swift Charts line chart of solve time over time, filterable by mode and tier.
- **Assistance**: totals and per-tier rates of mistakes, hints by level, checks, reveals, assists; clean-solve count and %.
- **Techniques**: for each technique, the number of won puzzles that required it; tiers ranked by abandon rate.

## 9. Testing

- **SudokuCore unit tests**:
  - Each technique: at least one known board where it applies, asserting exact pattern and eliminations; at least one where it must not fire.
  - BruteForceSolver: unique, multi-solution and invalid puzzles (classic and killer).
  - LogicalSolver/grading: reference puzzles with known tiers.
  - Transforms: solution validity, uniqueness and grade preserved.
  - Generators: output is unique, logic-solvable, and of the requested tier (small samples).
  - Lessons: each lesson board produces its intended technique as the first step.
- **App**: unit tests for the queue manager, hint diagnosis and stats aggregation; UI tests for the core loop (start game, enter digits/candidates, undo, hint, complete).

## 10. Out of scope (for now)
iCloud sync, accounts, leaderboards, daily puzzles, iPad-specific layout, other variants (Thermo, Arrow, etc.), puzzle import.
