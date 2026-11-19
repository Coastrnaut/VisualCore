# Feature Specification: Graphics Benchmark Lab — Phase 02 Three deterministic workload renderers

**Feature Branch**: `174-gbl-p02-workload-renderers` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A24-P02 (legacy ledger) · ID namespace FR-A24-2##, SC-A24-2##, T-A24-2##

**Input**: User description: archived manual `apps/24-graphics-benchmark-lab.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: warm-up, controlled measurement and cool-down phases. Here it is a pure run timeline that places every frame
    of a run in its phase from the case's plan, and a recorder that turns drawn frames into frame samples, driving the
    three workload scenes;
  - regression fixture: an unsupported GPU timer produces null, not fabricated zeros: every recorded sample has no GPU
    time, the summary has no GPU distribution and is flagged "GPU time not available";
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here:** G-SCENES of `docs/apps/graphics-benchmark-lab/visualcore-contract.json`.
- **The experience arrives:** Graphics Benchmark Lab is drawn in the one app for the first time and registered as a
  candidate; it is not yet available to a person (that is X-A24). The synthetic candidate of the app's tests moves to
  `a25.effects-composer`.
- **Not here:** the run's caps, stop rule, CPU submit time and dropped-frame rule, the device report and the renderer
  facts (A24-P03), saving and export (A24-P04).
- **No VisualCore or ProjectM change.** Follow `specs/167-vpl-p02-node-canvas`.
- **No benchmark number** is shown or claimed; results on the simulator are never device evidence.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Three workloads, the same picture every time (Priority: P1) 🎯

A person opens Graphics Benchmark Lab, picks one of the three cases (textured quads, shader ALU stress, particles)
and sees its workload drawn. A workload's picture depends only on the case and the frame number, never on the clock,
so the same frame of the same case looks the same on every run.

**Why this priority**: repeatable scenes are the basis of every comparison.

**Independent Test**: draw frame N of each case off screen twice, in separate hosts, and compare.

**Acceptance Scenarios**:

1. **Given** each case, **When** frame 0 and frame 60 are drawn off screen, **Then** each picture is not blank and
   differs between the two frames.
2. **Given** the same case and frame drawn in two hosts, **When** the pictures are compared, **Then** they are
   byte-identical.
3. **Given** a case outside its caps, **When** it is chosen, **Then** nothing is allocated and the refusal names the
   value.

---

### User Story 2 - A run passes through warm-up, measurement and cool-down (Priority: P1)

A person starts a run. The status shows the phase (warm-up, measuring, cool-down) and then "Finished" with the
summary's percentiles. Frames during warm-up and cool-down are drawn but left out of the summary.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: feed a run's timeline with frame times and read each frame's phase and the finished summary.

**Acceptance Scenarios**:

1. **Given** the plan 3/10/5 s, **When** frames arrive at 0 s, 2.9 s, 3 s, 12.9 s, 13 s, 17.9 s and 18 s,
   **Then** their phases are warm-up, warm-up, measure, measure, cool-down, cool-down and finished.
2. **Given** a finished run, **When** its summary is read, **Then** it counts only the measured frames and names how
   many warm-up and cool-down frames were left out.

---

### User Story 3 - No GPU timer means no GPU number (Priority: P1)

Without a supported GPU timer, every recorded sample has no GPU time, the summary has no GPU line and says "GPU time
not available"; no zero is ever shown as a GPU time.

**Why this priority**: the manual's regression fixture for this phase.

**Independent Test**: record a run on the simulator and read the samples and the summary.

**Acceptance Scenarios**:

1. **Given** a recorded run, **When** its samples are read, **Then** every GPU time is absent (null in the file).
2. **Given** its summary, **When** read, **Then** there is no GPU distribution and the flag "GPU time not available"
   is set, and the status names it.

---

### User Story 4 - The workloads survive interruptions (Priority: P2)

A context rebuild or a resize during a run marks the run interrupted, rebuilds the workload from the case, and leaves
nothing leaked.

**Independent Test**: rebuild the context ten times and resize while drawing; read the registry and the run state.

**Acceptance Scenarios**:

1. **Given** a drawing workload, **When** the context is rebuilt ten times, **Then** the picture of a given frame is
   byte-identical before and after and nothing is leaked.
2. **Given** a running run, **When** the context is rebuilt, **Then** the run ends as interrupted and its samples so
   far are kept.

### Edge Cases

- **A case's texture larger than the device allows:** refused before allocation with the limit named.
- **A particle count at the cap:** drawn within the registry's budget.
- **Choosing another case during a run:** the run stops first (state "stopped"), then the new case is drawn.
- **Leaving the experience during a run:** the run ends as interrupted.
- **The first frame of a run:** has no interval; later frames do.
- **Reduce Motion:** the workloads still draw (they are the measurement); the controls stay readable and static.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A24-201**: The experience MUST draw each of the three built-in cases through VisualCore's public drawing
  building blocks, with a picture that depends only on the case and the frame index.
- **FR-A24-202**: A case MUST be validated before anything is allocated, and its caps (texture size, layers,
  iterations, particles, resolution scale) MUST be checked against the host's limits.
- **FR-A24-203**: A pure run timeline MUST place each frame in warm-up, measurement, cool-down or finished from the
  case's plan and the time since the run started.
- **FR-A24-204**: A recorder MUST turn the drawn frames of a run into frame samples (interval from consecutive frame
  times, absent for the first; no GPU time) and produce the summary when the run finishes.
- **FR-A24-205**: The interface MUST offer the case choice, start and stop, the phase and, after a run, the summary's
  percentiles with their flags, all as native controls with spoken labels, without system menus over the drawing.
- **FR-A24-206**: A context rebuild or resize MUST rebuild the workload from the case, leave nothing leaked, and end a
  running run as interrupted.
- **FR-A24-207**: Graphics Benchmark Lab MUST be registered as a candidate (not available), with a scenario manifest
  the verification runner passes on iOS 27.2.
- **FR-A24-208**: Every public name MUST carry documentation; G-SCENES MUST be closed with evidence.

### Key Entities

- **Run timeline**: plan, start time, phase of a frame time.
- **Recorder**: the samples of the current run and its state.
- **Session state (snapshot)**: the selected case and the last finished run's summary.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A24-201**: 3 of 3 cases draw non-blank pictures that differ between frames 0 and 60, byte-identical across two
  hosts.
- **SC-A24-202**: 100% of the timeline fixtures place their frames in the expected phase.
- **SC-A24-203**: 100% of recorded samples have no GPU time; the summary has no GPU distribution and carries the flag.
- **SC-A24-204**: 10 context rebuilds leave the picture byte-identical with 0 leaked.
- **SC-A24-205**: The verification runner passes every scenario of the manifest on iOS 27.2.
- **SC-A24-206**: Each unit test finishes in under 10 seconds; no test runs a full 18-second plan in real time.

## Assumptions

- A24-P01's cases, samples, statistics and run file are reused unchanged.
- Tests drive the timeline with synthetic frame times; the real frame clock is used only by the presenter.

## Traceability

| Source | Requirement |
|---|---|
| MVP: warm-up, controlled measurement and cool-down phases | FR-A24-203, 204, US2 |
| Regression fixture: unsupported GPU timer produces null, not zeros | FR-A24-204, US3 |
| EGL/context ownership solely in the host | FR-A24-201, 206, US4 |
| Version 0.1 feature 01: repeatable baseline scenes | FR-A24-201, 202, US1 |
| Contract G-SCENES | FR-A24-201–208 |

## Negative Requirements

- No VisualCore or ProjectM change; no GL call of the experience's own; no benchmark number in copy; no clock in the
  workload pictures; no availability to a person before X-A24; no network; no permission.
