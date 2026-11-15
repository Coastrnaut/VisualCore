# Research: A09-P03 Editing, feeding and save system

Facts verified on 2026-11-14 (clarification session): `GestureArbiter` semantics (one owner per touch, priority on the
same event, nothing after a discrete owner until lift), `LongPressRecognizer` (0.5 s, recognized on the next event,
fails beyond 10 points), `TapRecognizer` (0.3 s, 10 points), `DragRecognizer` (begins beyond 10 points);
`ExperiencePresenter.pointer` (view points, actions with normalized positions), `gestureActions` ⊆ `nativeActions`
(`GestureAlternatives.missing`); multi-value `ExperienceControl` ranges; the presenter's tank mapping.

## D1 — Gestures

- **Decision**: declarations `feed` (tap, 1), `place` (longPress, 2), `move` (drag, 3), one pointer each. A recognized
  tap → `food.drop`; a recognized long press → `decor.place` at the press point; a drag's `began` hit-tests the decor
  (topmost piece whose centre is within its drawn half size of the touch) and its `began`/`changed` send `decor.move`
  for that piece; a drag that began on water sends nothing. View points → tank fractions through the presenter's
  centred scale (the letterbox outside the tank clamps to 0…1).
- **Rationale**: the arbiter's one-owner rule forbids long-press-then-drag in one touch; drag-to-move is the common
  pattern. Pure mapping type (`AquariumGestures`) keeps it host-testable with synthetic events.
- **Alternatives**: own recognizers in the presenter (duplicates shared code); double tap to remove (no native
  equivalent needed but adds a gesture without value).

## D2 — Feeding model

- **Decision**: per step, after the fish move: pellets sink by 0.5 × dt; for each fish in document order, the nearest
  pellet within 0.5 × length + 0.15 is eaten (removed); then pellets at or below `bounds.minY` are removed. The seek
  force (toward the nearest pellet within 4 units, unit direction × 2.5) is added to the steering force before the cap.
  A feed adds 3 pellets at x − 0.25, x, x + 0.25 (clamped into the swim bounds).
- **Rationale**: deterministic, order defined, bounded (≤ 12 × 24 checks).
- **Alternatives**: pellets as VisualCore particles (not saved state; no eating rule).

## D3 — Schema 3

- **Decision**: `HabitatDocument.currentSchema = 3`, `food: [FoodPellet]` (`position: Vec2`), decoding a missing key as
  []; `migrated(catalog:)` handles 1 → 3 and 2 → 3. Snapshot `MigrationChain(currentVersion: 3)` with steps 1 (identity)
  and 2 (adds `decorKind` 0). Habitat change clears food and keeps `decorKind`.

## D4 — Fixtures

- **Decision**: fixture-8 feeding (Reef, 300 steps, feed at fish 0's position, 600 steps; the test checks that at
  least one pellet was eaten and none remains below the floor); fixture-9 decor editing (kind 1, place at 0.25/0.2,
  move piece 0 to 0.75/0.3, remove piece 1); fixture-10 no fast-forward with food (feed, 60 steps; the session test
  suspends and resumes and compares step and state).
