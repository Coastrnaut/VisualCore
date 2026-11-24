# Feature Specification: R02-G14-04 — Moonlit Mechanism: gameplay spatial interaction

**Feature Branch**: `434-moonlit-mechanism-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G14-04 (migration ledger, game feature of experience R02-G14) · ID namespace FR-R02G1404-###,
SC-R02G1404-###, T-R02G1404-###

**Input**: User description: the archived R02-G14-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Moonlit Mechanism ("Implement native gesture-to-world actions, undo and camera
behavior"; player mechanic "rotate a clockwork machine until its combined moving shadows spell symbols"), with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/434-moonlit-mechanism-gameplay-spatial-interaction`; FR-R02G1404-###,
  SC-R02G1404-###, T-R02G1404-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g14.moonlit-mechanism` (a registered candidate
  since R02-G14-03) inside the one app; the source's `Apps/MoonlitMechanism` and `Packages/GameModules` paths are
  superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 77" is a
  milestone figure; the 100 certified levels of R02-G14-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G14-01 … 03.
- **Model:** feature 424 (Acoustic Constellator's gameplay spatial interaction) for the gesture controller, picker, orbit
  and panel, adapted to the clockwork.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
424's answers where the games agree. Facts checked in code (read-only, 2026-11-24): the host's `PointerEvent` (id,
phase began/moved/ended/cancelled, location in view points with the origin top-left, timestamp); feature 424's
thresholds (tap below 10 points and 0.5 s, drag from 16 points, double tap within 0.35 s and 22 points, orbit 90° per
view width and 60° per view height). Moonlit Mechanism's adapter declares `handle.turn` [±1], `gear.reseat` [gear, ±1],
`lamp.step` [±1], `machine.run`, `play.undo`, `play.redo`, `level.next` and `frame.show` [key frame]; the kernel refuses
a re-seat of gear 0 (the driver, code `action.driver`) and a lamp step out of range (`action.lamp`); one handle turn
moves every gear by one of its own teeth, gear i in the sense `MoonlitMechanismTrain.direction` gives (clockwise on
screen for +1); spending the last action of the budget without a win fails the level. The camera
(`MoonlitMechanismSceneGeometry`) looks from eye (0, 0.65, 2.4) towards (0, 0.55, −0.3) at the box x −0.95 … 0.95,
y −0.45 … 1.5, z −0.6 … 0.4; a gear's outline radius is 3.4 s plus a tooth of 0.35 s; gears are drawn back to front by
depth, then index; key-frame cards are 0.16 × 0.07 at most at y −0.18; the lamp is a disc of radius 0.06 at
(0, 1.30 + 0.03 · height, 0.35) with its ladder at x 0.12 — one rung is about 10 points on a phone, too small to drag
rung by rung.

- Q: How is a touch picked? → A: at touch-down every target is projected through the drawn camera (orbit included) into
  view points. In this order: the lamp (its centre within 22 points) or the ladder (within 22 points of the segment from
  its bottom rung to its top rung); then a key-frame card (inside its projected rectangle, or its centre within 22
  points; the nearest centre first, ties to the lower index); then a gear (inside its projected outline circle of radius
  3.75 s grown by 8 points; the front-most first — the one drawn last: higher depth, then higher index); anything else
  (the wall, the pips, the moves bars) is empty space. Tap, drag and double-tap thresholds are feature 424's. Impact:
  FR-R02G1404-001 … 005; SC-R02G1404-001.
- Q: How does a gear drag turn the train? → A: the swept angle is accumulated from the finger's angle about the gear's
  projected centre, measured clockwise on screen, skipping samples within 12 points of the centre. n = round(swept ÷
  (360° ÷ T)) for the gear's tooth count T; the handle step is s = direction(gear) × sign(n), so the dragged gear turns
  the way the finger went; |n| is capped at the actions left. While dragging, the pending turn (n teeth, |n| actions) is
  shown in the description and the panel; the gears are not redrawn until release. On release while playing, |n| turns
  of step s are sent one by one (each its own undo step); n = 0 sends nothing. A drag that starts on a gear in any stage
  other than playing previews nothing and sends nothing. Impact: FR-R02G1404-001; SC-R02G1404-001.
- Q: How does the lamp respond? → A: a vertical drag that starts on the lamp or the ladder counts one rung per 24 points
  of finger travel (upward positive, rounded to the nearest rung, a fixed screen distance because a projected rung is
  too small), shows the pending steps, and on release while playing sends that many `lamp.step` actions; steps past the
  ends are sent and refused with `action.lamp`, so the lamp stops at its end. A tap on the lamp (not the ladder) while
  playing sends `machine.run`. Impact: FR-R02G1404-002, 004; SC-R02G1404-001.
- Q: What do taps and double taps do? → A: a tap on a gear chooses it as the panel's gear (any stage, no action). A
  second tap on the same gear within 0.35 s and 22 points while playing sends `gear.reseat [gear, +1]`, except on the
  driver (gear 0), which sends nothing and the description says the driver cannot be re-seated. A tap on a key-frame
  card sends `frame.show [k]` in any stage (presentation only, never an undo step of the play). A tap on empty space
  changes nothing; two such taps within 0.35 s and 22 points reset the view. On a won or failed play no kernel action is
  sent (gear taps choose, card taps show, orbit works) and the description says the play is over (undo or next level).
  Impact: FR-R02G1404-003, 004; SC-R02G1404-002.
- Q: How do two fingers behave and how is it tested? → A: as feature 424: a second finger cancels any one-finger gesture
  (nothing sent) and orbits — yaw ±25° about the y axis (90° per view width) and pitch −10° … +15° (60° per view
  height) about the authored view, narrower than 424's because the wall faces the camera; a third finger re-bases the
  midpoint; a double tap on empty space or "Reset view" returns to the authored view; the camera refits so the authored
  box stays inside the view with a 5 % margin at every orbit and aspect 0.4 … 2.5. Orbit is not saved (schema stays 1).
  A Core gesture controller (`MoonlitMechanismGestureController`) with a picker (`MoonlitMechanismPicker`) takes pointer
  events with the view size, the drawn snapshot, the orbit and the chosen gear and returns gesture actions
  (chooseGear, pendingTurn, turn, pendingLamp, lampStep, reseat, showFrame, run, resetView) and the orbit; host tests
  feed 500 seeded taps and drags on certified levels at several sizes and orbits against an independent pick in the
  test; simulator tests send touches through the experience's pointer entry; a host test wins all 100 certified levels
  through panel actions alone. Impact: FR-R02G1404-005 … 008; SC-R02G1404-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Turn the machine by dragging a gear (Priority: P1) 🎯

A player puts a finger on any gear and drags it around the gear's centre: the gear's pending turn in whole teeth is
shown while dragging, and on release the train turns by that many teeth, one handle turn (one action) per tooth, in the
sense that makes the dragged gear follow the finger.

**Why this priority**: turning the train is the game's main move; the shadows move only when the gears turn.

**Independent Test**: scripted rotary drags send exactly the number and sign of handle turns an independent computation
predicts from the swept angle, the gear's tooth count and its direction in the train.

**Acceptance Scenarios**:

1. **Given** a level while playing, **When** the player drags a gear through two teeth' worth of angle in its turning
   sense and lifts, **Then** exactly two handle turns of the sign that turns that gear that way are sent.
2. **Given** a drag that sweeps less than half a tooth, **When** it lifts, **Then** nothing is sent.
3. **Given** a drag on a gear whose train direction is −1, **When** the finger sweeps clockwise, **Then** the handle
   turns sent have the opposite sign to the same sweep on a direction +1 gear.

### User Story 2 - Raise and lower the lamp (Priority: P1)

A player drags the lamp or its height ladder up or down: each rung passed is one lamp step (one action) on release,
and the shadows slide as the kernel casts them.

**Why this priority**: the lamp height is the second set-up a level asks for.

**Independent Test**: scripted vertical drags on the lamp and ladder send exactly the lamp steps an independent
computation predicts.

**Acceptance Scenarios**:

1. **Given** the lamp at height 1 of 4 while playing, **When** the player drags it up past two rungs and lifts, **Then**
   exactly two lamp steps of +1 are sent.
2. **Given** a drag past the top rung, **When** it lifts, **Then** the steps beyond the range are sent and refused with
   their reason code, and the lamp stays at the top.

### User Story 3 - Choose a gear, re-seat it and show a key frame (Priority: P1)

A player taps a gear to choose it in the panel; double-taps a gear to re-seat it one blade slot forward (one action); and
taps a key-frame card to show that key frame's shadows (no action).

**Why this priority**: re-seating and reading each key frame are how a player solves levels with several frames.

**Independent Test**: scripted taps and double taps choose, re-seat and show exactly what an independent pick predicts.

**Acceptance Scenarios**:

1. **Given** any stage, **When** the player taps a gear, **Then** it becomes the panel's chosen gear and nothing is sent.
2. **Given** a level while playing, **When** the player double-taps a gear, **Then** exactly one re-seat of that gear by
   +1 is sent.
3. **Given** any stage, **When** the player taps a key-frame card, **Then** that key frame is shown and the play is
   unchanged.

### User Story 4 - Run the machine by touching the lamp (Priority: P1)

A player taps the lamp to run the machine through every key frame; the verdict is decided.

**Why this priority**: running is how a level is won or lost.

**Independent Test**: scripted taps on the lamp send exactly one run.

### User Story 5 - Look around and come back (Priority: P2)

A player orbits the clockwork with two fingers within bounds and returns to the authored view; the view never changes
the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 6 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (turn − and +, gear − and +, re-seat −
and +, lamp − and +, key frame − and +, run, undo, redo, next level, "Reset view"), including winning every certified
level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap (below 10 points, lifted within 0.5 s); two taps on empty space within
  0.35 s and 22 points reset the view; two taps on the same gear within 0.35 s and 22 points re-seat it (the first tap
  chose it); a press lifted at 0.5 s or later without moving does nothing.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A gear drag through the gear's centre** (the finger within 12 points of the projected centre): the angle is not
  updated there, so the sweep never jumps.
- **A turn, re-seat, lamp step or run the kernel refuses** (the budget, the lamp range, the stage): sent and refused
  with its reason code, which the presenter logs and shows.
- **A finished play (won or failed):** gestures send no kernel action (a gear tap only chooses the gear, a card tap
  still shows its key frame) and the description says the play is over (undo or next level); orbit still works.
- **A double tap on the driver (gear 0):** sends nothing; the description says the driver cannot be re-seated.
- **A gear drag longer than the actions left:** the turns are capped at the actions left.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing.
- **Overlapping targets near a touch:** the lamp and ladder first, then a key-frame card, then the front-most gear
  (drawn last), each within its touch target.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1404-001**: A drag that starts on a gear while playing MUST show the pending turn in whole teeth and, on
  release, MUST send |n| handle turns of step s through the declared turn control, where n is the clockwise swept angle
  divided by one tooth's angle (360° ÷ T), rounded, capped at the actions left, and s = direction(gear) × sign(n); it
  MUST send nothing when n is 0.
- **FR-R02G1404-002**: A vertical drag that starts on the lamp or the ladder while playing MUST send one lamp step per
  24 points of finger travel (rounded to the nearest rung) on release, upward positive, through the declared lamp
  control.
- **FR-R02G1404-003**: A tap on a gear MUST choose it as the panel's gear (no action); a double tap on a gear while
  playing MUST send exactly one re-seat of that gear by +1 through the declared re-seat control, except on the driver,
  where it sends nothing and says why.
- **FR-R02G1404-004**: A tap on a key-frame card MUST show that key frame through the declared frame control in any
  stage, leaving the play unchanged; a tap on the lamp while playing MUST send exactly one run.
- **FR-R02G1404-005**: Picking MUST be analytic and deterministic: the lamp and ladder, the key-frame cards and the gear
  discs projected through the drawn camera (orbit included), each with a stated touch target, in that order.
- **FR-R02G1404-006**: Two-finger orbit MUST stay within stated bounds, keep the scene inside the view with a 5 % margin
  at every aspect 0.4 … 2.5 and never enter the digest, the snapshot or the kernel; a double tap on empty space or
  "Reset view" returns to the authored view.
- **FR-R02G1404-007**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G1404-008**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through the
  experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with their
  reason code (observability). Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: state (idle, gear press, gear drag, lamp press, lamp drag, card press, empty press, orbiting,
  cancelled), the touched gear, card or lamp, the start and last points, the swept angle, the press time, the last tap
  time, place and target.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Gesture action**: chooseGear, pendingTurn, turn, pendingLamp, lampStep, reseat, showFrame, run, resetView; turn,
  lampStep, reseat, showFrame and run map onto declared adapter controls.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1404-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and choices equal an independent computation.
- **SC-R02G1404-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1404-003**: Orbit never changes the digest in every scripted case.
- **SC-R02G1404-004**: At every orbit within bounds and every aspect 0.4 … 2.5 the scene stays inside the view with a 5 %
  margin.
- **SC-R02G1404-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1404-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1404-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G14-05; announcements, haptics, sound and full accessibility
  in R02-G14-06; persistence in R02-G14-07. The snapshot schema stays 1 here (orbit, the chosen gear and the pending turn
  are not saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added. A
  backward re-seat stays a panel action.
- A two-finger twist was considered for re-seating but two fingers orbit (as in feature 424), so re-seating is a double
  tap on a gear and the panel.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Rotate a clockwork machine (gesture-to-world turn) | FR-R02G1404-001 |
| Light matrix (lamp height) | FR-R02G1404-002 |
| Gear phase constraints (re-seat), key frames | FR-R02G1404-003, 004 |
| Gesture-to-world actions (analytic picking) | FR-R02G1404-005 |
| Camera behavior (orbit, reset) | FR-R02G1404-006 |
| Undo | FR-R02G1404-007, 008 |
