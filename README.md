# My2048 Roadmap

## Current State
- Based on the SpriteKit Game template; runs on iOS and macOS with a shared `GameScene`.
- Shared model layer now includes `GameBoard`, `GameTile`, and `MoveResult` to handle spawning, sliding, merging, scoring, and win/lose detection.
- `GameStore` (`ObservableObject`) wraps `GameBoard` and exposes moves, restart, board snapshots, score, and win/lose status for both targets.
- `GameScene` still renders the template demo content (label/spinny nodes) — no 2048 board visuals yet.

## Target Architecture
- **Core Model (`Shared/Models`)**  
  `GameBoard` struct stores tile grid, handles random tile spawning, movement, merges, and score updates.  
  `GameTile` represents an individual cell with value, position, and optional animation metadata.
- **View Model (`Shared/ViewModels`)**  
  Observable `GameStore` owning a `GameBoard`, exposing published state for rendering plus inputs API (`move(_:)`, `restart()`).
- **Rendering (`GameScene`)**  
  SpriteKit scene driven by `GameStore`. Listens for swipe/keyboard gestures, maps state diff into node updates/animations.
- **Platform Glue**  
  `GameViewController` sets up the scene and injects a shared `GameStore`. macOS target adds keyboard bindings; iOS target focuses on swipe gestures.

## Next Steps
1. Replace template visuals with a 4×4 board layout; wire up gestures/keyboard input to `GameStore`.
2. Add animations, win/lose overlays, and persistence (high score, undo) once the loop is stable.
3. Cover `GameBoard`/`GameStore` with unit tests for move logic and reset flows.

## Notes
- Keep the model free of SpriteKit dependencies so it can be reused in future UIs.
- Document major gameplay decisions (spawn odds, board size) here as they evolve.
