# Feature Specification: R02-G04-04 — Hue Compass: gameplay spatial interaction

**Feature Branch**: `334-hue-compass-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G04-04 (migration ledger, game feature of experience R02-G04) · ID namespace FR-R02G0404-###,
SC-R02G0404-###, T-R02G0404-###

**Input**: User description: the archived R02-G04-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement native gesture-to-world actions, undo and camera behavior" for Hue Compass (controls: "swipe to rotate compass,
press to sample a clue, separate high-contrast colorblind symbols"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/334-hue-compass-gameplay-spatial-interaction`; FR-R02G0404-###, SC-R02G0404-###,
  T-R02G0404-###.
- **Packaging (ADR-0009):** experience R02-G04 (`r02-g04.hue-compass`, free, a registered candidate since R02-G04-03) in
  `Packages/ExperiencesRound02/HueCompass`; this feature extends its Core and experience target.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and per-round device campaign
  (ImplementationLock-100). **Device-only items:** touch feel and gesture latency on D1/D2/D3, `{device}` tasks after
  ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F22 (spatial interaction: gesture arbitration, assistive steps) through the existing
  VisualCore packages; the adapter and scene of R02-G04-03.
- **Model:** feature 324 (Wave Knot Keeper's gameplay spatial interaction).

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only, 2026-11-21): Wave Knot Keeper's feature 324 solved the same problem with a host-tested
`WaveKnotKeeperGestureController` taking `PointerEvent`s with the view size and the drawn snapshot (idle, dragging,
orbiting, cancelled; at most one action per gesture) and an orbit in its scene geometry; Hue Compass's camera
(`HueCompassSceneGeometry.camera(aspect:)`) looks down −z tilted 35° about x, fitting a 1.45 bounding sphere for aspects
0.4 … 2.5; its panel already has turn −4, −1, +1, +4, Probe, a band picker, Select, Undo, Redo and Next level; its adapter
accepts `compass.turn [steps]`, `compass.probe` and `compass.select [bearing, band]`.

- Q: How does a swipe become a turn? → A: the angle is measured about the projected compass centre (the origin through
  the drawn camera), counter-clockwise on screen being counter-clockwise on the compass (screen y points down, so angle =
  atan2(−dy, dx)); the swipe accumulates the angle change between successive touch points, ignoring points within 20
  points of the centre (where the angle is unstable); the preview is the start bearing plus round(accumulated angle ×
  96 / 2π) bearings; on release one `compass.turn [steps]` is sent with steps wrapped into −47 … 48, nothing when 0.
  Impact: FR-R02G0404-001; SC-R02G0404-001.
- Q: How are touches arbitrated, and where is the hub? → A: a Core `HueCompassGestureController` with idle, swiping,
  orbiting and cancelled states; a touch that ends within 10 points of where it began is a tap; a tap within the hub —
  the projected disc of radius 0.3 world units about the centre, never smaller than 30 points — sends exactly one
  `compass.probe`; a double tap (two taps within 0.35 s) outside the projected wheel (radius 1.0) resets the view; any
  other tap sends nothing; a second finger cancels a swipe and orbits; a cancelled gesture sends nothing; while not
  playing nothing is sent and no preview is shown. Impact: FR-R02G0404-002, 003; SC-R02G0404-002.
- Q: What can the camera do? → A: two-finger orbit of yaw (±40° about the z axis, 90° per view width) and pitch (the tilt
  from the z axis between 15° and 60°, authored 35°, 60° per view height); a double tap on empty space or "Reset view"
  returns to the authored view; the distance refits so the 1.45 bounding sphere stays inside the view with a 5 % margin
  at every orbit and aspect 0.4 … 2.5. Presentation only: never in the digest, the snapshot or the kernel; not saved.
  Impact: FR-R02G0404-004; SC-R02G0404-003.
- Q: How is a swipe previewed, and what does the panel need? → A: while swiping, a ghost needle (pearl at half opacity)
  points at the preview bearing and the description reads "Turning to bearing n of 96"; the real needle stays until the
  turn is accepted. The panel keeps its controls and gains "Reset view"; every certified witness is replayable through
  the panel, a turn of k bearings becoming ⌊|k|/4⌋ presses of ±4 and |k| mod 4 presses of ±1. Impact: FR-R02G0404-005;
  SC-R02G0404-004.
- Q: How are gestures tested without a screen? → A: the Core gesture controller takes pointer events with the view size
  and the drawn camera and returns at most one action per gesture plus the preview; tests feed scripted swipes (seeded
  start angles, sweeps up to ±1.5 turns, radii and point counts), taps inside and outside the hub, second fingers,
  cancels and non-playing stages at fixed sizes, and compare with the turn computed independently from the angles;
  simulator tests send the same touches through the experience's pointer entry; a host test wins all 100 levels through
  panel actions. Impact: FR-R02G0404-006; SC-R02G0404-001, 002, 004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Swipe to turn the compass (Priority: P1) 🎯

