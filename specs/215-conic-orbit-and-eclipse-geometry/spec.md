# Feature Specification: R02-F15 — Conic orbit and eclipse geometry

**Feature Branch**: `215-conic-orbit-and-eclipse-geometry` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Clarified

**Ledger gate**: R02-F15 (migration ledger, shared round feature) · ID namespace FR-R02F15-###, SC-R02F15-###, T-R02F15-###

**Input**: User description: the archived R02-F15 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Kepler anomaly solver; projected overlap; phase stepping; visibility classification", with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/215-conic-orbit-and-eclipse-geometry`; FR-R02F15-###, SC-R02F15-###,
  T-R02F15-###.
- **Section 13 disposition: extend.** The framework has `KeplerOrbit` (feature 104): an elliptical orbit
  (0 ≤ e < 1) from classical elements, Kepler's equation solved by Newton's method, and the position at a time. It has
  no parabolic or hyperbolic paths, no true anomaly or velocity, no deterministic phase stepping, no overlap of two
  projected disks, and no classification of what an observer sees (none, partial, annular, total, hidden). This feature
  adds those beside `KeplerOrbit`, which stays unchanged and is reused for the elliptic case; Solar System Explorer's
  `OrbitElements` is untouched.
- **Who the users are:** the player of Celestial Eclipse Lab, Apsides Workshop, Binary Gardens or Starlit Cartouche who
  moves bodies along orbits, scrubs time and watches eclipses and transits happen; the engineer, who needs positions,
  phases and eclipse verdicts to be exact, bounded and identical on every device.
- **Prerequisites:** R02-F03 (numerical foundations) and R02-F05 (precision and budgets) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** none beyond the regression; the consuming experiences measure frame
  time on D1–D3 in the device campaign. **Owner-only items:** none.

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): `KeplerOrbit` (VisualCoreMath; semi-major axis, 0 ≤ e < 1, i, Ω, ω, M₀, n;
`eccentricAnomaly(meanAnomaly:eccentricity:)` by Newton, 32 steps, step tolerance 1e-12; `position(at:)`) is used by
tests only in the framework; Solar System Explorer has its own `OrbitElements`; `Vec2`, `Vec3` are in VisualCoreMath,
which depends on nothing; the names `ConicOrbit`, `KeplerSolver`, `OrbitState`, `PhaseStepper`, `DiskOverlap`,
`EclipseGeometry`, `EclipseClass`, `OrbitError` are free (`Visibility` is taken).

- Q: Where do the parts live and how are elements given? → A: all in VisualCoreMath. `ConicOrbit` takes periapsis
  distance q > 0, eccentricity e ≥ 0, inclination, ascending node, argument of periapsis (radians, the frame of
  `KeplerOrbit`), time of periapsis tₚ and gravitational parameter μ > 0, all finite (Double). Mean motion
  n = √(μ/|a|³) with a = q/(1 − e) for e ≠ 1, and n = √(μ/(2q³)) for the parabola. For e < 1 an adapter gives the
  equal `KeplerOrbit` (a, e, i, Ω, ω, M₀ = −n·tₚ, n). Rationale: Section 13's home; periapsis distance stays finite for
  every conic. Impact: FR-R02F15-001, 003; SC-R02F15-002.
