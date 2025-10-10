# My2048 Roadmap

## Current State

- Based on the SpriteKit Game template; runs on iOS and macOS with a shared `GameScene`.
- Shared model layer now includes `GameBoard`, `GameTile`, and `MoveResult` to handle spawning, sliding, merging, scoring, and win/lose detection.
- `GameStore` (`ObservableObject`) wraps `GameBoard` and exposes moves, restart, board snapshots, score, and win/lose status for both targets.
- `GameScene` binds to `GameStore`, draws the 4×4 grid, and now mirrors the classic 2048 header (title, tagline, score/best panels, "New Game" button, win/lose overlay plus "Keep Going" option) while routing swipe, mouse, and keyboard input back into the model.
- Scene layout dynamically shifts the board/HUD to keep the top controls visible even in short windows.
- Core logic exposes `ScorePersistence` with `UserDefaults` + in-memory implementations; `GameStore` automatically restores/persists the best score through this layer.

## Target Architecture

- **Core Model (`Shared/Models`)**`GameBoard` struct stores tile grid, handles random tile spawning, movement, merges, and score updates.`GameTile` represents an individual cell with value, position, and optional animation metadata.
- **View Model (`Shared/ViewModels`)**Observable `GameStore` owning a `GameBoard`, exposing published state for rendering plus inputs API (`move(_:)`, `restart()`).
- **Rendering (`GameScene`)**SpriteKit scene driven by `GameStore`. Listens for swipe/keyboard gestures, maps state diff into node updates/animations.
- **Platform Glue**
  `GameViewController` sets up the scene and injects a shared `GameStore`. macOS target adds keyboard bindings; iOS target focuses on swipe gestures.

## Next Steps

1. Extend persistence beyond best score (last board snapshot, move counter, undo stack, multi-profile support).
2. Polish presentation: add merge/move animations, subtle particle effects, sound + haptic feedback, and pause darkening during overlays.
3. Add coverage: expand `swift test` cases (spawn odds, undo, continue flow) plus a SpriteKit smoke test to verify layout diffing.

## Persistence & Tests

- `ScorePersistence` lives under `My2048 Shared/ViewModels`. `UserDefaultsScorePersistence` backs the app; `MemoryScorePersistence` powers tests and previews.
- `Package.swift` exposes `Models` + `ViewModels` as the `My2048Core` SwiftPM target, plus a `My2048CoreTests` XCTest bundle.
- Run unit tests via `swift test` (needs Xcode command-line tools and write access to SwiftPM caches). If sandboxed caches fail, rerun with `SWIFTPM_CACHE_PATH=$PWD/.build/cache swift test`.

### Running Tests with Xcode Toolchain

macOS provides two Swift toolchains: Command Line Tools (no XCTest) and the full Xcode toolchain (includes XCTest and platform SDKs). When `swift test` runs under Command Line Tools it fails to find XCTest.

Switch once to the Xcode toolchain:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Verify the active path:

```bash
xcode-select -p
# /Applications/Xcode.app/Contents/Developer
```

Optional revert to Command Line Tools:

```bash
sudo xcode-select -s /Library/Developer/CommandLineTools
```

This only affects command-line Swift invocations; Xcode itself always uses its bundled toolchain.

## Manual Test Ideas

- Launch iOS/macOS build; confirm two tiles spawn, score panels show `0`, and best panel retains the session high after restarts.
- Resize the window or rotate on iOS to confirm the title/tagline/score panels stay visible and aligned with the board.
- Reach 2048 and verify the overlay presents a "Keep Going" button that lets you continue playing without resetting; confirm it disappears afterward.
- Compare the header against the mock (title left, centered score/best/New Game row above the board) on both targets.
- Check that score/best/New Game buttons remain evenly spaced, centered across the board width, and text stays within rounded panels regardless of score digits.
- Swipe in each direction (or use arrow keys on macOS) to verify merges update score and HUD without visual glitches.
- Trigger a win/lose state using a debug board or manual play; confirm overlay text appears and restart button resets the board.
- Tap/click restart during play and from overlay; ensure the board re-seeds tiles and status returns to playing.

## Notes

- Keep the model free of SpriteKit dependencies so it can be reused in future UIs.
- Document major gameplay decisions (spawn odds, board size) here as they evolve.
