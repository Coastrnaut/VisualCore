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

## D2b — Spoken changes
- **Decision**: an app-local `BeamAnnouncer` in `MazePresenter.swift` (latest text wins, at most one per second of the
  presenter's frame clock), because Tiny Worlds' `ViewAnnouncer` is internal to that module; touches arrive through the
  presenter's `pointer(_:viewSize:port:)` as in Tiny Worlds.

## D3 — Loops
- **Decision**: `LoopFixtureTests` with three committed boards (mirror path back to the emitter, prism branches meeting,
  a mirror spiral to the bounce cap), asserting reasons and the budgets.

## As built (2026-11-15)

- **Suspension wrapper:** `ExperiencePresenter` has no suspension callback, so `LightMazeExperience.make` now wraps the
  shell in `MazeExperience` (as Neon Arcade's wrapper does): `suspend()` and `beginDeactivation()` call
  `presenter.suspended()`, which forgets every touch, so a touch cut off by backgrounding never stays in the arbiter
  (the next tap would otherwise count as a second finger). The public factory signature is unchanged; tests reach the
  shell as before (`MazeSessionTests.testASuspensionForgetsEveryTouch`).
- **Ring shape:** the lit-target ring is an outline square inset 0.05 from the target (clarification Q4), replacing the
  A13-P01 circle; colours are unchanged.
- **Gesture details:** an axis-aligned drag is exactly 45° from both diagonals and snaps to `\` ("within 45°" is
  strict); a drag that begins on a fixed tile answers as a tap would; refusal words go to the controls' message line,
  while `BeamAnnouncer` speaks only beam changes.
