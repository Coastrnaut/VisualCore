# Feature Specification: Solar System Explorer — Phase 02 Approximate orbit computation with fixtures

**Feature Branch**: `104-sse-p02-orbits` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A14-P02 (legacy ledger) · ID namespace FR-A14-2##, SC-A14-2##, T-A14-2##

**Input**: User description: archived manual `apps/14-solar-system-explorer.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — orbit view, planet focus and camera navigation; regression fixture — AU to
  km conversion and simulated date changes remain consistent; graphics context ownership stays solely in the VisualCore
  host.
- **Gap built here** (contract `docs/apps/solar-system-explorer/visualcore-contract.json`): G-ORBIT (rows M05, M07,
  M12) — approximate Kepler propagation of an elliptical orbit for a date, generic in VisualCore's math module (tests,
  documentation, API baseline; the reference regression runs at X-A14). The procedural bodies, full scale modes and
  rendering polish stay for A14-P03 (G-BODIES); play, pause and rate, tours and saved view state for A14-P04.
- **Experience:** the candidate experience of A14-P01 gains an orbit view: the Sun, the eight planets at their computed
  positions for a simulated date, their orbit lines, a date stepper, planet focus and camera controls.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A14; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
VisualCoreMath has no orbit propagation (A14-P00 audit); its additive types follow `Ray2` (A13-P01: `Sendable`,
`Equatable`, failable initialisers refusing non-finite input, `///` on every symbol, host tests in
`VisualCoreMathTests`); `OrbitCamera` clamps distance to 0.01…1,000,000 and pitch to ±89°; A14-P01's `SolarState` is
schema 1 (selection only) with refusals `damaged`, `newer-version`, `out-of-range`; the catalog stores periods in days
and AU through `Units.kmPerAU`.

- Q: What does VisualCore offer, in which units and frame? → A: `VisualCoreMath.KeplerOrbit` (new, additive):
  `init?(semiMajorAxis:eccentricity:inclination:ascendingNode:argumentOfPeriapsis:meanAnomalyAtEpoch:meanMotion:)`
  (angles in radians, mean motion in radians per time unit; refuses non-finite values, e outside 0 ≤ e < 1, and
  non-positive axis or motion); `static func eccentricAnomaly(meanAnomaly:eccentricity:) -> Double` (Newton's method
  from E₀ = M for e < 0.8, else π, at most 32 steps, stops below 1e-12 rad); `position(at time:) -> Vec3` in the
  orbit's reference frame (x toward the ascending-node reference direction, y 90° ahead in the reference plane, z
  toward the plane's north), and `meanAnomaly(at:)`, `period`. Generic: any elliptical orbit, no planet data.
- Q: Which elements, from where, under what license? → A: Mean J2000.0 elements of E. M. Standish, "Keplerian
  Elements for Approximate Positions of the Major Planets" (JPL Solar System Dynamics, Table 1, valid 1800–2050):
  a (AU), e, i, mean longitude L, longitude of perihelion ϖ, longitude of the ascending node Ω (degrees) — Mercury
  0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593; Venus 0.72333566, 0.00677672,
  3.39467605, 181.97909950, 131.60246718, 76.67984255; Earth (Earth–Moon barycentre) 1.00000261, 0.01671123,
  −0.00001531, 100.46457166, 102.93768193, 0.0; Mars 1.52371034, 0.09339410, 1.84969142, −4.55343205, −23.94362959,
  49.55953891; Jupiter 5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909; Saturn 9.53667594,
  0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448; Uranus 19.18916464, 0.04725744, 0.77263783,
  313.23810451, 170.95427630, 74.01692503; Neptune 30.06992276, 0.00859048, 1.77004347, −55.12002969, 44.96476227,
  131.78422574. Recorded license `public-domain`: the elements are numerical facts published by a NASA laboratory;
  the record states this basis. The mean motion is 2π / the catalog's sidereal period (no secular rates), so the
  catalog and the orbits agree on periods.
- Q: What is the date range, the start date and the fixture? → A: Days since J2000.0 (2000-01-01 12:00 UTC), allowed
  −18,262.5 … +18,627.5 (1950-01-01 00:00 to 2051-01-01 00:00 UTC, the end of 2050); start at 0. Steps ±1, ±30, ±365 days; others
  refused `a14.invalid-step`; leaving the range refused `a14.out-of-range`. Fixture: Earth's heliocentric ecliptic
  longitude at J2000.0 is 100.38° ± 0.3°; Earth's perihelion and aphelion distances 0.98329 and 1.01671 AU ± 0.2 %;
  Mars between 1.381 and 1.666 AU ± 0.5 %; every planet back within 1e-6 rad of its start angle after one period; 100
  steps forward and back exact; Kepler residual |E − e sin E − M| < 1e-10 for e ∈ {0, 0.2056, 0.5, 0.9, 0.95}.
