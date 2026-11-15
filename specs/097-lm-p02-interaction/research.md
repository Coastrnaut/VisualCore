# Research: A13-P02 (feature 097)

## D1 — Gestures
- **Decision**: a pure `MazeGestures` over `GestureArbiter` like Tiny Worlds' `WorldsGestures`; the presenter passes a
  view→board mapping (inverse camera of the last frame) and a `send` closure. Snaps send only `tile.select` and
  `tile.turn` (clarification Q2 amended), so gesture actions are a subset of the native ones.
- **Alternatives**: a new `tile.orient` action (rejected: needs its own native control; select + turn reach the same
  state).

## D2 — Glow
- **Decision**: layered primitives (halo, then core) per segment; static; no effect graph pass. **Rationale**: exact,
  cheap, legible, nothing to flash; the effect graph's bloom stays available for later polish (A13-P04) if needed.

## D3 — Loops
- **Decision**: `LoopFixtureTests` with three committed boards (mirror path back to the emitter, prism branches meeting,
  a mirror spiral to the bounce cap), asserting reasons and the budgets.
