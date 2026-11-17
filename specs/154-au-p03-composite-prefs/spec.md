# Feature Specification: Aurora — Phase 03 Multi-layer compositing and presets

**Feature Branch**: `154-au-p03-composite-prefs` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A21-P03 (legacy ledger) · ID namespace FR-A21-3##, SC-A21-3##, T-A21-3##

**Input**: User description: archived manual `apps/21-aurora.md` §9 Phase 03 `/speckit-specify` prompt (verbatim in
the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: scene transitions and saveable preferences;
  - regression fixture: the sound setting remains independent of the visualization lifecycle;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-COMPOSITE and G-PREFS of `docs/apps/aurora/visualcore-contract.json`.
- **Aurora stays a candidate.** No VisualCore or ProjectM change. Follow `specs/147-zg-p03-stones`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One sky dissolves into the next (Priority: P1) 🎯

When a person chooses another sky, the current picture dissolves into the new one: both skies keep moving, the old
fades out as the new fades in, and nothing in between is brighter than the person's limit.

**Why this priority**: the manual's version 0.1 feature 03 (scene transitions) and risk 2.

**Independent Test**: start a change between two skies; read the picture at many steps of the change.

**Acceptance Scenarios**:

1. **Given** a change between two presets, **When** the picture is read at each step, **Then** it moves steadily from
   the old sky to the new one and no pixel exceeds the limit.
2. **Given** a context loss or a resize during a change, **Then** the change continues with the same picture.

---

### User Story 2 - The sky the person chose is there next time (Priority: P1)

A person's choices (the sky, its colours and motion, the brightness limit, the quality and the sound choice) are kept
and come back the next time the experience opens. A damaged or newer saved choice is reported and replaced by
defaults, and the experience still opens.

**Why this priority**: the manual's version 0.1 feature 03 (saveable preferences) and its third journey.

**Independent Test**: change the choices; close and reopen; open with damaged and newer saved choices.

**Acceptance Scenarios**:

1. **Given** changed choices, **When** the experience is closed and reopened, **Then** every choice is the same.
2. **Given** a damaged or newer saved choice, **When** the experience opens, **Then** it opens with defaults and
   reports why.

---

### User Story 3 - The sound choice outlives the drawing (Priority: P1)

The sound on/off choice and its volume belong to the person, not to the picture. Restarting the drawing, a context
loss, a resize, suspending and resuming never change them.

**Why this priority**: the manual's regression fixture.

**Independent Test**: set the sound choice; rebuild the drawing in every way; read the choice.

**Acceptance Scenarios**:

1. **Given** a sound choice, **When** the drawing is torn down, rebuilt, resized, suspended and resumed, **Then** the
   choice is unchanged.

### Edge Cases

- **A new choice while a change is running:** the running change completes into the newest choice, or restarts from
  the current picture; nothing jumps.
- **Reduce Motion:** the change is immediate.
- **Storage full or unavailable:** the experience runs with the choices in memory and says they could not be saved.
- **A saved choice outside its bounds:** treated as damaged and replaced by defaults.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A21-301**: A change between presets MUST dissolve the old moving sky into the new one over a bounded time,
  with the brightness limit applied to every mixed frame, and MUST be immediate under Reduce Motion.
- **FR-A21-302**: The mix MUST move steadily (monotonically) from old to new, and MUST survive a context loss or
  resize.
- **FR-A21-303**: The person's choices (preset, hue, speed, turbulence, ribbons, stars, clouds, limit, quality, sound
  on/off and volume) MUST be saved in the experience's own storage with a version and restored on open.
- **FR-A21-304**: A damaged, newer or out-of-range saved choice MUST be reported and replaced by defaults, without
  stopping the experience; a failed save MUST be reported and the choices kept in memory.
- **FR-A21-305**: The sound choice MUST be independent of the drawing lifecycle.
- **FR-A21-306**: No sound plays in this phase; the sound choice is stored only (the loop comes in A21-P04 and A21-P05).

### Key Entities

- **Preferences**: version, preset, hue, speed, turbulence, ribbons, stars, clouds, limit, quality, sound on/off,
  volume.
- **Transition**: from picture, to picture, progress, duration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A21-301**: At every sampled step of a change, no pixel exceeds the limit, and the picture's difference from the
  new sky never grows.
- **SC-A21-302**: 100% of choices survive a close and reopen; 100% of damaged and newer samples open with defaults
  and a reason.
- **SC-A21-303**: The sound choice is unchanged after every lifecycle event in 100% of trials.
- **SC-A21-304**: Each unit test runs under 10 seconds.

## Assumptions

- The ambient loop player comes in A21-P04 (VisualCoreAudio) and its control in A21-P05; this phase only keeps the
  choice.

## Traceability

| Source | Requirement |
|---|---|
| MVP: scene transition and saveable preferences | FR-A21-301–304 |
| Regression fixture: sound setting independent of the visualization lifecycle | FR-A21-305, SC-A21-303 |
| Brainstorm: blending and compositing | FR-A21-301, 302 |
| Contract G-COMPOSITE, G-PREFS | FR-A21-301–306 |

## Negative Requirements

- No sound played; no network; no account; no image or recording; no VisualCore change; no availability before X-A21.