- Q: How is each Kepler equation solved, and where is the parabolic band? → A: elliptic: `KeplerOrbit.eccentricAnomaly`,
  then at most 8 further Newton steps while the residual |E − e·sin E − M| exceeds 1e-12; hyperbolic
  (e·sinh H − H = M): Newton from H₀ = sign(M)·ln(2|M|/e + 1.8), at most 64 steps, stop when the step is below
  1e-12·max(1, |H|); parabolic (|e − 1| ≤ 1e-9, Barker's equation): closed form s = y − 1/y, y = ∛(W + √(W² + 1)),
  W = (3/2)·n·(t − tₚ), true anomaly ν = 2·atan(s). Results are always finite. Rationale: reuse the existing solver,
  closed form where Newton is weakest. Impact: FR-R02F15-002; SC-R02F15-001; the near-parabolic edge case: for
  μ = q = 1 and |t − tₚ| ≤ 10, positions at e = 1 ± 1e-4 differ from the parabola's by a relative ≤ 1e-3.
- Q: How does phase stepping avoid drift, and how are passages counted? → A: `PhaseStepper` has a start time t₀, a step
  Δt > 0 and a tick k in 0 … 1,000,000,000; time(k) = t₀ + Double(k)·Δt is computed directly, never accumulated, so
  stepping and jumping agree bit for bit. Phase of a closed orbit = ((t − tₚ)/P) mod 1 in [0, 1); open orbits have no
  phase (nil). Passages in the half-open span [tₐ, t_b) are listed in time order, periapsis at tₚ + jP and apoapsis at
  tₚ + (j + ½)P; an open orbit has one periapsis passage at tₚ. Rationale: half-open spans report each passage once.
  Impact: FR-R02F15-004; SC-R02F15-003.
- Q: How are eclipses projected and classified? → A: from an observer, angular radii αₛ = asin(Rₛ/dₛ),
  αₒ = asin(Rₒ/dₒ) and separation θ (angle between the two directions) feed the planar disk overlap of radii αₛ, αₒ at
  distance θ (exact for the disk model, the usual small-angle approximation of the sky). Classes: **hidden** when an
  optional ground sphere (the observer's own body) puts the whole source disk below the horizon; otherwise **none** when
  the occluder is not nearer than the source (dₒ ≥ dₛ) or θ ≥ αₛ + αₒ (touching gives none); **total** when αₒ ≥ αₛ and
  θ ≤ αₒ − αₛ; **annular** when αₒ < αₛ and θ ≤ αₛ − αₒ; else **partial**. The verdict reports αₛ, αₒ, θ, covered
  fraction and class. Impact: FR-R02F15-005, 006; SC-R02F15-004, 005.
- Q: What is stored, and what are the failure codes? → A: `ConicOrbit` is `Codable` as JSON with sorted keys
  `{"schema":1,"periapsisDistance","eccentricity","inclination","ascendingNode","argumentOfPeriapsis",
  "timeOfPeriapsis","gravitationalParameter"}`; schema 1 is the first stored form (no earlier form exists, so nothing
  migrates yet; a later schema adds a step to the consumer's `MigrationChain`); schema above 1 is refused. Reason codes
  (`OrbitError`): `r2-f15.invalid-elements`, `r2-f15.invalid-step`, `r2-f15.tick-limit`, `r2-f15.invalid-disk`,
  `r2-f15.observer-inside`, `r2-f15.span-limit` (a passage span listing more than 1,000,000 passages),
  `r2-f15.newer-schema`, `r2-f15.malformed`; the experience adds its id, seed and tick.
  Impact: FR-R02F15-007, 008; SC-R02F15-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Place a body on any conic path (Priority: P1) 🎯

The engineer describes a closed (elliptic), escape (parabolic) or flyby (hyperbolic) path and asks where the body is,
how fast it moves and at which angle from periapsis it stands at any time.

**Why this priority**: every consumer moves bodies along these paths.

**Independent Test**: for seeded elements of all three kinds, the solved anomaly satisfies its Kepler equation to a
stated tolerance; elliptic positions equal the existing orbit's positions; energy and angular momentum stay constant
along the path.

**Acceptance Scenarios**:

1. **Given** elliptic elements, **When** the position at a time is asked, **Then** it equals the existing orbit's
   position for the same elements.
2. **Given** near-parabolic eccentricities on either side of 1, **When** solved, **Then** the result is finite and
   continuous across the boundary.
3. **Given** invalid elements (non-positive periapsis distance, negative eccentricity, non-finite values), **When**
   created, **Then** they are refused with a named reason.

### User Story 2 - Step phases deterministically (Priority: P1)

The engineer advances time in fixed steps and reads each body's phase (fraction of its period) and the passages of
periapsis and apoapsis between two steps; a run of many steps lands on exactly the same time and phases as a direct
jump to that step.

**Independent Test**: stepping n times equals evaluating at step n directly; no drift after a long run; every periapsis
passage in a span is reported once.

### User Story 3 - See an eclipse or a transit (Priority: P1)

From an observer's position, the engineer projects a light source and an occluding body onto the sky and asks how much
of the source is covered and what kind of event it is: none, partial, annular, total, or the source hidden behind the
observer's side.

**Independent Test**: overlap fractions of two disks match the analytic lens area for seeded cases; the class follows
the stated thresholds at every boundary.

### User Story 4 - Save orbits and open them later (Priority: P2)

A set of conic elements is saved with a schema version and opened by a later version; a newer schema or damaged data
is refused with a named reason.

**Independent Test**: a saved orbit round-trips byte for byte; schema above the current one and damaged data are
refused.

### Edge Cases

- **Eccentricity exactly 1, or within 1e-9 of it:** the parabolic closed form is used, so results stay finite; at
  e = 1 ± 1e-4 positions differ from the parabola's by a relative ≤ 1e-3 (μ = q = 1, |t − tₚ| ≤ 10).
- **Hyperbolic time far from periapsis:** the solver stays finite (bounded steps), and the true anomaly stays inside the
  asymptote limits.
- **Disks that just touch, that are equal, or where one is inside the other:** overlap is 0, exact, or the smaller
  disk's full area.
- **An occluder behind the observer or behind the source:** no eclipse is reported (dₒ ≥ dₛ, or θ ≥ αₛ + αₒ).
- **An observer inside the source, the occluder or the ground:** refused with `r2-f15.observer-inside`.
- **Zero-size or non-finite radii and positions:** refused with a named reason.
- **A passage span that would list more than 1,000,000 passages, or whose ends are not finite or reversed:** refused
  with `r2-f15.span-limit` (reversed or non-finite ends: `r2-f15.invalid-step`).
- **A tick beyond 1,000,000,000 or a step that is not finite and positive:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F15-001**: A conic orbit MUST describe elliptic, parabolic and hyperbolic paths from periapsis distance,
  eccentricity, orientation angles, time of periapsis and gravitational parameter, refusing invalid elements.
- **FR-R02F15-002**: A Kepler solver MUST solve the elliptic, parabolic and hyperbolic forms of Kepler's equation in a
  bounded number of steps to a stated tolerance, always returning a finite result, and give the true anomaly.
- **FR-R02F15-003**: The orbit MUST give position and velocity at any time; for elliptic elements the position MUST equal
  the existing elliptical orbit's.
- **FR-R02F15-004**: A phase stepper MUST advance time in fixed whole steps without drift and report phases and periapsis
  and apoapsis passages between steps.
- **FR-R02F15-005**: Overlap of two projected disks MUST be computed exactly (analytic lens area) as an area and as a
  fraction of the source disk.
- **FR-R02F15-006**: Eclipse geometry MUST project source and occluder from an observer into angular radii and
  separation and classify the event as none, partial, annular, total or hidden.
- **FR-R02F15-007**: Orbits MUST have a versioned stored form; a newer schema and damaged data MUST be refused with a
  named reason.
- **FR-R02F15-008**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F15-009**: The existing elliptical orbit, Solar System Explorer and their tests MUST be unchanged; every new
  public name carries documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Conic orbit**: shape, orientation, time of periapsis, gravitational parameter.
- **Orbit state**: position, velocity, true anomaly at a time.
- **Phase stepper**: fixed step, step count, phases and passages.
- **Disk overlap**: two disks, overlap area and fraction.
- **Eclipse verdict**: angular radii, separation, covered fraction, class.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F15-001**: For 1,000 seeded elements of each kind, the solved anomaly satisfies its Kepler equation to 1e-10
  and energy and angular momentum stay constant to a relative 1e-9 along the path.
- **SC-R02F15-002**: For 1,000 seeded elliptic elements and times, positions equal the existing orbit's to a relative
  1e-9.
- **SC-R02F15-003**: Stepping 100,000 fixed steps equals evaluating the last step directly, bit for bit; every passage in
  a span of 100 periods is reported exactly once.
- **SC-R02F15-004**: For 1,000 seeded disk pairs, overlap equals an independent numerical integration to 1e-6 of the
  smaller disk's area; touching, equal and nested disks give their stated values.
- **SC-R02F15-005**: At least five fixtures per class (none, partial, annular, total, hidden) give their stated class;
  stored orbits round-trip byte for byte and newer and damaged forms are refused.
- **SC-R02F15-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- Two-body motion only: no perturbations, no n-body integration, no relativity.
- Disks are uniform circles (no limb darkening); bodies are spheres.
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: controls, layout and accessibility belong to the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Kepler anomaly solver | FR-R02F15-001, 002, 003 |
| Phase stepping | FR-R02F15-004 |
| Projected overlap | FR-R02F15-005 |
| Visibility classification | FR-R02F15-006 |
| Schema migration | FR-R02F15-007 |
| Observability | FR-R02F15-008 |
| No Stage One breakage | FR-R02F15-009 |

## Negative Requirements / Excluded scope

- No GPU code, no new module, no change to `KeplerOrbit` or Solar System Explorer, no real ephemerides or body data, no
  n-body physics, no device run before ImplementationLock-100, no analytics.
