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
  the focused body stays in front of the near plane; every control has a label and value.
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
