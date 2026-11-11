# Feature Specification: Fluid Art Playground — Phase 05 Numerical fixtures and device stress tests

**Feature Branch**: `023-fap-p05-fixtures-stress` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A02-P05 · ID namespace FR-A02-5##, SC-A02-5##, T-A02-5##

**Input**: User description: archived manual `apps/02-fluid-art-playground.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- The manual's Phase 05 gates are:
  - MVP-05: pause, reset, deterministic seeded test mode and still capture. Capture already shipped in feature 022.
  - The §11 fixtures 1–5. Fixture 5 is "suspend/resume causes bounded catch-up, not hundreds of solver steps".
  - EGL and context ownership stays solely in the audited VisualCore host.
- Device stress tests are prepared as automation, compiled only under `DEBUG || VISUALCORE_AUTOMATION`, with zero
  automation symbols in the Release build. They are rehearsed on simulators only. Physical-device runs wait for the
  implementation lock (CLAUDE.md §1, §8).
- Reusable pieces, such as a seeded synthetic gesture script, go in VisualCore with tests, docs, the API baseline and
  the ProjectM regression.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing delegation (CLAUDE.md §2), recommended option in each case. Facts
were checked in code: `AutomationRunner` (modes smoke, launch, lifecycle; `renderOneFrame` uses a fixed 1/60 s
delta), `RenderHost.renderFrame` (renders nothing unless active), `FramePacing.clampedDelta` (≤ 0.1 s) and
`TimeStepPolicy.clamp` (1/240…1/30 s; invalid deltas give 1/240 s).

- Q: How does a device stress run detect numerical blow-up, when the automation runner only knows whether frames
  rendered? → A: VisualCoreAutomation gains one generic, app-supplied **post-run check**: an optional closure that
  `AutomationView` passes to `AutomationRunner`. It runs after the mode's frames and returns nil (pass) or a failure
  message. A failure sets the report's result to "fail" with that message. The fluid app's check reads its velocity,
  pressure and dye fields back and checks that every value is finite and in range. It also puts the final picture's
  digest in the report. No app-specific stress mode is added: smoke (frames), launch and lifecycle (pause, resume
  and context recreation) are run with the aggressive seeded script.
- Q: How is the test mode's seed passed, and what is it? → A: A generic launch-environment key in VisualCoreAutomation,
  `VISUALCORE_AUTORUN_SEED` (an unsigned 64-bit integer; missing, 0 or invalid gives 1), read by
  `AutomationRunner.requestedSeed()`. It is only compiled with the rest of the automation code. Determinism is
  claimed for two fresh scenes with the same seed and frame count, on the same runtime and device.
- Q: What exactly does fixture 5 measure? → A: Three parts, all automated:
  1. While the host is paused (backgrounded), it renders no frames, so the step count does not change.
  2. The first frame after resume runs exactly one step.
  3. A frame with any delta (600 s, 0, negative or not finite) runs exactly one step, with a time step in
     1/240…1/30 s. The scene has no catch-up loop, so the step count never rises by more than one per rendered
     frame.
- Q: Is the simulation resolution setting (MVP-06, "configurable simulation resolution with thermal downgrade") in
  this phase? → A: Yes. Thermal downgrade already shipped (feature 021). This phase adds a "Simulation detail" picker
  with square grids: Low 64×64, Medium 128×128 (the default, unchanged from features 019–022) and High 256×256. Each
  is capped by the device's maximum render size. A change rebuilds only the field targets on the next frame and
  restarts from the seed. The stress fixture covers High. (Refined at planning: square grids keep today's default
  picture and need no layout-time rebuild; see research R4.)
- Q: Where does "Reset" restore the dye from? → A: The seeded pattern for the current seed, in the current palette's
  splat colors (as at first open). The velocity and pressure are cleared to zero, written as encoded zero in 8-bit
  storage.

### Session 2026-11-11 (implementation finding, T-A02-508)

- Q: The first stress run failed in half-float storage. Velocity reached 34,688 cells/s (578 cells per step on a
  256² grid), dye reached 89.5 and |pressure| reached 4.9×10⁴, because splats added force and dye without any bound.
  8-bit storage passed only because its encoding clamps. How is this fixed? → A: Splats bound what they add, in every
  storage and in the CPU reference (`Splat.apply`):
  - each velocity component is clamped to ±`velocityRange × 60` cells/s, the range 8-bit storage already imposes;
  - each dye channel is clamped to 0…2 (`Splat.dyeCeiling`), so smoke can still reach near-white and ink
    near-black.

  After the fix: half-float max |v| 382 cells/s, dye 1.97, |p| 2,168; RGBA8 max |v| 341 cells/s. The blow-up
  detectors in FR-A02-507 are unchanged.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Pause, step a frame, resume and reset (Priority: P1)

A person playing with the fluid wants to freeze the motion to look at it, advance one frame at a time, continue, and
start again from a known picture. (Manual journey 3, journey 2 "reset to a known starting state", MVP-05.)

**Why this priority**: These are the MVP-05 controls the manual requires for release. Every later fixture also uses
the same pause, step and reset behavior.

**Independent Test**: Open the playground, tap Pause, tap Step three times, tap Resume, then tap Reset. Check the
frame counter, the canvas, and VoiceOver's announcements at each step.

**Acceptance Scenarios**:

1. **Given** the simulation is running, **When** the person taps Pause, **Then** the fluid stops moving, the Pause
   control changes to Resume, the Step control becomes enabled, and VoiceOver announces "Paused".
2. **Given** the simulation is paused, **When** the person taps Step, **Then** exactly one simulation step runs (the
   step count rises by 1), any queued touches are applied in that step, and the simulation stays paused.
3. **Given** the simulation is paused, **When** the person paints, **Then** the touches are queued and applied on the
   next step or on resume; none are lost.
4. **Given** any state, **When** the person taps Reset, **Then** the velocity becomes zero, the dye returns to the
   seeded starting pattern for the current seed and palette, the touch queue is emptied, and the pause state is
   kept. Tuning values (viscosity, palette, brush) are unchanged.
5. **Given** the simulation is running, **When** Step is shown, **Then** Step is disabled and its accessibility hint
   says to pause first.
6. **Given** any state, **When** the person picks another Simulation detail level, **Then** the canvas restarts from
   the seed at that level's grid, strokes in progress end, and the pause state is kept (FR-A02-511).

---

### User Story 2 — Deterministic seeded test mode (Priority: P1)

A tester, or an automated run, needs the same input to produce the same picture every time, so fixtures and device
stress runs can be compared between runs, devices and builds.

**Why this priority**: It is the MVP-05 "deterministic seeded test mode" and the basis of every device stress run.

**Independent Test**: Run the test mode twice with the same seed and number of frames and compare the final
pictures; then run it with a different seed and check that the picture differs.

**Acceptance Scenarios**:

1. **Given** the test mode with seed S and N frames, **When** it runs twice on the same device and runtime, **Then**
   both final pictures are byte-identical, and their digests are equal.
2. **Given** the test mode with seeds S and S′ (S ≠ S′), **When** both run for N frames, **Then** the final pictures
   differ.
3. **Given** the test mode, **When** it runs, **Then** every step uses a fixed 1/60 s time step, and the scripted
   touches come from a seeded synthetic gesture script instead of the screen.
4. **Given** a shipping Release build, **When** it is inspected, **Then** it contains no test-mode entry point. The
   mode cannot be triggered by a URL or by remote input.

---

### User Story 3 — Numerical fixtures 1–5 as one suite (Priority: P2)

A maintainer needs one named suite that proves the manual's §11 fixtures, so release reviews can point at a single
result.

**Why this priority**: The manual makes these fixtures the Phase 05 regression gate. Fixtures 1–4 exist from earlier
phases. Fixture 5 is new.

**Independent Test**: Run the fixture suite on both simulator runtimes and read its five named results.

**Acceptance Scenarios**:

1. **Fixture 1.** **Given** uniform dye at rest, **When** it is stepped, **Then** it decays only by the configured
   dissipation.
2. **Fixture 2.** **Given** a known dye pattern and zero velocity, **When** it is stepped, **Then** it stays bounded:
   no value grows, and the total stays within the dissipation bound.
3. **Fixture 3.** **Given** each boundary mode, **When** the solver runs, **Then** no sample falls outside the grid,
   and the edge rules hold.
4. **Fixture 4.** **Given** all passes, **When** frames run, **Then** no pass samples its own output.
5. **Fixture 5.** **Given** a running simulation, **When** the app is suspended for a long time (for example 30 s or
   10 minutes) and then resumed, **Then** the first frame after resume runs at most one simulation step, with a time
   step no longer than 1/30 s. The step count rises by at most the number of frames rendered, never by hundreds.

---

### User Story 4 — Stability under stress (Priority: P2)

A person who swipes wildly with many fingers at maximum force and the highest quality must not break the fluid: no
black frames, no "exploding" colors, and the app stays responsive.

**Why this priority**: The manual's risks 2 and 3 are solver cost and touch floods. Stress fixtures protect against
numerical blow-up before device runs.

**Independent Test**: Run the seeded test mode with an aggressive script (10 pointers, maximum force, maximum
iterations) for 600 frames and inspect every field.

**Acceptance Scenarios**:

1. **Given** the aggressive script, **When** 600 frames run in each storage (half-float and 8-bit), **Then** every
   velocity, pressure and dye value read back is finite, and stays within its encoding range.
2. **Given** a touch flood beyond the per-frame cap, **When** frames run, **Then** at most the cap is applied per
   frame and the queue stays within its bound.

---

### User Story 5 — Device stress runs, prepared for the device campaign (Priority: P3)

The device campaign needs ready, repeatable stress runs for D1, D2 and D3 that write a report and exit without a
person.

**Why this priority**: Execution is deferred to the device campaign, but the runs must exist and be rehearsed before
the implementation lock.

**Independent Test**: Launch the app on a simulator with the automation environment for each mode. Check that it
writes a JSON report and exits, and that the Release build contains no automation symbols.

**Acceptance Scenarios**:

1. **Given** a launch with the automation environment set to the smoke, launch or lifecycle mode, **When** the app
   starts, **Then** it runs the fluid scene in the deterministic test mode and writes a report. The report has the
   device model, OS, build, frame count, frame-time statistics and result. Then the app exits.
2. **Given** a Release build, **When** its symbols are listed, **Then** it contains zero automation symbols.
3. **Given** the device campaign is not yet unlocked, **When** these runs are documented, **Then** they are marked
   "automation ready, device run pending implementation lock" and are not claimed as device evidence.

### Edge Cases

- Step pressed while running: no effect (disabled), with the hint.
- Reset during an active swipe: the stroke in progress ends and is dropped. Painting resumes on the next touch.
- Reset while paused: the canvas shows the seeded pattern immediately, and the simulation stays paused.
- Capture while paused, after steps: the capture shows the stepped picture and does not step.
- Suspend while paused: resume keeps it paused, with no catch-up step.
- A non-finite value appearing in a field (should never happen): the next frame detects it in test mode, the run
  reports failure, and the app does not crash.
- Test-mode seed 0 or a missing seed: falls back to the default seed 1.
- A frame count beyond the automation limit: clamped to the runner's maximum.
- A Simulation detail change during a swipe: the active strokes end, the touch queue is emptied (forces were
  converted for the old grid), the pause state is kept and the canvas restarts from the seed.
- A detail level larger than the device allows: capped by the device's maximum render size, as at first open. If
  the new fields cannot be allocated, the previous grid is restored and a message says the level is unavailable.
- Context loss during the test mode: the scene rebuilds from the seed. The report records the loss rather than
  hiding it.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A02-501**: The playground MUST offer Pause/Resume, Step and Reset controls with accessibility labels, values
  and hints. Pause stops simulation steps but keeps displaying. Step is enabled only while paused and runs exactly
  one step.
- **FR-A02-502**: Touches made while paused MUST be queued (within the existing cap and queue bounds) and applied on
  the next step or on resume.
- **FR-A02-503**: Reset MUST zero the velocity and pressure, restore the seeded dye pattern for the current seed and
  palette, empty the touch queue, end any active stroke and keep the pause state and tuning values. It is done
  without rebuilding the renderer.
- **FR-A02-504**: A deterministic seeded test mode MUST run the simulation with a fixed 1/60 s time step and a seeded
  synthetic gesture script. Identical seed and frame count MUST give byte-identical pictures on the same runtime.
- **FR-A02-505**: The seeded synthetic gesture script MUST be a reusable VisualCore component. It generates
  deterministic multi-pointer touch sequences (began, moved, ended) within a view size from a seed, a pointer count, a
  stroke length and a speed. It has tests, public docs, an API-baseline entry and a ProjectM regression run.
- **FR-A02-506**: The fixture suite MUST name and run the §11 fixtures 1–5 on both simulator runtimes. Fixture 5 MUST
  show that a long suspension causes at most one bounded step per rendered frame after resume.
- **FR-A02-507**: A stress fixture MUST run the aggressive script for 600 frames per storage and assert that every
  read-back value is finite and within its encoding range, and that the per-frame splat cap holds. The ranges are blow-up detectors, not physics claims:
  - dye: every channel in 0…4;
  - velocity: |v|·Δt ≤ the grid's longer edge (no cell moves farther than the grid in one step);
  - pressure: |p| ≤ 10⁴.

  In 8-bit storage, the decoded values must also not all sit at the encoding's extremes.
- **FR-A02-508**: The app MUST register the fluid scene with VisualCore's automation runner (smoke, launch and
  lifecycle modes) in the deterministic test mode, with the seed from `VISUALCORE_AUTORUN_SEED` and a post-run field
  check (clarification 1) added to VisualCoreAutomation as a generic, documented hook. This code is compiled only under `DEBUG || VISUALCORE_AUTOMATION`
  and triggered only by the launch environment. In the lifecycle mode, after each context recreation the scene rebuilds
  from the seed, and the post-run check still passes. The Release symbol check MUST report zero automation symbols for the
  app.
- **FR-A02-509**: The app MUST NOT create or own EGL displays, contexts or surfaces. All GPU work goes through the
  VisualCore host, and the isolation check enforces this.
- **FR-A02-511**: The Adjust panel MUST offer a "Simulation detail" picker (Low, Medium, High = 64×64, 128×128,
  256×256 cells, capped by the device's maximum render size). A change rebuilds only the field targets
  on the next frame and restarts from the seed. It is accessible and covered by unit and UI tests (MVP-06).
- **FR-A02-510**: The contract and the device-campaign plan MUST record the automation modes, their report fields,
  and the "device run pending implementation lock" status. The checks MUST pass.

### Key Entities

- **Simulation control state** (app): running or paused, step count, pending step request.
- **Synthetic gesture script** (VisualCore): seed, pointer count, stroke length, speed, view size; produces ordered
  touch events with timestamps.
- **Test-mode run** (app): seed, frame count, final picture digest, result.
- **Fixture result** (tests): fixture number, name, pass or fail with measured values.
- **Automation report** (VisualCore, existing): mode, device, OS, build, frames, frame-time statistics, result.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A02-501**: Pause, Step ×3, Resume and Reset behave as in US1: step count +3 across the three Steps; 0 lost
  touches across a pause; after Reset, the velocity is exactly zero and the dye equals the seeded pattern within one
  storage step. The checks pass in unit and UI tests on both runtimes.
- **SC-A02-502**: Two test-mode runs with the same seed and 120 frames give byte-identical pictures. Runs with two
  different seeds differ in at least 1% of pixels, where a pixel differs if any channel differs.
- **SC-A02-503**: The synthetic gesture script gives identical events for identical inputs, and stays within the view
  bounds for 100 seeds. Each run has began-before-moved-before-ended per pointer and strictly increasing timestamps.
- **SC-A02-504**: Fixtures 1–5 pass on iOS 27.2 and 26.5. Fixture 5 shows at most 1 step for the first frame after a
  simulated 10-minute suspension, with a time step of at most 1/30 s.
- **SC-A02-505**: The stress fixture finds 0 non-finite or out-of-range values over 600 frames in each storage, and
  never more than the cap per frame.
- **SC-A02-507**: Each simulation detail level gives its documented grid (64×64, 128×128, 256×256), and switching
  levels keeps 0 leaked resources over 10 switches.
- **SC-A02-506**: Simulator rehearsal: each automation mode writes a report with result "pass" and exits. The Release
  build has 0 automation symbols. API review, documented-API, isolation, contract, ProjectM regression (7/7) and app
  tests on both runtimes all pass.

## Assumptions

- Capture (MVP-05's fourth item) is complete from feature 022. This phase only checks capture after Step.
- Byte-identical determinism is claimed per runtime and device, not across GPUs. Across devices only the structural
  properties (finite, bounded, the same step count) are compared.
- The automation runner's existing modes (smoke, launch, lifecycle) are used with the aggressive script, plus the
  generic post-run check (clarification 1). No app-specific mode is added.
- The simulation detail picker (MVP-06) is in this phase (clarification 4). Thermal downgrade shipped in feature 021.
- The simulator GPU is assumed deterministic for identical work. If the determinism test shows otherwise, it fails
  and the spec is revisited; tolerances are not loosened silently.
- No persistence is added. Seed and frame count come from the launch environment only in test builds.
- Performance thresholds are not invented. Device frame times are recorded in the device campaign and judged by a
  later acceptance ADR (manual §12).

## Traceability

| Source | Covered by |
|---|---|
| MVP-05 pause, reset, deterministic seeded test mode | FR-A02-501–FR-A02-505, SC-A02-501–SC-A02-503 |
| Manual journey 3 (pause, step a frame, resume, capture) | FR-A02-501, FR-A02-502, US1 |
| Manual journey 2 (reset to a known starting state) | FR-A02-503 |
| Manual §11 fixtures 1–5 | FR-A02-506, SC-A02-504 |
| Manual Phase 05 gate (suspend/resume bounded catch-up) | FR-A02-506 fixture 5 |
| Manual Phase 05 gate (EGL/context only in the VisualCore host) | FR-A02-509 |
| MVP-06 configurable simulation resolution | FR-A02-511 |
| Manual §13 risks 2 and 3 (solver cost, touch floods) | FR-A02-507, SC-A02-505 |
| Manual §11 simulator/device separation, CLAUDE.md §9 automation | FR-A02-508, FR-A02-510, SC-A02-506 |

## Negative Requirements

- No physical-device install, launch or test in this phase. Simulator results are not device evidence.
- No automation code in the Release build, and no URL or remote trigger for the test mode.
- No second renderer, EGL context or ProjectM linkage, no networking, and no new permission.
- Reset never rebuilds the renderer or changes tuning; Step never runs while the simulation is running.
- No invented performance thresholds.
- The test mode stores nothing except the automation report in the app's own Documents folder, and nothing leaves
  the device. The report holds no personal data (model identifier, OS, build, frame statistics, result).
