# Research: A11-P02 (feature 083)

Facts verified on 2026-11-15 (clarification session).

## D1 — Springs (VisualCoreSimulation)

- **Decision**: `Springs2D.apply(_ bodies: inout [RigidBodyState2D], springs: [Spring2D], dt:)`; per spring the world
  anchors pA, pB, d = pB − pA, L = |d|; skip when L < 1e-9 or both ends static; n = d/L; relative velocity at the
  anchors projected on n; m = 1/(Σ inverse masses); k' = min(k, 0.1·m/dt²); c = min(2ζ√(k'·m), m/dt);
  J = (k'·(L − L₀) + c·vₙ)·dt pulls the ends together when stretched (A gets +J·n at pA, B −J·n at pB, angular by r×J).
  Applied before contacts, in spring order, and before gravity and drag in the world's tick: with gravity first the
  damper sees the gravity speed of the same tick and the rest stretch becomes (m·g − c·g·dt)/k, short by 2ζ·ω·dt
  (measured by the VisualCore agent at implementation; recorded 2026-11-15). The world tick is therefore springs →
  gravity and drag → broad-phase contacts → warm-started solve → integrate.
- **Rationale**: impulse form matches the velocity-level solver; ω·dt ≤ 0.32 keeps semi-implicit Euler's energy error
  small (undamped energy band within 2 % in the fixture).
- **Alternatives**: a spring as a soft constraint inside the solver iterations (more coupling, not needed for ≤ 16).

## D2 — Broad phase

- **Decision**: `AABB2D(min, max)`, `Shape2D.bounds(at: Pose2D)`; `BroadPhase2D.pairs(_ boxes: [AABB2D]) ->
  [BroadPhasePair2D]` sorting indices by min.x (stable, index tiebreak), sweeping with an active list, inclusive
  overlap within 1e-9, output sorted by (i, j) with i < j. A test compares with brute force on 50 seeded scenes.

## D3 — Warm starting and the cache

- **Decision**: `Contact2D` gains `normalImpulses: [Double]` and `tangentImpulses: [Double]` (default `[]`).
  `ImpulseSolver2D.solve(_ bodies: inout, contacts: inout [Contact2D], settings:)` applies stored impulses whose count
  equals the manifold's point count before iterating, then writes the accumulated impulses back; the existing
  non-`inout` solve calls it on a copy (identical Phase 01 results when nothing is stored). The world keeps the cache
  as a saved field (`contactCache`, keyed by body ids and point index) so a save/restore continues exactly; the digest
  covers it.
- **Rationale**: warm starting is the standard remedy for creeping stacks; saving the cache keeps restore exact.

## D4 — Levels and schema 2

- **Decision**: clarified values; `ForceLevels` maps levels to gravity, drag and stiffness; world schema 2 fields
  springs (≤ 16), nextSpringId, gravityLevel 0…2, dragLevel 0…2, stiffnessLevel 0…3, contactCache; migration 1 → 2.

## D5 — Fixtures

- **Decision**: manifest fixtures 11 resting stack (5 wood boxes, 1,200 ticks: top drift < 2 cm, sink < 1 cm), 12 spring
  equilibrium (stretch within 2 % of m·g/k), 13 undamped spring energy (± 2 % over 10 s, no gravity), 14 damped spring
  energy (non-increasing within 0.1 %/s, < 10 % at ζ = 0.5 by 10 s), 15 stiffness clamp, 16 broad phase equals brute
  force, 17 gravity and drag levels, 18 schema-1 migration. Drift over longer runs: the measured per-second drift times
  the run length (stated in the test, not run).
- **As built** (recorded at convergence, T-A11-212): the manifest replays only the experience's
  actions, so fixture 11 is a dropped pile that settles until its fastest body moves below 0.05 m/s, and fixture 13 is
  spring energy with gravity and drag off at the world's damping ratio 0.1 (energy never rises after the switch). The
  five-box stack bound (drift < 2 cm, sink < 1 cm over 1,200 ticks; measured 0.8 mm and 1.4 mm in the world, 2.1 mm and
  1.3 mm in VisualCore) is proven by `StackFixtureTests` and `ImpulseSolver2DTests`, and the undamped ± 2 % band by
  `Springs2DTests`.

