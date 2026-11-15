# Research: A10-P01 Fixed-step engine and collision fixtures

Facts verified in code on 2026-11-14 (clarification session): no shape-against-shape or swept test exists in any
VisualCore product (`Primitive.contains` / `SceneNode.hitTest` are point tests); `VisualCoreMath.Vec2` gives the vector
operations; `ExperienceAction` carries its `step`; `ExperienceEngine` stops stepping on `suspend()`; `SeededRandom`
saves its state; `FixedStepRunner`'s `ControlStream` exists but the experience path uses actions with steps instead.

## D1 — Collision API (VisualCore)

- **Decision**: value types `CollisionCircle(center, radius)` and `CollisionCapsule(a, b, radius)`; `Collision2D.overlaps`
  for circle–circle (distance² ≤ (r1 + r2)² + 1e-9) and circle–capsule (distance from the centre to the closest point
  of segment ab ≤ r1 + r2 + 1e-9; a degenerate segment is a circle); `Collision2D.sweep(_ a: CollisionCircle, moving
  da: Vec2, _ b: CollisionCircle, moving db: Vec2) -> Double?`: relative motion d = da − db from relative start
  p = a.center − b.center, R = ra + rb; if |p|² ≤ R² return 0; solve |p + t d|² = R² for the smallest t in [0, 1]
  (a = d·d, b = 2 p·d, c = p·p − R²; no hit if a ≈ 0, b ≥ 0 or the discriminant < 0). Non-finite or negative-radius
  input gives false / nil.
- **Rationale**: exact for circles, branch-light, deterministic; the capsule overlap covers bars without rotation
  maths; swept capsules are not needed because their speed is bounded (D3).
- **Alternatives**: conservative advancement or sub-stepping (cost grows with speed, still approximate); a broad phase
  (≤ 24 objects need none).

## D2 — Game step order

- **Decision**: per step: (1) apply this step's steering (target velocity = value × 9, the velocity eases to it at
  60 units/s², clamp x to 0.5…8.5, zero velocity at a wall); (2) spawn if due; (3) for each object in id order: compute
  its displacement, test it against the player (swept for circles using both displacements, end-of-step overlap for
  capsules), apply the hit or pickup and record the event, else move it; remove objects below y = −1; (4) count down
  invulnerability; (5) lives 0 → over. Paused or over: nothing changes.
- **Rationale**: fixed order makes replays exact; testing before moving keeps swept tests on the true path.

## D3 — Capsule speed bound

- **Decision**: capsule hazards fall ≤ 5 units/s = 0.0833 units/step; their smallest summed radius with the player is
  0.2 + 0.4 = 0.6, so a capsule can never pass the player between steps; player speed ≤ 9 units/s = 0.15 units/step
  likewise. A test asserts the bound from the catalog.

## D4 — Replay and events

- **Decision**: the game keeps `events` (last 256 `CollisionEvent`s: step, object id, kind hit/pickup) and
  `eventCount`; the replay test applies a recorded list of `run.steer` actions to two fresh cores and to cores driven
  by 1/30, 1/60 and 1/120 s frames through the engine, then compares score, lives, eventCount and events.

## D5 — Fixtures

- **Decision**: fixture-1 replay (seed, 1,200 steps, 12 recorded steering inputs; asserts identical score, lives and
  events over two runs and the digest); fixture-2 frame pacing (same replay at three frame times); fixture-3 swept hit
  (a circle hazard placed to cross the player within one step at 50× the summed radii per step; one hit recorded);
  fixture-4 save/restore mid-run; fixture-5 resume without catch-up; fixture-6 catalog refusal; fixture-7 bounded
  objects (10,000 steps: objects ≤ 24, player inside the field). Manifest digests derived as in A09-P01.
