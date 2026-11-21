# Feature Specification: R02-G05-04 — Colorfall Canyons: gameplay spatial interaction

**Feature Branch**: `344-colorfall-canyons-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G05-04 (migration ledger, game feature of experience R02-G05) · ID namespace FR-R02G0504-###,
SC-R02G0504-###, T-R02G0504-###

**Input**: User description: the archived R02-G05-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Colorfall Canyons (controls: "drag short sluice
edits and tap valves; pause/step/undo"), with the canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/344-colorfall-canyons-gameplay-spatial-interaction`; FR-R02G0504-###,
  SC-R02G0504-###, T-R02G0504-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g05.colorfall-canyons` (a registered candidate since
  R02-G05-03) inside the one app; the source's `Apps/ColorfallCanyons` paths are superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock (as before). **Device-only items:**
  touch feel and latency on D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only
  items:** none.
- **Shared features used:** R02-F22 (spatial controls and analytic picking), R02-F26 (input and accessibility
  contract), the experience host's pointer events, and the kernel, adapter and renderer of R02-G05-01 … 03.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag to carve a sluice (Priority: P1) 🎯

A player drags a finger across a canyon cell and that cell is carved one step lower, opening a new channel; the cell
under the finger is highlighted while dragging, and exactly one carve is made when the finger lifts.

**Why this priority**: carving is the game's main move.

**Independent Test**: scripted drags over cells of certified levels produce exactly the carve the independent picking
computation predicts, or none.

**Acceptance Scenarios**:

1. **Given** a playing level, **When** a drag starts on a carvable cell and moves far enough, **Then** exactly one carve
   of that cell is sent on release.
2. **Given** a drag that starts on rock, a spring, a basin, a drain or empty space, **When** it is released, **Then**
   nothing is sent.

### User Story 2 - Tap a spring's valve (Priority: P1)

A player taps a spring and its valve opens or closes.

**Independent Test**: taps on spring emitters send exactly one valve toggle for that spring; taps elsewhere send none.

### User Story 3 - Look around and come back (Priority: P2)

A player orbits the canyon with two fingers within bounds and returns to the authored view with a double tap on empty
space or a "Reset view" button; the view never changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 4 - Every move without gestures (Priority: P1)

A player who cannot drag or tap precisely can do everything through the labelled panel (cell picker and carve, valve
buttons, steps, undo, redo), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A drag that never moves far enough:** a tap; on a spring it toggles the valve, elsewhere nothing.
- **A second finger during a drag:** cancels the drag (nothing sent) and orbits.
- **A cancelled touch:** sends nothing.
- **Not playing (won, failed, paused):** gestures send nothing and show no highlight; orbit still works.
- **A cell hidden behind a taller nearer block:** picking selects the nearest block top hit by the touch ray.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0504-001**: A drag that starts on a carvable cell and moves at least a stated distance MUST send exactly one
  carve of that cell on release; any other drag MUST send nothing.
- **FR-R02G0504-002**: A tap on a spring MUST send exactly one valve toggle of that spring; other taps MUST send nothing
  except a double tap on empty space, which resets the view.
- **FR-R02G0504-003**: Picking MUST be analytic and deterministic: the touch ray through the drawn camera against the
  block tops and emitter columns, the nearest hit winning, with stated minimum touch targets.
- **FR-R02G0504-004**: Two-finger orbit MUST stay within stated yaw and pitch bounds, keep the scene inside the view at
  every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a reset returns to the authored view.
- **FR-R02G0504-005**: While dragging, the picked cell MUST be highlighted and described; nothing changes in the kernel
  until release.
- **FR-R02G0504-006**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G0504-007**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented.

### Key Entities

- **Gesture controller**: state (idle, dragging, orbiting, cancelled), picked cell, start point, last points.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: carve(cell) or valve(spring), at most one per gesture.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0504-001**: For 500 seeded scripted drags and taps on certified levels at several sizes, the actions sent equal
  an independent computation of the touched cell or spring, at most one per gesture.
- **SC-R02G0504-002**: Second fingers, cancels and non-playing stages send nothing in every scripted case.
- **SC-R02G0504-003**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin, and the digest never changes.
- **SC-R02G0504-004**: All 100 certified levels are won through panel actions alone.
- **SC-R02G0504-005**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G0504-006** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G05-05; announcements, haptics and full accessibility in
  R02-G05-06; persistence in R02-G05-07.
- Time stays discrete: the panel's step and run buttons advance it; pausing is the play's stage, as before.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Gesture-to-world actions (drag sluice edits, tap valves) | FR-R02G0504-001, 002, 003 |
| Undo | FR-R02G0504-006 (panel undo and redo) |
| Camera behaviour (constrained orbit, reset, no singularities) | FR-R02G0504-004 |
| Accessible alternative to every gesture | FR-R02G0504-006 |
| Deterministic tests | FR-R02G0504-007; SC-R02G0504-001 … 004 |

## Negative Requirements / Excluded scope

- No free camera navigation, no gestures that change the rules, no hints, sounds or haptics, no device run before
  ImplementationLock-100, no availability before X-R02-G05.