- Q: How is the orbit view drawn and navigated? → A: Scene plane x–z (ecliptic north = +y); display radius of a point
  at r AU is 4·√r scene units in its direction (Mercury ≈ 2.5, Neptune ≈ 21.9), labelled "Distances and sizes not to
  scale"; orbit lines are 128 samples of each orbit through the same mapping drawn as thin tubes; bodies at A14-P01's
  display radii × 0.6 (the Sun × 0.5). Camera: `OrbitCamera` target = focused body (the Sun for the overview), yaw step
  15°, pitch 5°…85° in 10° steps, distance 4…80 in factors of 1.25, overview yaw 0, pitch 35°, distance 60; focusing a
  body keeps distance ≥ 3 × its display radius + 0.5 (in front of the near plane).
- Q: What is the state and its migration? → A: State schema 2 = selection, `dayOffset` (days since J2000.0), camera
  `yawSteps` (integer), `pitchDegrees` (5…85), `zoomSteps` (integer, distance 60 × 1.25^−n clamped 4…80). Actions:
  `body.select/next/previous` (focus = selection), `date.step [days]`, `camera.orbit [±1]`, `camera.tilt [±1]`,
  `camera.zoom [±1]`, `view.reset`. Schema 1 migrates with dayOffset 0 and the overview camera. The fact card gains
  "Distance from the Sun on <date>: x AU (y km)".

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See where the planets are on a date (Priority: P1) 🎯

A person sees the Sun with the eight planets on their orbits for the shown date; stepping the date forward or back
moves each planet along its orbit by the right amount, and the date is always shown with its time zone.

**Why this priority**: the manual's orbit view and its main validity risk (time accuracy).

**Independent Test**: step the date; read the planets' angles and the shown date.

**Acceptance Scenarios**:

1. **Given** the start date, **When** the orbit view opens, **Then** every planet is drawn on its orbit line at its
   computed position and the date reads in UTC.
2. **Given** a planet, **When** the date steps forward by its orbital period, **Then** it returns to the same place.
3. **Given** a date step forward then back, **Then** the positions return exactly.

---

### User Story 2 - Positions follow a stated, approximate model (Priority: P1)

The owner can trust that positions come from a stated approximate model (Kepler orbits from mean elements at a stated
epoch), match reference positions within stated tolerances inside the model's date range, and are refused outside it.

**Why this priority**: the manual's algorithm decision 1 and false-precision risk.

**Independent Test**: compare computed positions with reference values; try dates outside the range.

**Acceptance Scenarios**:

1. **Given** the reference fixture, **When** positions are computed, **Then** each lies within tolerance.
2. **Given** a date outside the stated range, **When** requested, **Then** it is refused with a reason.
3. **Given** any orbit, **When** solved for any date in range, **Then** the solution converges within a fixed number of
  steps and stays finite.

---

### User Story 3 - Focus a planet and move the camera (Priority: P1)

A person chooses a planet to focus; the camera moves to centre it without passing through it; buttons orbit the camera
left or right, tilt it and zoom in or out within limits, and reset the view.

**Why this priority**: the phase's MVP ("planet focus and camera navigation").

**Independent Test**: focus each planet; operate the camera buttons; read the camera.

**Acceptance Scenarios**:

1. **Given** a planet, **When** focused, **Then** the camera's target is that planet and its distance keeps the planet
   in front of the near plane.
2. **Given** the camera buttons, **When** used, **Then** the view turns, tilts and zooms within its limits; reset
   returns the overview.

---

### User Story 4 - Units and dates stay consistent (Priority: P2)

The owner sees that the shown distances in AU and km agree, and that repeated date changes never drift.

**Why this priority**: the phase's regression fixture.

**Independent Test**: step the date many times forward and the same number back; compare.

**Acceptance Scenarios**:

1. **Given** a planet's distance from the Sun, **When** shown in AU and km, **Then** both agree through the constant.
2. **Given** n steps forward and n back, **Then** the date and every position equal the start.

### Edge Cases

