# My2048 Roadmap

## Current State

- Based on the SpriteKit Game template; runs on iOS and macOS with a shared `GameScene`.
- Shared model layer now includes `GameBoard`, `GameTile`, and `MoveResult` to handle spawning, sliding, merging, scoring, and win/lose detection.
- `GameStore` (`ObservableObject`) wraps `GameBoard` and exposes moves, restart, board snapshots, score, and win/lose status for both targets.
- `GameScene` binds to `GameStore`, draws the 4×4 grid, and now mirrors the classic 2048 header (title, tagline, score/best panels, "New Game" button, win/lose overlay plus "Keep Going" option) while routing swipe, mouse, and keyboard input back into the model.
- Scene layout dynamically shifts the board/HUD to keep the top controls visible even in short windows.

## Target Architecture

- **Core Model (`Shared/Models`)**`GameBoard` struct stores tile grid, handles random tile spawning, movement, merges, and score updates.`GameTile` represents an individual cell with value, position, and optional animation metadata.
- **View Model (`Shared/ViewModels`)**Observable `GameStore` owning a `GameBoard`, exposing published state for rendering plus inputs API (`move(_:)`, `restart()`).
- **Rendering (`GameScene`)**SpriteKit scene driven by `GameStore`. Listens for swipe/keyboard gestures, maps state diff into node updates/animations.
- **Platform Glue**
  `GameViewController` sets up the scene and injects a shared `GameStore`. macOS target adds keyboard bindings; iOS target focuses on swipe gestures.

## Next Steps

1. Persist HUD data: track and save best score across launches, add move counter, and expose hooks for future UI (settings, undo).
2. Polish presentation: add merge/move animations, subtle particle effects, sound + haptic feedback, and pause darkening during overlays.
3. Add coverage: deterministic unit tests for `GameBoard`/`GameStore`, plus a smoke test that instantiates `GameScene` and simulates moves.

## Manual Test Ideas

- Launch iOS/macOS build; confirm two tiles spawn, score panels show `0`, and best panel retains the session high after restarts.
- Resize the window or rotate on iOS to confirm the title/tagline/score panels stay visible and aligned with the board.
- Reach 2048 and verify the overlay presents a "Keep Going" button that lets you continue playing without resetting; confirm it disappears afterward.
- Compare the header against the mock (title left, score/best/new-game row right-aligned above the board) on both targets.
- Check that score/best/New Game buttons remain evenly spaced, centered across the board width, and text stays within rounded panels regardless of score digits.
- Swipe in each direction (or use arrow keys on macOS) to verify merges update score and HUD without visual glitches.
- Trigger a win/lose state using a debug board or manual play; confirm overlay text appears and restart button resets the board.
- Tap/click restart during play and from overlay; ensure the board re-seeds tiles and status returns to playing.

## Notes

- Keep the model free of SpriteKit dependencies so it can be reused in future UIs.
- Document major gameplay decisions (spawn odds, board size) here as they evolve.
