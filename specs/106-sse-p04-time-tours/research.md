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

## As built (2026-11-15)

- **`date.set` refusals:** the action declares the model's range, so through the engine a day outside it is refused as
  `action.out-of-range` before the core sees it; `a14.out-of-range` comes only when the core is called directly (and
  for `view.apply` values that pass the declared ranges but not the saved view's rules, such as a pitch off its grid).
- **Captions** show the catalog's stored values (Mars: one orbit takes 686.98 days), not the rounded example of the
  clarification.
- **`labelWithTime`** rounds the instant to the second, so sums of 1/120-day steps never read a minute short.
- **Announcements:** the limiter counts its 10 s from the last announcement of either kind (event or periodic date).
- **Label canvas size:** taken from the size the overlay reports; until it reports, the drawable's pixels ÷ the display
  scale.
- **Suspension test:** suspends the shell directly, so frames keep drawing while no step runs (the session's
  background route also pauses the render host, which would hide the property under test).
- **Documented API:** the phase's check found `RecordingAnnouncementSink` (used by the presenter tests since A14-P03)
  undocumented; it is now named in `Packages/VisualCoreRendering/README.md`.
