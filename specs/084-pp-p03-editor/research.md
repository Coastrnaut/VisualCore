# Research: A11-P03 (feature 084)

Facts verified on 2026-11-15 (clarification session).

## D1 — Editing in the core

- **Decision**: `WorldEditing` with pure functions returning a refusal reason or applying the edit: `add(kind:at:)`
  (seeded size from the generator as `drop` does; refused when the cap is reached or the body's bounds leave the
  stage or overlap another body's bounds by more than half the new body's size), `select`, `grab` (dynamic and
  unpinned only), `move` (clamped target), `release`, `togglePin` (static bodies refused), `delete` (removes springs,
  cache entries, grab and selection naming it), `nudge`. Pinned bodies enter the solver and springs with inverse mass
  and inertia 0 and their velocity set to 0 when pinned.
- **Rationale**: keeps every edit a validated, replayable action; pinning reuses the static path the solver already has
  (the gate's mass-zero fixture).

## D2 — Grab pull

- **Decision**: each tick, before the world's springs, a temporary `Spring2D` from the grab anchor to the target world
  point with rest length 0, stiffness `Springs2D.stableStiffness(effectiveMass: m, dt:)` and damping ratio 1.0.
- **Rationale**: stable for any body mass, no new solver code; measured to reach 5 cm of a still target within 1 s.

## D3 — Force measurement

- **Decision**: `ForceMeasurement` records, during each tick, the net spring force on each dynamic body (sum of the
  spring impulses ÷ dt) in a non-saved, derived field rebuilt by the next tick (excluded from the digest and the
  snapshot; recomputed after restore at the next tick, and the arrows of a restored, paused world show 0 spring force
  until a tick runs). Weight is m·g from the settings.

## D4 — Gestures

- **Decision**: `PlaygroundGestures` holds one recognizer of each kind fed with the same `PointerEvent`s, converts the
  first touch point to stage metres, hit-tests bodies (point inside the shape at its pose) and resolves by the clarified
  priority; a tap is reported only after the double-tap window closes (checked on the next event or the frame's tick).

## D5 — Fixtures

- **Decision**: manifest fixtures 19 add at a point, 20 grab, move and release, 21 pin with impacts (the mass-zero
  fixture), 22 unpin and fall, 23 delete with springs, 24 selection and nudge, 25 overlays on and off (digest unchanged
  except the flags), 26 schema-2 migration; refusal entries for each new rule.
