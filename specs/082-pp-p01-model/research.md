# Research: A11-P01 (feature 082)

Facts verified on 2026-11-15 (clarification session): `ExperienceCore` and `ExperienceAction` shapes; `SeededRandom`
state; `Vec2` operations; `VisualCoreSimulation` depends only on `VisualCoreMath`; no box, contact or solver code in any
framework product.

## D1 — Contacts (VisualCoreSimulation)

- **Decision**: `Contacts2D.collide(_:_:_:_:)` over `Shape2D` (`circle(radius)`, `box(halfExtents)`) and `Pose2D`
  (position, angle). Circle–circle by centre distance; circle–box by clamping the circle centre into the box's local
  frame (inside → push out along the least-penetrating face); box–box by the separating-axis test on the four face
  normals, the reference face of least penetration, incident-edge clipping against the reference side planes and
  keeping points below the reference face (one or two points). Normal points from the first shape to the second;
  touching within 1e-9 counts (depth 0). Non-finite poses or non-positive sizes give nil.
- **Rationale**: the standard small 2D rigid-body pipeline; two points make boxes rest flat.
- **Alternatives**: GJK/EPA (general polygons, not needed for circles and boxes); app-local code (rejected: constitution
  A11 reuse first).

## D2 — Impulse solver (VisualCoreSimulation)

- **Decision**: `ImpulseSolver2D.solve(_ bodies: inout [RigidBodyState2D], contacts: [Contact2D], settings:)`: per
  contact point, effective normal mass from inverse mass and inverse inertia (rA×n)², the restitution bias
  −e·vₙ captured before iterating when the closing speed exceeds 0.5 m/s, `settings.iterations` (default 10)
  sequential passes accumulating clamped normal impulses (≥ 0) and friction impulses clamped to ±μ·Pₙ with μ =
  √(μA·μB), e = max(eA, eB); then one positional pass moving each body by its inverse-mass share of
  0.8·max(depth − 0.005, 0) along the normal. A point whose effective mass is 0 (both static) is skipped.
- **Rationale**: sequential impulses are deterministic, simple and stable for small counts; the Phase 01 fixture
  (two-body elastic momentum) holds exactly because equal and opposite impulses are applied.
- **Alternatives**: warm starting and split impulses (A11-P02 for resting stacks).

## D3 — World and integration (app-local)

- **Decision**: per tick: for dynamic bodies v += g·dt, ω unchanged by gravity; v ·= 1/(1 + kₗ·dt), ω ·= 1/(1 + kₐ·dt);
  caps 40 m/s and 40 rad/s; build the solver states (walls and the ledge with inverse mass 0); contacts for every pair
  i < j in id order and every body against each wall; solve; x += v·dt, θ += ω·dt (semi-implicit Euler: velocities
  first, contacts on the new velocities, then positions; positional correction from the solver applied after). Mass =
  density × area (circle πr², box 4·hx·hy), inertia m·r²/2 and m·(w² + h²)/12.
- **Rationale**: semi-implicit Euler is symplectic enough for a toy and matches the solver's velocity-level design.
- **Safeguards added in implementation** (recorded at convergence, T-A11-115): (1) the solver's positional correction of
  a body is limited to 0.1 m per tick (`WorldSimulation.maxCorrectionPerTick`, applied where the corrected positions are
  copied back): a drop onto another body can start with a deep overlap, and an unlimited 80 % correction could push a
  body through a 1 m wall in one tick; with the limit the overlap separates over a few ticks. (2) Before
  `Contacts2D.collide`, a pair whose bounding circles are farther apart than their radii plus 1e-6 m is skipped, and a
  body is tested only against the walls its bounding circle reaches. Because touching counts within 1e-9 m and shapes
  lie inside their bounding circles, the skipped pairs are exactly those `collide` answers with nil, so results are
  identical; it is a pre-filter over all pairs, not a broad phase (G-BROADPHASE stays open for A11-P02). Covered by
  `PhysicsFixtureTests` (containment: five seeds filled to 48 bodies by drops for 2,400 ticks, every centre inside the
  stage and every value finite; the ledge fixture) and `WorldSimulationTests`.

## D4 — Time scale, actions and replay

- **Decision**: the clarified actions; the time-scale remainder is an integer count of quarter ticks, so ¼ runs one tick
  every fourth host step and 2 runs two ticks per host step; `world.step` runs exactly one tick while paused. The
  replay is the seed and the applied actions with their steps; the digest covers the whole world and the generator.

## D5 — Manifest fixtures

- **Decision**: nine standard scenarios plus fixtures: 1 free fall (1 s, no drag, within 1 %), 2 two-body elastic
  momentum (equal circles head-on, e = 1, momentum within 1e-9 relative, velocities exchanged within 2 %), 3 static
  zero mass (a ledge hit for 1,000 ticks moves by 0), 4 replay determinism, 5 frame pacing 1/30, 1/60, 1/120 s, 6 time
  scale and single step, 7 save/restore, 8 resume without catch-up, 9 catalog refusal, 10 body cap.
