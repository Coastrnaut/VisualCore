# Research: A14-P04 (feature 106)

## D1 — Clock
- **Decision**: step-driven simulated clock in the core; rates [1, 7, 30, 365] days per second; clamp with
  `end-of-range` and pause; "Now" as `date.set [days]` computed by the presenter from an injected clock.
- **Rationale**: replays and digests never depend on wall time; suspension runs no step (host contract), so no
  fast-forward. **Alternatives**: SceneClock with wall-time deltas (non-deterministic replays — rejected).

## D2 — Tours
- **Decision**: two catalog-built tours of 600-step stops; captions generated from catalog values and source titles.
- **Alternatives**: hand-written captions (unsourced numbers risk — rejected); TourTimeline (2D PlaneFraming; timing
  idea reused, not the type).

## D3 — Canvas overlay
- **Decision**: a generic optional overlay slot in the host, non-interactive, inside the canvas frame.
- **Alternatives**: drawing text in GL (no font rasteriser in VisualCore; a large addition — rejected); labels in the
  controls list only (does not meet "labels at projected positions").

## D4 — Labels
- **Decision**: greedy placement by focus then distance; 90 × 20 pt boxes; hidden behind the camera or off canvas.

## D5 — Saved view
- **Decision**: `view.json` schema 1 in `ExperienceStorage`, ≤ 4,096 bytes, applied through `view.apply` (7 values).