A player swipes around the compass and the needle follows the finger's angle, previewing the bearing it will settle on;
on release exactly one turn is made (or none, if the swipe did not move it a whole bearing).

**Why this priority**: turning the compass is how every clue and selection is aimed.

**Independent Test**: scripted swipes at fixed view sizes end in exactly the turn their angles imply, computed
independently.

**Acceptance Scenarios**:

1. **Given** a playing level, **When** a finger swipes around the compass by an angle and lifts, **Then** exactly one
   `compass.turn` of the nearest whole number of bearings (wrapped to −47 … 48) is sent, or nothing when it is 0.
2. **Given** a swipe through the compass centre, **When** it moves, **Then** the turn follows the angle about the centre
   and never jumps by more than the finger moved.

### User Story 2 - Press to sample a clue (Priority: P1)

A press on the compass hub samples the clue at the current bearing.

**Independent Test**: a tap within the hub sends exactly one `compass.probe`; a tap elsewhere sends nothing.

### User Story 3 - Look around without changing the puzzle (Priority: P1)

Two fingers orbit the camera to see the fog's depth; a double tap on empty space or "Reset view" returns to the authored
view. The puzzle never changes.

**Independent Test**: orbiting to every limit and resetting changes no digest; the compass stays inside the view.

### User Story 4 - Play with the panel alone (Priority: P1)

A player who cannot swipe turns with the panel's labelled turn buttons, probes with its Probe button and selects with its
band picker and Select; every level can be won this way.

**Independent Test**: all 100 certified levels are won through the panel's actions alone with their witness actions.

### Edge Cases

- **Second finger during a swipe:** the swipe is cancelled (nothing sent) and the gesture becomes an orbit.
- **A press that moves:** beyond the tap distance it is a swipe, not a probe.
- **A swipe through or ending in the centre:** points within the 20-point dead zone add no angle; the angle gathered
  before stands, and the turn is sent at release as usual.
- **Stage not playing (won, failed, paused):** swipes and presses send nothing.
- **A swipe that winds more than half a turn:** the turn is the net angle, wrapped to −47 … 48 bearings.
- **Orbit limits and every aspect 0.4 … 2.5:** the compass stays inside the view with a 5 % margin.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0404-001**: A one-finger swipe MUST turn the previewed needle by the finger's angle about the projected compass
  centre and, on release, send at most one `compass.turn` of the nearest whole number of bearings.
- **FR-R02G0404-002**: A tap within the projected hub MUST send exactly one `compass.probe`; elsewhere nothing.
- **FR-R02G0404-003**: Gestures MUST be arbitrated: one finger swipes or taps; two fingers orbit; a second finger cancels a
  swipe; a cancelled gesture sends nothing; nothing is sent while not playing.
- **FR-R02G0404-004**: The camera MUST orbit within stated limits, reset on request and never change the kernel's state,
  digest or snapshot; the compass MUST stay inside the view at every orbit and aspect.
- **FR-R02G0404-005**: The panel MUST make every level winnable without gestures, and undo, redo and "Reset view" MUST be
  reachable from it.
- **FR-R02G0404-006**: Gesture logic MUST be deterministic and testable without a screen.
- **FR-R02G0404-007**: Existing tests MUST pass; every new public name is documented; the reference regression passes.

### Key Entities

- **Gesture**: idle, swiping (start angle, preview steps), orbiting, cancelled; a tap.
- **Orbit**: yaw and pitch offsets from the authored view, presentation only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0404-001**: For 500 seeded scripted swipes, each gesture ends in exactly the turn its angles imply
  (independently computed), or none.
- **SC-R02G0404-002**: Every arbitration case (second finger, cancel, tap inside and outside the hub, not playing) sends
  nothing or the stated action, and is tested.
- **SC-R02G0404-003**: Orbiting to every limit and resetting changes no digest; the compass stays inside the view with a
  5 % margin at every orbit limit and at 7 aspects.
- **SC-R02G0404-004**: All 100 certified levels are won through the panel's actions alone.
- **SC-R02G0404-005**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G0404-006** {device}: after ImplementationLock-100, touch feel and gesture latency are checked on D1/D2/D3.

## Assumptions

- Selection stays in the panel (band picker and Select): the design names only swipe and press as gestures, and an
  accessible stepper serves every essential state change.
- Hints and progression are R02-G04-05; announcements and haptics R02-G04-06.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Gesture-to-world actions (swipe to rotate, press to sample) | FR-R02G0404-001, 002, 003 |
| Undo | FR-R02G0404-005 |
| Camera behaviour (constrained orbit, reset) | FR-R02G0404-004 |
| Accessible stepper controls for all essential changes | FR-R02G0404-005 |
| Deterministic tests | FR-R02G0404-006; SC-R02G0404-001, 002 |

## Negative Requirements / Excluded scope

- No free camera navigation, no gesture that selects, no device run before ImplementationLock-100, no change to the rules.
