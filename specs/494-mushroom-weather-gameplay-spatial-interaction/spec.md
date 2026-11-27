# Feature Specification: R02-G20-04 — Mushroom Weather: gameplay spatial interaction

**Feature Branch**: `494-mushroom-weather-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Draft

**Ledger gate**: R02-G20-04 (migration ledger, game feature of experience R02-G20) · ID namespace FR-R02G2004-###,
SC-R02G2004-###, T-R02G2004-###

**Input**: User description: the archived R02-G20-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Mushroom Weather (controls: "drag spore pods,
open or close canopy vents, shift moonlight intensity"), with the canonical overrides of ADR-0009 and Auto-Creator.md
sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/494-mushroom-weather-gameplay-spatial-interaction`; FR-R02G2004-###,
  SC-R02G2004-###, T-R02G2004-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g20.mushroom-weather` (a registered candidate
  since R02-G20-03) inside the one app; the source's `Apps/MushroomWeather` and `Packages/GameModules` paths are
  superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 76" is a
  milestone figure; the 100 certified levels of R02-G20-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G20-01 … 03.
- **Model:** feature 484 (Microscopic Aurora's gameplay spatial interaction) for the gesture controller, picker, orbit
  and panel, adapted to pods placed on sites, vents and the moonlight.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag spore pods between sites (Priority: P1) 🎯

A player taps an empty site to put a pod there, presses a placed pod and drags it to another site, or drags it off the
floor to take it away; while dragging, the weather the arrangement would give is previewed (mist, caps and gauges).
Lifting the finger commits the change as one action, undoable.

**Why this priority**: the pods are the game's main lever.

**Independent Test**: scripted taps and drags send exactly the placement or removal an independent pick predicts, or
nothing.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player taps an empty site and a slot is free, **Then** exactly one
   placement of a pod on that site in the first free slot is sent.
2. **Given** a placed pod, **When** the player drags it and lifts on another free site, **Then** exactly one placement
   moving that slot's pod to the new site is sent; lifted outside the floor, exactly one removal is sent; lifted on its
   own site, an occupied site or elsewhere on the floor, nothing is sent.

### User Story 2 - Open or close a canopy vent (Priority: P1)

A player taps a vent to open it or shut it; the change is one action, undoable, and the predicted weather follows.

**Why this priority**: vents are the second lever on drying.

**Independent Test**: scripted taps on vents send exactly the vent change an independent pick predicts.

### User Story 3 - Shift the moonlight (Priority: P1)

A player drags up or down on the moon to choose a moonlight level, with the weather previewed while dragging; lifting
commits one change to a different level, or nothing when the level is unchanged.

**Independent Test**: scripted moon drags send exactly the level an independent computation predicts, or nothing.

### User Story 4 - Scrub through the run (Priority: P1)

A player drags sideways along the cycle scrubber below the gauges to move the shown cycle through the predicted run; the
mist, caps and gauges follow and nothing else changes.

**Independent Test**: scripted scrubs show exactly the cycle an independent computation predicts; no kernel action is
sent.

### User Story 5 - Look around the forest and come back (Priority: P1)

A player orbits the forest with two fingers within bounds and returns to the authored view by a double tap off the
floor or "Reset view"; the view never changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, the digest never
changes.

### User Story 6 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (slot, site, place, remove, vent
toggles, moonlight − and +, cycle − and +, run, undo, redo, next level and "Reset view"), including winning every
certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap is below 10 points and lifted within 0.5 s; a press lifted at 0.5 s or
  later without moving does nothing; two taps off the floor within 0.35 s and 22 points reset the view.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A tap on an empty site with every slot used:** nothing is sent; the reason is given in words.
- **Targets under each other** (a pod on its site, a vent over a cell): the target drawn last is picked, as drawn.
- **A change the kernel refuses** (no action left, the stage): sent; the refusal is logged and shown with its reason
  code. A drop or moon drag that changes nothing is never sent.
- **A finished play (won or failed):** gestures send no kernel action (the scrubber still shows cycles) and the
  description says the play is over (undo or next level); orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** a preview clears and nothing is sent.
