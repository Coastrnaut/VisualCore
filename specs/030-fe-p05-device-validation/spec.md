# Feature Specification: Fractal Explorer — Phase 05 Device precision and performance validation

**Feature Branch**: `030-fe-p05-device-validation` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A03-P05 · ID namespace FR-A03-5##, SC-A03-5##, T-A03-5##

**Input**: User description: archived manual `apps/03-fractal-explorer.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates:**
  - MVP: still capture and curated guided tours, validated under automation.
  - Regression fixture: saved bookmarks round-trip and reproduce their views within tolerances.
  - EGL/context ownership stays solely in the VisualCore host.
- **No physical-device run before the implementation lock** (CLAUDE.md §1, §8). This phase makes the device precision
  and performance measurements automation-ready, rehearses them on simulators (never device evidence), and writes the
  device-campaign plan for D1, D2 and D3.
- **Reuse:** app-defined automation modes with measurements in the report are generalized into VisualCore automation
  (G-AUTOMODE), so every app can add its own measurement modes.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2), choosing the recommended option each time.
Facts checked in code:
- `AutomationRunner` knows only smoke, launch and lifecycle, applies `postRunCheck`/`checkNote` to those, writes one
  JSON report and exits;
- `AutomationReport` has no measurement fields yet; `AutomationView` owns the one render host;
- the fractal shader receives the center and the step as 32-bit uniforms;
- feature 027 GPU agreement reached 99.9% with boundary-only disagreements on default views.

- Q: Which ladder steps does the precision mode judge, given that deep views near the set's boundary can disagree at a
  few boundary pixels even when precision is fine? → A: The run judges the steps the app calls *reliable*: each must
  agree ≥ 99% with the CPU reference (otherwise the advisor is overconfident on this device). Steps the app calls *near
  the limit* are recorded but not judged (the app already warns "details may blur"). Steps past the clamp are drawn
  only to locate the measured breakdown (first step below 99%), which is recorded. The verdict also fails if the clamp
  step comes after the breakdown step.
- Q: How does a mode registered by the app reach the render host and the report? → A: VisualCore's runner gains
  `appModes: [String: handler]`, where a handler receives the render host and the report (inout) and may set result,
  message, frames, frame-time statistics, `measurements` (name → number) and `details` (name → text). The runner then
  applies the app's domain check and note as for built-in modes. Reports gain the two optional fields.
- Q: How long is a tour run, and is its frame count limited? → A: All three tours at 60 tour steps per second (about
  1,260 frames per tour); `VISUALCORE_AUTORUN_FRAMES` (if given) caps the frames per tour for quick rehearsals. Stills
  are captured at every stop regardless.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Measure the device's real precision limit (Priority: P1) 🎯

The campaign operator launches the app in a measurement mode on a device. The app records what the graphics driver
reports and checks the precision limit the app enforces against what the device actually draws.

**Why this priority**: the phase title; the A03 truthful-precision rule needs device data before any claim.

**Independent Test**: Run the precision mode on a simulator and read the report.

**Acceptance Scenarios**:

1. **Given** a launch with the precision mode, **Then** the report records the reported fragment precision (high and
   medium: bits and range), the render size limit, and a zoom ladder: from the Seahorse Valley point, zoom ×4 per step
   for up to 24 steps, each step drawn at 64 × 64 and compared with the CPU reference (share of agreeing pixels), with
   the app's precision level at that step.
2. **Given** the ladder, **Then** the report names the deepest zoom the app allows (its clamp) and the first zoom at
   which agreement falls below 99% (the measured breakdown). The run passes only if every step the app calls reliable
   agrees ≥ 99% and the clamp comes at or before the breakdown (clarification 1).
3. **Given** a device that reports no usable high precision, **Then** the report says which fallback was used.

---

### User Story 2 - Validate tours and capture under automation (Priority: P1)

The operator runs a tour mode that plays every curated tour at a fixed time step, captures a still at each stop and
records frame times, so tours and capture can be judged on each device.

**Why this priority**: the phase's MVP gate (still capture and curated tours).

**Independent Test**: Run the tour mode on a simulator and read the report.

**Acceptance Scenarios**:

1. **Given** the tour mode, **Then** all three tours are played at 60 steps per second of tour time with a frame drawn
   per step, and the report records frame-time statistics (minimum, median, 95th percentile, maximum; CPU-side, never
   called GPU time) and the frame count.
2. **Given** each tour stop, **Then** a still at 1024 px on the long edge is captured and compared with the CPU
   reference at 64 sample points (≥ 99%); the report records the agreement per stop, and the run fails if any stop
   falls below.
3. **Given** the run, **Then** no capture file remains afterwards.

---

### User Story 3 - Bookmarks reproduce their views (Priority: P1)

A bookmark saved and reopened, on the same or another canvas shape, draws the same picture.

**Why this priority**: the phase's regression fixture.

**Independent Test**: Save bookmarks, reload them in a fresh model, and compare rendered pictures.

**Acceptance Scenarios**:

1. **Given** 10 bookmarks across both modes, palettes and caps, **When** each is reopened on a fresh model with the
   same canvas, **Then** the 64 × 64 rendered picture is identical to the original (every channel within 1 of 255).
2. **Given** the same bookmarks reopened on a canvas of another shape, **Then** the escape classes at 64 sample points
   at the same plane points agree ≥ 99% with the original picture's classes.
3. **Given** the bookmark library on disk, **Then** every saved field survives the reload exactly.

---

### User Story 4 - A device-campaign plan the operator can follow (Priority: P2)

The operator has one page saying what to run on D1, D2 and D3, what each report means and what counts as a pass.

**Why this priority**: device runs happen only after the implementation lock; the plan must exist now.

**Independent Test**: Read the plan and run its simulator rehearsal commands.

**Acceptance Scenarios**:

1. **Given** the plan, **Then** it lists the modes (smoke, launch, lifecycle, precision, tour), the launch variables,
   the report fields, the pass rules, and the per-device rows to fill (D1 iPhone 15 iOS 27.0.1, D2 iPad Pro M5 iPadOS
   27.2, D3 iPad A16 iPadOS 26.5), all marked "pending device campaign".
2. **Given** the shipping Release build, **Then** it contains no automation code or trigger strings.

### Edge Cases

- An unknown automation mode: the report says so with the list of known modes (including app modes) and the run errors.
- A mode name an app registers that VisualCore already defines: the VisualCore mode wins and the app mode is ignored
  (and reported in the message).
- The precision ladder reaches PlaneViewport's finest scale before any breakdown: the measured breakdown is "none
  within the ladder" and the run passes if the clamp was reached.
- The device's render limit below 1024: tour captures use the limit.
- The app in the background during a run: the run continues (it owns the screen while automated).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A03-501**: VisualCore automation MUST let an app register its own modes: a mode name, a handler that runs
  against the one render host and fills the report, and optional numeric measurements and text details in the report
  (new optional report fields, so older reports still decode). App modes go through the same domain check and note
  as built-in modes; unknown modes list every known mode. Tests, docs and a baseline entry (G-AUTOMODE).
- **FR-A03-502**: The app MUST provide the precision mode per US1, with the ladder computed by a pure, host-testable
  routine (steps, clamp step, breakdown step, pass rule).
- **FR-A03-503**: The app MUST provide the tour mode per US2, reusing the curated tours, the tour timeline and the
  still capture.
- **FR-A03-504**: The app MUST pass the bookmark reproduction fixture per US3 on both simulator runtimes.
- **FR-A03-505**: The app MUST route automation launches to its automation root only in `DEBUG` or
  `VISUALCORE_AUTOMATION` builds, triggered solely by the launch environment; the shipping Release build MUST contain
  zero automation symbols and strings (checked).
- **FR-A03-506**: Every mode (smoke, launch, lifecycle, precision, tour) MUST be rehearsed on the iOS 27.2 and 26.5
  simulators with reports kept as rehearsal data, and the device-campaign plan MUST be written (US4).
- **FR-A03-507**: The contract MUST record G-AUTOMODE closed; checks, ProjectM regression 7/7 and the A01 and A02 builds
  MUST pass.

### Negative requirements

- No physical-device install, launch or test in this phase.
- No performance or precision claim from simulator runs; their reports are rehearsal data.
- No automation entry by URL, notification or any remote input.

### Key Entities

- **App automation mode** (VisualCore): name, handler; report measurements (name → number) and details (name → text).
- **Precision ladder** (app): steps (zoom, level, agreement), clamp step, breakdown step, verdict.
- **Tour run** (app): per-stop agreement, frame-time statistics.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A03-501**: Automation tests show an app mode runs, fills measurements, goes through the domain check, and that
  older reports without the new fields still decode.
- **SC-A03-502**: The ladder routine's verdict is right for synthetic ladders (clamp before, at and after the breakdown;
  no breakdown) in 100% of host tests.
- **SC-A03-503**: On both simulator runtimes the precision and tour modes write a "pass" report with all fields
  present (rehearsal only).
- **SC-A03-504**: 10/10 bookmarks reproduce identical pictures on the same canvas and ≥ 99% class agreement on another
  shape, on both runtimes.
- **SC-A03-505**: The shipping Release build has 0 automation symbols; the measurement build has them (the check can
  see them).
- **SC-A03-506**: Fast checks, ProjectM regression 7/7 and A01/A02 builds pass.

## Assumptions

- The CPU reference is exact enough to judge a 32-bit GPU picture (Double precision).
- 64 × 64 ladder pictures and 64 capture sample points are enough to detect a breakdown or a wrong capture.
- Simulator precision is reported by the simulator's driver; it says nothing about devices.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 title — device precision and performance validation | US1, US2, US4, FR-A03-502, FR-A03-503, FR-A03-506 |
| Phase 05 MVP — still capture and curated guided tours | US2, FR-A03-503 |
| Phase 05 regression fixture — bookmarks round-trip and reproduce views | US3, FR-A03-504 |
| CLAUDE.md §9 — AutomationRunner, Release without automation | FR-A03-501, FR-A03-505 |
| Constitution Principle II / owner reuse rule | FR-A03-501 (G-AUTOMODE) |
