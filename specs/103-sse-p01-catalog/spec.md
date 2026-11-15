# Feature Specification: Solar System Explorer — Phase 01 Scientific catalog, units and citation audit

**Feature Branch**: `103-sse-p01-catalog` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A14-P01 (legacy ledger) · ID namespace FR-A14-1##, SC-A14-1##, T-A14-1##

**Input**: User description: archived manual `apps/14-solar-system-explorer.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — the Sun and the eight major planets with curated fact cards (the manual's
  licensed textures are replaced by procedural surfaces made in code); regression fixture — known approximate orbital
  periods and radii match the stored catalog within tolerances; graphics context ownership stays solely in the
  VisualCore host.
- **Gap built here** (contract `docs/apps/solar-system-explorer/visualcore-contract.json`): G-CATALOG (rows M06, M09,
  M11, M15, M20) — the body catalog with sourced data, explicit unit conversion and the citation record. Orbits stay for
  A14-P02 (G-ORBIT); procedural bodies, the scene, focus and scale modes for A14-P03 (G-BODIES); time, tours and fact-card
  presentation for A14-P04; the provenance and tolerance review for A14-P05.
- **Experience:** created in `Packages/ExperiencesCreative/SolarSystemExplorer`, registered as a candidate with its
  scenario manifest; the slice draws the nine bodies and shows the selected body's fact card that a person can change
  with native controls — no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A14; every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Meet the Sun and the eight planets (Priority: P1) 🎯

A person opens Solar System Explorer and sees the Sun and the eight major planets side by side; choosing a body shows
its fact card — mean radius, distance from the Sun, orbital period and axial tilt — each value with its unit and its
source.

**Why this priority**: the manual's first journey and the phase's MVP.

**Independent Test**: open the experience; select each body; read the fact card and the drawn frame.

**Acceptance Scenarios**:

1. **Given** the experience, **When** it opens, **Then** nine bodies are drawn in catalog order and the first is selected.
2. **Given** a selected planet, **When** its card is read, **Then** every value shows a unit and a source.
3. **Given** a selection, **When** the next or previous body is chosen, **Then** the card and the drawn highlight change.

---

### User Story 2 - Units are explicit and convert exactly (Priority: P1)

The owner can trust every number: distances are stored in kilometres and converted to astronomical units with the
defined constant, times in days and years, angles in degrees, and no value is shown without its unit.

**Why this priority**: the manual's algorithm decision 3 and main validity risk (unit and time accuracy).

**Independent Test**: convert known values both ways; compare.

**Acceptance Scenarios**:

1. **Given** 1 astronomical unit, **When** converted to kilometres, **Then** it is exactly 149,597,870.7 km, and back.
2. **Given** each body, **When** its distance is shown in AU and km, **Then** both agree through the constant.
3. **Given** a non-finite or negative value, **When** converted or stored, **Then** it is refused.

---

### User Story 3 - The catalog matches known values (Priority: P1)

The owner can trust the stored catalog: independent approximate reference values for orbital periods and radii agree
with it within stated tolerances.

**Why this priority**: the phase's regression fixture.

**Independent Test**: compare each planet's stored period and radius with the fixture values.

**Acceptance Scenarios**:

1. **Given** the fixture of approximate periods and radii, **When** compared with the catalog, **Then** every planet is
   within tolerance.
2. **Given** the catalog's order, **When** read, **Then** the planets are ordered by increasing distance from the Sun.

---

### User Story 4 - Every number has a source (Priority: P2)

The owner can show where each bundled number came from: source, epoch, units and license are recorded, a citation
audit refuses missing or unsupported records, and a committed document lists them.

**Why this priority**: the constitution's data-provenance rule and row M20.

**Independent Test**: run the citation audit; compare the committed document with the catalog.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** audited, **Then** 0 problems are found and the committed document matches.
2. **Given** a value without a source or with an unsupported license, **When** audited, **Then** the problem is named.

### Edge Cases

- **The Sun has no orbit around itself:** its distance and period are absent, never zero, and the card says so.
- **Venus and Uranus rotate retrograde:** axial tilts above 90° are stored as given, with the convention stated.
- **Rounding:** cards round for display, the stored values stay unrounded; tolerances are stated per quantity.
- **A damaged or newer catalog document:** refused as a whole; the bundled catalog is used.
- **Selection beyond the ends:** previous at the first body or next at the last is refused with a reason.

## Requirements *(mandatory)*

### Functional Requirements

**Catalog and units (stories 2, 3)**

- **FR-A14-101**: The experience MUST define a catalog of the Sun and the eight major planets with id, name, mean
  radius (km), semi-major axis (km; absent for the Sun), sidereal orbital period (days; absent for the Sun) and axial
  tilt (degrees), in increasing distance from the Sun.
- **FR-A14-102**: Unit conversion MUST be explicit: km ↔ AU through 1 AU = 149,597,870.7 km, days ↔ Julian years
  through 365.25 days; non-finite or negative magnitudes are refused.
- **FR-A14-103**: A fixture of independent approximate periods and radii MUST agree with the catalog within stated
  tolerances (relative, per quantity).
- **FR-A14-104**: The catalog MUST round-trip through a versioned, validated document; damaged, newer or out-of-range
  documents are refused as a whole.

**Citations (story 4)**

- **FR-A14-110**: Every catalog value MUST carry a source (title, publisher, link text), an epoch, its units and a
  license; a citation audit MUST refuse missing or unsupported records, and a committed document generated from the
  catalog MUST match it.

**Experience slice (story 1)**

- **FR-A14-120**: The experience MUST draw the nine bodies through the one host's drawing path as lit spheres with
  procedural colouring made in code, sized in a stated visibility-enhanced scale and labelled as not to scale, with the
  selected body highlighted.
- **FR-A14-121**: Native controls MUST select the previous or next body and show its fact card (each value with unit and
  source); every control has an accessible label and value.
- **FR-A14-122**: The experience MUST be registered as a candidate with a scenario manifest (standard scenarios and at
  least five fixtures) and pass the runner on iOS 27.

### Key Entities

- **Celestial body**: id, name, kind (star, planet), mean radius, semi-major axis, orbital period, axial tilt.
- **Source record**: value key, source title, publisher, link text, epoch, units, license.
- **Fact card**: body, ordered facts (label, value, unit, source).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A14-101**: 9 bodies load in order; 100 % of planets match the fixture's periods and radii within tolerance.
- **SC-A14-102**: AU ↔ km conversion is exact to the defined constant both ways; 100 % of non-finite or negative inputs
  are refused.
- **SC-A14-103**: The citation audit reports 0 problems; the committed document matches; each damaged-record fixture is
  refused with its reason.
- **SC-A14-104**: The nine bodies draw a non-blank frame on the iOS 27 simulator; changing the selection changes the
  drawn highlight and the card.
- **SC-A14-105**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The VisualCore pieces of the A14-P00 contract (UV sphere, lit mesh renderer, orbit camera, storage, manifest and
  runner) exist; the experience pattern of A12–A13 (Core, Experience with Adapter/, candidate registration) applies.
- The values come from a public-domain or openly licensed reference; the epoch is stated.

## Traceability

| Source | Requirement |
|---|---|
| Phase 01 MVP: Sun and eight planets with curated fact cards (procedural surfaces) | FR-A14-101, 120, 121 |
| Regression fixture: known approximate periods and radii match the catalog | FR-A14-103, SC-A14-101 |
| Algorithm decision 3: explicit AU/km, separate physical and display scale | FR-A14-102, 120 |
| Feature 6: references and units on educational claims | FR-A14-110, 121 |
| Contract gap G-CATALOG (M06, M09, M11, M15, M20) | FR-A14-101–110 |
| EGL/context ownership in the VisualCore host | FR-A14-120 |

## Negative Requirements

- No orbits, time controls, tours or scale switching in this phase; no images, textures or data without a license; no
  network; no claim that the drawn sizes or distances are to scale.
