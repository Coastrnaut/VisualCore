# Feature Specification: R02-G17-04 — Celestial Eclipse Lab: gameplay spatial interaction

**Feature Branch**: `464-celestial-eclipse-lab-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-25

**Status**: Draft

**Ledger gate**: R02-G17-04 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1704-###,
SC-R02G1704-###, T-R02G1704-###

**Input**: User description: the archived R02-G17-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Celestial Eclipse Lab ("Implement native gesture-to-world actions, undo and camera
behavior"; player mechanic "position miniature orbits so sequential eclipses form a target sequence"; controls "drag
orbital handles, rotate time dial, step through predicted eclipse timeline"), with the canonical overrides of ADR-0009
and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/464-celestial-eclipse-lab-gameplay-spatial-interaction`; FR-R02G1704-###,
  SC-R02G1704-###, T-R02G1704-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g17.celestial-eclipse-lab` (a registered candidate
  since R02-G17-03) inside the one app; the source's `Apps/CelestialEclipseLab` and `Packages/GameModules` paths are
  superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 74" is a
  milestone figure; the 100 certified levels of R02-G17-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G17-01 … 03.
- **Model:** feature 454 (Starlit Cartouche's gameplay spatial interaction) for the gesture controller, picker, orbit
  and panel, adapted to miniature planets whose phases are set along their orbital rings.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag a planet along its orbit to set its phase (Priority: P1) 🎯

A player presses a movable planet and drags it along its orbital ring; while dragging, the planet's ghost follows the
nearest orbit position and the predicted timeline below the sky shows what the eclipses would become. Lifting the finger
sets the planet's phase there (one action, undoable).

**Why this priority**: changing a phase is the game's only move; the orbital handle is the natural way to do it.

**Independent Test**: scripted drags send exactly the phase change an independent pick predicts, or nothing.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player drags a movable planet along its ring and lifts at an orbit
   position other than its current one, **Then** exactly one phase change to that position is sent.
2. **Given** a drag that lifts at the planet's current position, off the ring or outside playing, **When** it lifts,
   **Then** nothing is sent and the preview clears.
3. **Given** a fixed planet, **When** the player drags it, **Then** nothing moves and the reason is given in words.

### User Story 2 - Tap a planet to choose it (Priority: P1)

A player taps a planet to make it the chosen planet (its dashed ring) for the panel's phase buttons and the
descriptions.

**Independent Test**: scripted taps choose exactly the planet an independent pick predicts; no kernel action is sent.

### User Story 3 - Rotate the time dial along the timeline (Priority: P1)

A player drags along the timeline below the sky (the time dial) to step the shown tick; the planets move to their
positions at that tick and the crescents and halos show the eclipses under way then. Tapping the timeline jumps to a
tick.

**Why this priority**: seeing when eclipses happen is how the player plans the order.

**Independent Test**: scripted drags along the timeline show exactly the tick an independent computation predicts; no
kernel action is sent.

### User Story 4 - Look around the sky and come back (Priority: P1)

A player orbits the sky with two fingers within bounds to see depth and returns to the authored view; the view never
changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (planet − and +, phase − and +, tick −
and +, run, undo, redo, next level, "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap is below 10 points and lifted within 0.5 s; a press lifted at 0.5 s
  or later without moving does nothing; two taps on empty space within 0.35 s and 22 points reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A planet hidden by a nearer planet:** the front-most planet under the finger is picked, as drawn.
- **A phase change the kernel refuses** (no action left, the stage): sent; the refusal is logged and shown with its
  reason code.
- **A finished play (won or failed):** gestures send no kernel action (taps still choose and the time dial still shows
  ticks) and the description says the play is over (undo or next level); orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** a previewed phase drag clears and nothing is sent.
- **Very small or very wide views:** picking, the time dial and orbit work at every supported aspect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1704-001**: A drag that starts on a movable planet while playing MUST preview the orbit position nearest the
  finger and, on release at a position other than the current one, send exactly one phase change to it; any other
  release MUST send nothing.
- **FR-R02G1704-002**: A tap on a planet MUST choose it (presentation only) in any stage.
- **FR-R02G1704-003**: A drag along the timeline (the time dial) or a tap on it MUST show the tick under the finger
  (presentation only) in any stage and MUST send no kernel action.
- **FR-R02G1704-004**: The phase preview MUST be presentation only: the planet's ghost at the previewed position and
  the predicted timeline of the previewed phases, never entering the digest, the snapshot's game state or the kernel.
- **FR-R02G1704-005**: Picking MUST be analytic and deterministic: each planet's projected disc through the drawn
  camera (orbit included), grown by a fixed margin, the front-most (drawn last) first; the timeline has its own
  projected region; anything else is empty space.
- **FR-R02G1704-006**: Two-finger orbit MUST stay within fixed yaw and pitch bounds, keep the scene inside the view with
  a 5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot's game state or the kernel; a double
  tap on empty space or "Reset view" returns to the authored view.
- **FR-R02G1704-007**: Gestures on a finished play, cancelled touches and second fingers MUST send no kernel action.
- **FR-R02G1704-008**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G1704-009**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through
  the experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with
  their reason code. Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: its state (idle, planet press, planet drag, dial drag, empty press, orbiting, cancelled), the
  touched target, the start and last points, the press time and the last tap's time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Phase preview**: the dragged planet, the previewed offset and the predicted timeline of the previewed phases.
- **Gesture action**: choosePlanet, showTick, setPhase, preview, clearPreview, resetView, explain; setPhase and the
  choices map onto the declared adapter controls `orbit.phase`, `orbit.choose` and `clock.show`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1704-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and choices equal an independent computation.
- **SC-R02G1704-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1704-003**: Orbit and the phase preview never change the digest in every scripted case.
- **SC-R02G1704-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G1704-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1704-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1704-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G17-05; announcements, haptics, sound and full accessibility
  in R02-G17-06; persistence in R02-G17-07. The snapshot schema stays 1 here (orbit, the choice, the shown tick and the
  preview are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 454 (and 444) so every round-two game feels the same.
- "Drag orbital handles" is read as dragging a planet along its own ring; "rotate time dial" and "step through
  predicted eclipse timeline" as dragging or tapping the timeline below the sky (stepping also by the panel's tick − and
  + buttons).
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Drag orbital handles | FR-R02G1704-001, 004 |
| Rotate time dial, step through predicted eclipse timeline | FR-R02G1704-003 |
| Choose a planet | FR-R02G1704-002 |
| Gesture-to-world actions (analytic picking) | FR-R02G1704-005 |
| Camera behavior (orbit, reset) | FR-R02G1704-006 |
| Undo, accessible panel | FR-R02G1704-007, 008, 009 |

## Negative Requirements / Excluded scope

- No new kernel action, no saved orbit, tick or preview, no device run before ImplementationLock-100, no availability
  before X-R02-G17.
