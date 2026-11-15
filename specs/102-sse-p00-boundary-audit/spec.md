# Feature Specification: Solar System Explorer — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `102-sse-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A14-P00 (legacy ledger) · ID namespace FR-A14-0##, SC-A14-0##, T-A14-0##

**Input**: User description: archived manual `apps/14-solar-system-explorer.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Solar System Explorer (`a14.solar-system-explorer`) is an experience of the VisualCore app,
  built in `Packages/ExperiencesCreative/SolarSystemExplorer` (Auto-Creator.md §16 layout: Core, CoreTests, Experience
  with Adapter/, ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target, bundle
  identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met by
  the one app itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A13;
  the contract lives in `docs/apps/solar-system-explorer/`.
- **Visuals are code:** planet surfaces, rings, the Sun, orbits and the starfield are procedural geometry, noise and
  shaders; the manual's licensed textures are replaced by procedural surfaces; bundled data (orbital elements, radii,
  periods, facts) needs a license and provenance record.
- **Constitution:** 2.10.0 adds the A14 experience rules (committed at the start of this gate).
- **Evidence:** host and simulator only; device tasks are tagged {device} and wait for ImplementationLock-100.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
the A14 constitution commit is `462c0a1f` and the A14-P00 specify commit `9335c07c` (the phase start: the no-change
diff of `Packages` and `External` is taken from it); the reference submodule is pinned at `d93edd1`; thirteen
experiences are registered (`Catalog/registrations.json`, A01–A13). VisualCore offers `VisualCoreMath` `Vec3`, `Mat4`,
`Quat`, `OrbitCamera` (with `OrbitBounds`), `CameraRail`, `FramingFlight` with `TourTimeline`, `OriginRebase`,
`PrecisionAdvisor` and `Ray3`/`RayHit3` with ray–sphere, box and triangle casts (`RayIntersection.swift`);
`VisualCoreScenes` `MeshGenerators.uvSphere(segments:rings:radius:)`, `MeshBuilder`, `GradientNoise2D` and
`FractalNoise2D`; `VisualCoreRendering` `MeshRenderer` (Lambert lighting toward a light direction, an `OrbitCamera` or
explicit view and projection, per-vertex colours, `MeshFog`), `DepthMeshPass`, `RenderTarget`, `PrimitiveRenderer`
and `ResourceRegistry`; `VisualCoreSimulation` `SceneClock` (bounded delta, speed 0–4, reduced-motion factor),
`Timeline`, `FixedStepClock` and `FixedStepRunner`; gesture recognizers with `GestureArbiter`; accessibility planners
and sinks; `ExperienceStorage`, `DocumentStore`, `MigrationChain`. No Kepler or other orbit propagation, no simulated
calendar date with a time rate, no astronomical unit conversion and no body catalog exist in any framework product
(grep for kepler, eccentric anomaly, ephemeris finds nothing).

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: As for A13: the one app is the shell;
  this phase proves it builds for testing with Solar System Explorer absent; the targets come with A14-P01's first
  rules.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least one
  test that exercises it; an implementation that exists only inside another experience or a harness is "requires
  adaptation" at best.
- Q: Which package holds Solar System Explorer? → A: `Packages/ExperiencesCreative/SolarSystemExplorer`
  (Auto-Creator.md §16), as A05–A13 did; no new package is created.
- Q: Does Solar System Explorer need a permission or a new privacy answer? → A: No. Version 0.1 needs no location,
  camera, motion, microphone or network; "reset to present" reads the device clock only; view state lives in the
  experience's own storage, so the app's privacy answers do not change.
- Q: Which pieces exist, and who owns the missing ones? → A: Vectors, matrices, quaternions, the orbit camera, camera
  rails and tour timelines, origin rebasing and precision advice, ray–sphere picking, the UV sphere, noise, the
  lit mesh renderer with fog, render targets, the scene clock, gestures, accessibility planners and storage exist. Gaps
  and owners, following the manual's phases (P01 scientific catalog, units and citation audit, P02 approximate orbit
  computation with fixtures, P03 camera and 3D body rendering, P04 time controls and guided tours, P05 scientific review
  and device QA): the body catalog with sourced data, unit conversion and the citation record → app-local (A14-P01);
  approximate Kepler propagation for a simulated date → `VisualCoreMath` if reusable, else app-local (A14-P02);
  procedural planet surfaces, rings, the Sun, starfield, orbit lines, labels, camera-relative positions, planet focus
  and the two scale modes → app-local over the mesh renderer, noise and the orbit camera (A14-P03); the simulated clock
  with play, pause, rate and a bounded date range, captioned tours, fact cards and saved view state → app-local over
  `SceneClock`, `TourTimeline` and `ExperienceStorage`, with a reusable scaled-date clock assessed for
  `VisualCoreSimulation` (A14-P04); the data provenance and tolerance review → app-local (A14-P05). The audit confirms or corrects each from the code and the
  manual's phase list.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Solar System Explorer gets a map of what VisualCore already provides for each capability
the experience needs — 3D scenes, camera controls, materials and lighting, animation, and time-based simulation — and
for each version 0.1 feature, with real files, declared names and package products, each marked available, requires
adaptation or upstream gap.

**Why this priority**: the manual's first review gate; every later phase depends on it.

**Independent Test**: run the contract checker; every cited file exists, every cited name is declared, every product
exists, and every non-available row has a gap entry.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the checker runs, **Then** it passes with 0 problems.
2. **Given** a cited name that does not exist, **When** the checker runs, **Then** it fails naming it.
3. **Given** the five brainstorm capabilities and the six version 0.1 features, **When** the traceability is read,
   **Then** each maps to at least one matrix row.

---

### User Story 2 - The reference stays proven (Priority: P1)

The owner sees that the ProjectM reference regression passes before any Solar System Explorer work, and the starting
commit is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Solar System Explorer absent, so
Phase 01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Solar System Explorer is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Solar System Explorer can proceed, what is missing upstream, and which
module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable 3D drawing path were missing, **Then** the decision
   is "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a sphere mesh but no orbit model, or a scene clock but no scaled
  simulated date): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example Fractal Explorer's precision helpers or Tiny
  Worlds' orbit camera use) but not in a framework product: not counted as available; reuse needs it in VisualCore
  first.
- **Astronomical scale versus single-precision drawing** (the manual's algorithm decision 2): the audit records the
  existing precision and origin-rebasing pieces and assigns the double-precision, camera-relative rule to a phase;
  nothing is built here.
- **Real scales making planets invisible** and **false precision** (the manual's risks): recorded as rules (separate
  true-relative and visibility-enhanced modes, labelled approximate model and epoch), not solved here.
- **Long timescales and date overflow:** the audit records the existing time pieces; the bounded date range's owner is
  named.
- **Timestamps, time zones and model scope** (the manual's algorithm decision 4): recorded as a rule (the simulated
  date is shown with its time zone, UTC by default, and the clock rate never implies precision beyond the model's
  validity range); its owner is named.
- **Data without a source:** the audit records that every bundled number needs source, epoch, units and license; the
  check's owner is named.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Solar System Explorer work starts.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A14-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A14-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A14-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local) and
  the phase that will build it; at least these MUST be assessed: the body catalog with sourced data; approximate Kepler
  orbit propagation for a simulated date; the simulated clock with play, pause, rate and a bounded date range; true and
  visibility-enhanced scale modes with explicit unit conversion; double-precision, camera-relative positions;
  procedural planet surfaces, rings, the Sun and the starfield; orbit lines and labels; planet focus and camera
  navigation without near-clip surprises; fact cards with units and citations; guided tours with captions; and saved
  view state.
- **FR-A14-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record the
  phase-start commit, the reference pin and the results.
- **FR-A14-005**: The one app MUST build for testing with Solar System Explorer absent; the experience package check
  MUST pass; Solar System Explorer MUST stay unregistered and unavailable (its targets come with A14-P01's first rules).
- **FR-A14-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking or live ephemeris download, no high-precision ephemeris or live sky position claims, no telescope
  alignment, no purchased, generated or hand-made images, textures or artwork, no unlicensed imagery or data, no claim
  that the visibility-enhanced mode is to scale, and no shader deciding body positions), the data and license rule
  (every bundled number and fact records its source, epoch, units and license) and a stop/go decision with reasons.
- **FR-A14-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A14-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A14-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A14-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A14-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A14-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (13 registered experiences, none of them A14).
- **SC-A14-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A14-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides 3D pieces used by earlier experiences — vectors, matrices and quaternions, an orbit camera, mesh
  generators (a UV sphere among them), a mesh renderer with fog and depth, noise, scene clocks, timelines and tour
  timelines, camera rails, origin rebasing and precision advice, gesture recognizers with arbitration, accessibility
  planners, experience storage and quality tiers; the audit confirms each from the code and records what is missing
  (for example Kepler orbit propagation, a scaled simulated date or a body catalog).
- Bodies, facts, tours, copy and the interface are app-local; generic pieces (for example Kepler propagation or a
  scaled-time clock) are assessed for VisualCore ownership.
- Later phases (A14-P01 to A14-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A14-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A14-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A14-005, US3 |
| Review gate: written stop/go decision | FR-A14-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A14-008 |
| Brainstorm capabilities (3D scenes, camera controls, materials and lighting, animation, time-based simulation) | FR-A14-002 |
| Manual non-goals and algorithm decisions 1–4 | FR-A14-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network.