- **High eccentricity (Mercury) and near-zero eccentricity (Venus, Neptune):** the solver converges for both.
- **Negative mean longitudes and angles beyond 360°:** normalised before use.
- **The date range's ends:** the first and last allowed dates are accepted; one step beyond is refused.
- **Very large distances (Neptune at 30 AU):** drawn through a stated display mapping, labelled not to scale.
- **Focus while zoomed in:** the camera distance is clamped so the body never crosses the near plane.

## Requirements *(mandatory)*

### Functional Requirements

**VisualCore (story 2)**

- **FR-A14-201**: VisualCore's math module MUST offer an elliptical Kepler orbit from classical elements (semi-major
  axis, eccentricity 0 ≤ e < 1, inclination, longitude of the ascending node, argument or longitude of perihelion, mean
  anomaly at epoch, mean motion) that returns the position in the reference plane for a time since epoch, solving
  Kepler's equation with a bounded iteration and a stated tolerance.
- **FR-A14-202**: Invalid elements (non-finite, e outside 0…1, non-positive axis or motion) MUST be refused; the solution
  MUST stay finite.
- **FR-A14-203**: The new generic code MUST be documented, covered by host tests and recorded in the API baseline; the
  reference regression runs at X-A14.

**Experience model (stories 1, 2, 4)**

- **FR-A14-210**: The catalog MUST gain each planet's mean orbital elements at epoch J2000.0 with source, units and
  license recorded (audited as in A14-P01).
- **FR-A14-211**: A simulated date (UTC, as days since J2000.0) MUST be part of the experience state, bounded to the
  model's stated range; date steps of ±1, ±30 and ±365 days are actions; out-of-range steps are refused.
- **FR-A14-212**: Positions MUST be computed from the elements for the state's date; a reference fixture MUST agree
  within stated tolerances; stepping by a planet's period returns it within tolerance; forward-then-back is exact.

**Experience view (stories 1, 3)**

- **FR-A14-220**: The experience MUST draw the Sun, the planets at their positions and their orbit lines through the one
  host's drawing path with a stated, labelled distance mapping (not to scale).
- **FR-A14-221**: Native controls MUST step the date, focus a body, orbit, tilt and zoom the camera and reset the view;
  the focused body stays in front of the near plane; every control has a label and value. Camera ranges: yaw in
  15° steps (unbounded, wraps), pitch 5°…85° in 10° steps (5 + 10k), zoom steps −1…12 (distance 60 × 1.25^−n,
  4.12…75); a tilt or zoom step leaving its range is refused `a14.out-of-range`. The minimum distance 4 exceeds
  3 × the largest display radius + 0.5 (Sun 0.8 → 2.9), so focus never crosses the near plane.
- **FR-A14-222**: The scenario manifest MUST be updated (state schema 2 with migration from 1) and pass the runner on
  iOS 27.

### Key Entities

- **Orbit elements**: body, semi-major axis (AU), eccentricity, inclination, ascending node, perihelion longitude,
  mean longitude at epoch (degrees), epoch, source.
- **Simulated date**: days since J2000.0 (UTC), bounded range.
- **View state**: focused body, camera yaw, pitch and zoom level.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A14-201**: 100 % of reference positions within tolerance; 100 % of out-of-range dates refused.
- **SC-A14-202**: The solver converges for e ∈ [0, 0.95] at every tested anomaly within its step bound.
- **SC-A14-203**: Each planet returns to within tolerance after one orbital period; n steps forward and back are exact.
- **SC-A14-204**: The orbit view draws a non-blank frame on the iOS 27 simulator; a date step changes the drawn
  positions; focusing changes the view.
- **SC-A14-205**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The catalog, units, citation audit and candidate experience of A14-P01 exist; the VisualCore mesh, renderer and
  orbit camera pieces of the A14-P00 contract exist.
- Mean elements are held fixed at J2000.0 (no secular rates), so accuracy degrades away from the epoch; the date range
  keeps the stated tolerance.

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 MVP: orbit view, planet focus and camera navigation | FR-A14-220, 221 |
| Regression fixture: AU/km conversion and simulated date changes consistent | FR-A14-211, 212, SC-A14-203 |
| Algorithm decision 1: labelled approximate Kepler orbits | FR-A14-201, 212 |
| Algorithm decision 2: double precision on the CPU, camera-relative for the GPU | FR-A14-201, 220 |
| Algorithm decision 4: labelled timestamps, no precision beyond the model | FR-A14-211 |
| Contract gap G-ORBIT (M05, M07, M12) | FR-A14-201–212 |

## Negative Requirements

- No precision ephemeris, live sky positions or observing aids; no play/pause or tours yet; no images or textures; no
  network; no claim that drawn distances are to scale.
