# iPad Version (1.1) — Design Spec

Date: 2026-10-13
Status: Draft for review

## 1. Purpose

Make Really Really Hard Sudoku a native iPad app so it reaches more App Store players, and have it feel built for iPad rather than a stretched iPhone app. Version 1.0 is iPhone-only; on iPad it currently runs as a phone-sized window.

**Success criteria**
- On every iPad size (mini, 11", 13"), in both orientations and in any window size (split view, Stage Manager, freely resized iPadOS 26 windows), the board is as large as the window allows and the controls are a comfortable size and close to the board.
- iPhone layout and behaviour are unchanged.
- A hardware keyboard can play a whole game without touching the screen.
- Ships as 1.1 of the same App Store app (same bundle ID, listing and privacy answers).

**Out of scope for 1.1:** Apple Pencil features (Pencil works as a finger; no handwriting or Pencil shortcuts), a sidebar/split-view navigation redesign, any new gameplay features.

## 2. Approach

One adaptive layout per screen, chosen from the **space the view actually gets**, not from the device type. A narrow split-view window on an iPad gets the iPhone layout; a wide window gets the iPad layout. There are no separate iPad-only screens.

## 3. Game screen

`GameView` chooses between two arrangements.

**Stacked** (portrait, narrow windows, every iPhone) — today's vertical stack: board, hint bar, Normal/Candidate switch, keypad (1–5 over a centred 6–9), tools row.
- iPhone: unchanged.
- In a regular-width window, the switch, hint bar, keypad and tools are capped at **560 pt** wide and centred; the board still uses the full width.

**Side by side** (landscape, wide windows):
- Board on the left, sized to the available height.
- A **340 pt** column on the right, top to bottom: Normal/Candidate switch, keypad as a **3×3 grid** (1 2 3 / 4 5 6 / 7 8 9) with large keys (full column width, **72 pt** tall), then the tools (Undo, Redo, Erase, Cage, Auto Pencil, Hint) in **two rows of three**, then the hint bar when showing (below the keys, so they never move when a hint appears). When the Cage tool is hidden (Classic, or the setting is off) the tools are Undo, Redo, Erase / Auto Pencil, Hint.

**Choosing the arrangement** — a pure function `GameLayout.choose(width:height:)` (the space below the navigation bar) returns `.stacked` or `.sideBySide(board:)`, picking **whichever gives the bigger board**: stacked board `min(width − 16, height − 300)` (300 pt for the controls below it) versus side-by-side board `min(height − 32, width − 340 − 48)`. Side by side when width ≥ height and its board is bigger. In short windows the side column scrolls. `.sideBySide` carries the board side so the view and the tests agree; the stacked board keeps today's behaviour (full width, shrinking to fit). Rotating or resizing re-lays out immediately; the game, selection, timer and any open hint are untouched (they live in `GameSession`/`GameView` state, not in the layout).

**Sizing** — in regular-width windows the key digits, tool icons and tool labels scale by **1.3×**.

**Sheets** (lesson, explain step by step, cage helper, completion, stats, settings) keep their current content; iPad shows them as centred cards. Each is checked on iPad for stretched content; fixes are limited to width caps.

## 4. Home screen

**Wide windows** — two columns:
- Left: Stats and Settings buttons, wordmark, Continue card (when a game is in progress).
- Right: Classic/Killer switch and the seven tier rows, all visible without scrolling on 11" and 13" iPads in landscape.

**Tall windows on iPad** — today's single column, capped at **700 pt** and centred.

**Regular-width windows (both arrangements)** — wordmark, Continue card, mode switch and tier rows scale by about **1.4×**.

**iPhone and narrow windows** — unchanged.

The same component views are reused (`CagedWordmark`, `ContinueCard`, `ModeSwitch`, `TierRow`); they gain a scale parameter. The loading overlay, new-game confirmation and sheets are unchanged. The wide/tall choice uses the same rule shape as the game screen (`HomeLayout.choose(width:height:)`: two columns when the window is wider than tall and at least 900 pt wide).

## 5. Hardware keyboard

Active on the game screen only, and not while a sheet is open.

| Key | Action |
|---|---|
| ← → ↑ ↓ | Move the selected cell; stops at the edges. With no selection, the first press selects r1c1. |
| 1–9 (top row or number pad) | Same as tapping that digit key in the current input mode |
| Delete / Backspace | Erase |
| Space | Toggle Normal / Candidate |
| ⌘Z / ⇧⌘Z | Undo / Redo (attached to the buttons, so they appear in the ⌘ shortcut overlay) |

- Selection movement is a new `GameSession.moveSelection(rows:columns:)` in `SudokuGame`, next to the other game rules.
- The key → action mapping is a pure function `KeyCommand.action(for:)` returning an enum, so it is testable without UI.
- Works on iPhone with a Bluetooth keyboard too.

## 6. Rotation and project settings

- `TARGETED_DEVICE_FAMILY` becomes `1,2` (iPhone + iPad).
- iPad supports all four orientations (`UISupportedInterfaceOrientations~ipad`); iPhone stays portrait. No `UIRequiresFullScreen`, so multitasking stays on.
- `MARKETING_VERSION` 1.1; `CURRENT_PROJECT_VERSION` continues from the last uploaded build.
- The existing single 1024 pt app icon covers iPad. Bundle ID, App Store record, privacy answers and export compliance are unchanged.

## 7. Testing

**Unit tests (SudokuGame, `swift test -c release`):**
- `GameLayout.choose` and `HomeLayout.choose` with real window sizes: iPhone SE and 17, iPad mini / 11" / 13" in both orientations, split view at ⅓, ½ and ⅔, a wide Stage Manager window, and sizes either side of each threshold. (The layout functions live in `SudokuGame` as plain `Double` maths so they are testable there.)
- `moveSelection`: each direction, stopping at all four edges, selecting r1c1 from no selection.
- `KeyCommand.action(for:)`: every mapped key, and unmapped keys returning nothing.

**UI tests:**
- The existing 8 run on an iPad simulator as well as iPhone 17.
- New: rotate the iPad to landscape and assert the digit keys are to the right of the board.
- New: play with the hardware keyboard only (arrows, digits, Delete, Space, ⌘Z).

**Manual simulator checks, with screenshots:** iPad mini, 11", 13" in both orientations; split view at ⅓, ½, ⅔; a freely resized window; every sheet on iPad; iPhone SE and iPhone 17 regression.

## 8. App Store

- 13" iPad screenshots (2064×2752 portrait or 2752×2064 landscape): the same six scenes as iPhone; game scenes in landscape to show the side-by-side layout. Saved under `docs/appstore/screenshots/ipad-13-inch/`.
- Listing: add one line to the description — "Plays on iPhone and iPad, with full hardware keyboard support."
- What's New: "Now on iPad — a full-size board, side-by-side controls in landscape, split view and keyboard support."

## 9. Release

1. Start after 1.0 is approved and live.
2. Work on a branch; PR; merge.
3. TestFlight build for the user to try on an iPad.
4. Submit 1.1 for review.
