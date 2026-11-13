# Feature Specification: Particle Universe — Phase 05 Profiling and low-end device tuning

**Feature Branch**: `037-pu-p05-profiling-tuning` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A04-P05 (legacy ledger) · ID namespace FR-A04-5##, SC-A04-5##, T-A04-5##

**Input**: User description: archived manual `apps/04-particle-universe.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009, Auto-Creator.md §17.3):** work only in the experience package and the app; the standalone
  sandbox screen and scene model are not extended.
- **Phase gates (manual §9 Phase 05):** MVP pause, reseed and save a scene (delivered by Phases 01 and 04 and re-proved
  here); regression fixture 5: resuming from background never fast-forwards unbounded time; EGL and context ownership
  stays in the host.
- **Devices:** profiling numbers on devices (frame time, thermal behaviour, memory) are device-only and wait for
  ImplementationLock-100 ({device} tasks). Simulator numbers are recorded as simulator signals, never as device evidence.
- **Owner rulings of 2026-11-13:** tests are short; system accessibility audits wait for the device campaign;
  independent files go to parallel agents.
- **Out of scope:** changing VisualCore's quality policy (thermal and Low Power only today); new visual quality options;
  editing the particle limit or time scale; more than one placed force.
- **What exists today (read-only audit of 2026-11-13, `Build/agent-notes/A04-P05-audit.md`, names re-verified):**
  - Time is bounded in three layers: the fixed-step clock runs at most 8 steps per frame and drops the rest; Particle
    Universe's own simulation also runs at most 8 steps per frame; resuming resets the accumulated time; the host clamps
    each frame's time step to 0.1 s. Core tests prove the bound for one long frame and for a paused scene. No test proves,
    through the real session, that frames after a long background gap stay bounded.
  - Quality: four tiers draw all, three quarters, half or a quarter of the particles; the session chooses a tier from
    thermal state and Low Power Mode only; nothing reacts to frame time.
  - A performance record per session exists (quality level, step-downs, thermal state, Low Power, pacing, GPU bytes,
    memory events); Particle Universe has no performance entry in the repository's performance documents.
  - Pause, reseed and save exist; EGL ownership stays in the host.

## Clarifications

### Session 2026-11-13

(Filled by `/speckit-clarify`.)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Coming back never fast-forwards the scene (Priority: P1) 🎯

A person leaves the app with a scene playing and returns minutes later; the scene continues from where it was instead
of racing through the missed time.

**Why this priority**: regression fixture 5 of the phase; an unbounded catch-up freezes the app and changes the scene.

**Independent Test**: through the real session, play a scene, go to the background, let a long time pass, come back and
draw frames; count the simulation steps and compare the state with a bounded replay.

**Acceptance Scenarios**:

1. **Given** a playing scene, **When** the app returns after a 10-minute gap, **Then** the first frame advances at most 8
   simulation steps and the following frames advance at their normal rate.
2. **Given** the same history, **When** it is replayed, **Then** the state digest equals the live one.
3. **Given** a paused scene, **When** the app returns after a gap, **Then** no simulation step is taken until play.

---

### User Story 2 - Slow frames lower the drawn detail (Priority: P1)

On a device that cannot keep up, the experience draws fewer particles so frames stay on time, and draws more again when
it has headroom; the simulation itself is unchanged.

**Why this priority**: the phase's low-end tuning; today detail reacts only to heat and Low Power Mode.

**Independent Test**: feed a frame-time sequence (slow, then fast) to the detail controller and check the requested tier
over time; check that the drawn count follows and the simulation state does not change.

**Acceptance Scenarios**:

1. **Given** frames slower than the frame budget for a sustained window, **When** the window ends, **Then** the drawn
   detail steps down one tier, never more than one tier per window.
2. **Given** frames comfortably within budget for a longer sustained window, **When** it ends, **Then** detail steps up one
   tier, never above the tier allowed by heat and Low Power Mode.
3. **Given** any frame-time sequence, **When** detail changes, **Then** the simulation state digest is identical to a run
   without changes (detail only affects drawing).
4. **Given** a single slow frame (for example after a pause), **When** it occurs, **Then** detail does not change.

---

### User Story 3 - A profile of the experience is recorded (Priority: P2)

The owner gets a record of a scripted Particle Universe run (drawn detail, steps, frame pacing) labelled as a simulator
signal, and an entry in the performance budgets that names the device numbers still to be measured.

**Why this priority**: the phase's "profiling" deliverable; device numbers come later.

**Independent Test**: run the scripted profile on the simulator; check that the record exists, is labelled simulator,
and that the budgets document lists Particle Universe with its device-only measurements pending.

**Acceptance Scenarios**:

1. **Given** the scripted run, **When** it finishes, **Then** a record with quality level, step-downs and pacing exists and
   is labelled "simulator".
2. **Given** the performance documents, **When** they are checked, **Then** Particle Universe has an entry whose device
   values are marked as pending the device campaign.

---

### User Story 4 - The MVP and host gates still hold (Priority: P3)

Pause, reseed and save still work, and the experience still draws only through the host.

**Independent Test**: the existing interface tests and the dependency audit.

**Acceptance Scenarios**:

1. **Given** the Particle Universe interface chunks, **When** they run, **Then** pause, reseed and save pass.
2. **Given** the experience sources, **When** the dependency audit runs, **Then** no EGL call or second renderer exists.

### Edge Cases

- **Thermal or Low Power ceiling:** frame-time step-ups never exceed the tier allowed by heat and Low Power Mode;
  step-downs below it are allowed.
- **Pause and background:** frames while paused or in the background do not count toward the frame-time windows;
  the window restarts on resume.
- **Lowest and highest tier:** step-down at the lowest tier and step-up at the highest do nothing.
- **Noisy frames:** isolated slow frames below the window's threshold share do not change detail.
- **Memory pressure:** the existing session rule (closing on repeated warnings) is unchanged.
- **Cancellation, corrupted or newer data:** not applicable (no persisted state is added).

## Requirements *(mandatory)*

### Functional Requirements

**Bounded resume (story 1)**
- **FR-A04-501**: After a background gap of any length, the first frame MUST advance at most 8 simulation steps and later
  frames MUST advance at the normal rate; a paused scene MUST take no step until play.
- **FR-A04-502**: A replay of a history containing a background gap MUST reach the same state digest.
- **FR-A04-503**: A session-level test MUST prove FR-A04-501 with a gap of at least 10 minutes of clock time.

**Frame-time detail control (story 2)**
- **FR-A04-510**: The experience MUST step its drawn detail down one tier when the share of frames over the frame budget
  in a window exceeds a set threshold, and up one tier after a longer window comfortably within budget.
- **FR-A04-511**: Detail MUST never step above the tier allowed by heat and Low Power Mode, and at most one tier per window.
- **FR-A04-512**: Frames while paused or in the background MUST NOT count; the windows restart on resume.
- **FR-A04-513**: Detail changes MUST affect only the drawn count, never the simulation.
- **FR-A04-514**: The controller MUST be deterministic for a given sequence of frame times and host-testable.

**Profile (story 3)**
- **FR-A04-520**: A scripted simulator run MUST produce a performance record for Particle Universe labelled "simulator".
- **FR-A04-521**: The performance budgets MUST list Particle Universe with its device-only measurements marked pending.

**Gates (story 4)**
- **FR-A04-530**: Pause, reseed and save MUST keep passing their interface tests.
- **FR-A04-531**: The experience MUST keep drawing only through the host (dependency audit).

**Common**
- **FR-A04-540**: No VisualCore change; no standalone-app change; no network.

### Key Entities

- **Frame-time window:** a fixed count of recent frame times and the budget they are compared with.
- **Detail decision:** the requested tier, bounded by the heat/Low Power ceiling.
- **Profile record:** quality level, step-downs and step-ups, pacing, the label "simulator".

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A04-501**: After a 10-minute gap, the first frame takes at most 8 steps in 3 of 3 runs, and the replay digest
  matches.
- **SC-A04-502**: For a scripted frame-time sequence, detail steps down within one window of sustained slow frames,
  steps up only after the longer good window, never exceeds the ceiling and never moves more than one tier per window
  (100% of checks).
- **SC-A04-503**: The simulation digest with detail changes equals the digest without them.
- **SC-A04-504**: The profile record exists and is labelled simulator; the budgets list Particle Universe.
- **SC-A04-505**: The Particle Universe interface chunks and the dependency audit pass.
- **SC-A04-506**: Every new unit test finishes in under 10 seconds.

## Assumptions

- The frame budget is the display's frame interval (1/60 s by default); window sizes and thresholds are fixed in the
  plan and recorded in the evidence.
- Frame times on the simulator are not representative of devices; the controller is tested with injected sequences.
- A04-P04 is pass; X-A04 follows Phase 06.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 deliverable (profiling and low-end tuning) | FR-A04-510–521, US2, US3 |
| MVP: pause, reseed, save a scene | FR-A04-530, US4 |
| Manual §11 fixture 5 (resume does not fast-forward unbounded time) | FR-A04-501–503, US1 |
| Phase gate: EGL ownership in the host | FR-A04-531 |
| Manual §11 physical-device items (thermals, memory, pacing) | {device} tasks, Input |