- **Very small or very wide views:** picking, the scrubber and orbit work at every supported aspect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2004-001**: A tap on an empty site while playing, with a free slot, MUST send exactly one placement of a pod
  in the first free slot; with no free slot it MUST send nothing and say why.
- **FR-R02G2004-002**: A drag that starts on a placed pod while playing MUST preview the weather with the pod moved to
  the site nearest the finger (or removed, off the floor) and, on release on another free site, send exactly one
  placement moving that slot's pod; on release off the floor, exactly one removal; any other release MUST send nothing.
- **FR-R02G2004-003**: A tap on a vent while playing MUST send exactly one change of that vent to its other state.
- **FR-R02G2004-004**: A vertical drag that starts on the moon while playing MUST preview the moonlight level under the
  finger and, on release, send exactly one moonlight change when that level differs from the current one, otherwise
  nothing.
- **FR-R02G2004-005**: A drag along the cycle scrubber MUST show the cycle nearest the finger (presentation only) in any
  stage and MUST send no kernel action.
- **FR-R02G2004-006**: Previews MUST be presentation only: the previewed run (mist, caps and gauges), never entering the
  digest, the snapshot's game state or the kernel.
- **FR-R02G2004-007**: Picking MUST be analytic and deterministic: each pod's, site's, vent's and the moon's projected
  disc and the scrubber's projected band through the drawn camera (orbit included), grown by a fixed margin, the one
  drawn last first; the floor is the projected floor rectangle; anything else is empty space.
- **FR-R02G2004-008**: Two-finger orbit MUST stay within fixed yaw and pitch bounds, keep the scene inside the view with
  a 5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot's game state or the kernel; a double
  tap off the floor or "Reset view" returns to the authored view.
- **FR-R02G2004-009**: Gestures on a finished play, cancelled touches and second fingers MUST send no kernel action.
- **FR-R02G2004-010**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions within its budget.
- **FR-R02G2004-011**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code. Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: its state (idle, site press, pod press, pod drag, vent press, moon press, moon drag, scrubber
  press, scrub drag, floor press, empty press, orbiting, cancelled), the touched target, the start and last points, the
  press time and the last tap's time and place.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Preview**: the pod dragged and the site under the finger (or removal), or the moonlight level under the finger, and
  the previewed run or the reason nothing would change.
- **Gesture action**: place, move, remove, setVent, setMoonlight, showCycle, preview, clearPreview, resetView, explain;
  they map onto the declared adapter controls `pod.place`, `pod.remove`, `vent.set`, `moon.set` and `clock.show`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2004-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and cycles equal an independent computation.
- **SC-R02G2004-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G2004-003**: Orbit and previews never change the digest in every scripted case.
- **SC-R02G2004-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a
  5 % margin.
- **SC-R02G2004-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G2004-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G2004-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G20-05; announcements, haptics, sound and full accessibility
  in R02-G20-06; persistence in R02-G20-07. The snapshot schema stays 1 here (orbit, the shown cycle and the preview are
  not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 484 (and 474) so every round-two game feels the same.
- "Drag spore pods" is read as tapping sites and dragging pods between sites; "open or close canopy vents" as tapping a
  vent; "shift moonlight intensity" as a vertical drag on the moon; running the weather stays the panel's Run (a
  deliberate commitment, never a gesture side effect).
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Drag spore pods | FR-R02G2004-001, 002, 006 |
| Open or close canopy vents | FR-R02G2004-003 |
| Shift moonlight intensity | FR-R02G2004-004, 006 |
| Gesture-to-world actions (analytic picking) | FR-R02G2004-007 |
| Camera behavior (orbit, reset) | FR-R02G2004-008 |
| Undo, accessible panel | FR-R02G2004-009, 010, 011 |
| Reading the run over time | FR-R02G2004-005 |

## Negative Requirements / Excluded scope

- No new kernel action, no saved orbit, cycle or preview, no device run before ImplementationLock-100, no availability
  before X-R02-G20.
