# Feature Specification: R02-G16-04 — Starlit Cartouche: gameplay spatial interaction

**Feature Branch**: `454-starlit-cartouche-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-24

**Status**: Clarified

**Ledger gate**: R02-G16-04 (migration ledger, game feature of experience R02-G16) · ID namespace FR-R02G1604-###,
SC-R02G1604-###, T-R02G1604-###

**Input**: User description: the archived R02-G16-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Gameplay spatial interaction" for Starlit Cartouche ("Implement native gesture-to-world actions, undo and camera
behavior"; player mechanic "connect a moving starship route into a prescribed ancient symbol"; controls "tap route nodes
to queue legs, drag time slider, preview gliding 3D route"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/454-starlit-cartouche-gameplay-spatial-interaction`; FR-R02G1604-###,
  SC-R02G1604-###, T-R02G1604-###.
- **Packaging (ADR-0009):** the gestures live in the experience `r02-g16.starlit-cartouche` (a registered candidate
  since R02-G16-03) inside the one app; the source's `Apps/StarlitCartouche` and `Packages/GameModules` paths are
  superseded.
- **Superseded parts of the source prompt:** price, "no IAP" and the Round 2 lock. The source's "content count 80" is a
  milestone figure; the 100 certified levels of R02-G16-02 stand. **Device-only items:** touch feel and latency on
  D1/D2/D3, recorded as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F14 (reversible history), R02-F22 (spatial controls and analytic picking), R02-F26
  (input and accessibility contract), the experience host's pointer events, and the kernel, content, adapter and
  renderer of R02-G16-01 … 03.
- **Model:** feature 444 (Voxel Origami's gameplay spatial interaction) for the gesture controller, picker, orbit and
  panel, adapted to a starship flying corridors between moving stars.

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
444's answers where the games agree. Facts checked in code (read-only, 2026-11-24): the host's `PointerEvent` (id,
phase began/moved/ended/cancelled, location in view points with the origin top-left, timestamp); feature 444's
thresholds (`VoxelOrigamiGestureController`: tap below 10 points and 0.5 s, drag from 16 points, double tap within
0.35 s and 22 points, orbit 90° per view width and 60° per view height, yaw ±60°, pitch −20° … +35°). Starlit
Cartouche's adapter declares `route.fly` [star, wait], `play.undo`, `play.redo`, `level.next` and `route.choose` [star,
wait] (presentation only; the choice resets after every leg to the other end of the lowest-index corridor from the
ship's star with wait 0). The scene (`StarlitCartoucheSceneGeometry`) draws stars of radius 0.07 with notched rings out
to 0.098 at w(position(at: beat)) from eye (1.2, 1.0, 2.8) towards (0, −0.2, 0), fitted to the box x −0.95 … 0.95,
y −1.45 … 0.95, z −0.95 … 0.95, the ship at its star and nine wait pips at y −1.35 from x 0.0 to 0.9.

- Q: How is a touch picked? → A: at touch-down every star is projected through the drawn camera (orbit and launch
  preview included) into view points; a star is hit when the touch lies within its projected ring radius (0.098) grown
  by 8 points; of several hits the front-most wins (the one drawn last in the paint order). A hit on the ship's star is
  a press on the ship. The time slider is the bounding box of the nine projected wait pips grown by 8 points. Anything
  else (corridors, trails, hazards, the cartouche, bars, track, firmament) is empty space. Tap, drag and double-tap
  thresholds are feature 444's. Impact: FR-R02G1604-005; SC-R02G1604-001.
- Q: What do taps and double taps do? → A: a tap on a star other than the ship's sends `route.choose [star, wait]` (the
  chosen wait kept) in any stage; a second tap on the same star within 0.35 s and 22 points while playing sends
  `route.fly [star, wait]` (the kernel decides: a refusal is logged and shown, a failure ends the level). A tap on the
  ship's star changes nothing; a tap on the slider chooses the wait of its nearest pip; a tap on empty space changes
  nothing and two such taps within 0.35 s and 22 points reset the view. On a won or failed play no kernel action is
  sent (taps and the slider still choose) and the description says the play is over (undo or next level). Impact:
  FR-R02G1604-001, 007; SC-R02G1604-002.
- Q: How do the slider and the launch preview work? → A: from touch-down on the slider, the wait is the index of the pip
  whose projected centre is nearest to the finger's projection onto the screen line through pips 0 and 8, clamped to
  0 … 8; every change sends `route.choose [destination, wait]` (never an undo step, never a kernel action). The launch
  beat is L = beat + chosen wait. The scene draws every star (and the ship at its star) at w(position(at: L)) instead of
  the current beat — at wait 0 the picture is R02-G16-03's — and, while playing and when a corridor joins the ship's
  star and the destination, the previewed leg: a dashed sapphire ribbon 0.03 wide from the ship's star at L to the
  destination at L + travel. Trails stay at the positions where they were flown; the cartouche and gauges are unchanged.
  The preview is presentation only (the snapshot gains the launch beat and the launch positions; neither enters the
  digest). Impact: FR-R02G1604-002, 003; SC-R02G1604-003, 004.
- Q: How does a drag from the ship fly a leg, and how do two fingers behave? → A: a press on the ship that moves 16
  points or more while playing becomes a ship drag: the star under the finger (picked as above, not the ship's) becomes
  the pending destination and is previewed as the chosen leg would be; on release over such a star exactly one
  `route.fly [star, wait]` is sent; a release elsewhere, on the ship's star or outside playing clears the pending
  destination and sends nothing (a star with no corridor is explained in words). Two fingers as feature 444: a second
  finger cancels any one-finger gesture (nothing sent) and orbits — yaw ±60° about the vertical axis through the
  authored box centre (90° per view width), pitch −20° … +35° (60° per view height); a third finger re-bases the
  midpoint; a double tap on empty space or "Reset view" returns to orbit (0, 0); the camera refits so the authored box
  stays inside the view with a 5 % margin at every orbit and aspect 0.4 … 2.5 and the eye stays outside the box; meshes
  are rebuilt when the orbit changes; orbit is not saved (schema stays 1). Impact: FR-R02G1604-004, 006, 007;
  SC-R02G1604-002, 003, 004.
- Q: How is it built and tested? → A: a Core gesture controller (`StarlitCartoucheGestureController`) with a picker
  (`StarlitCartouchePicker`) and an orbit (`StarlitCartoucheOrbit`, with `camera(_:aspect:orbit:)` equal to the
  authored camera at orbit 0) takes pointer events with the view size, the drawn snapshot and the orbit and returns
  gesture actions (chooseDestination, chooseWait, fly, preview, clearPreview, resetView, explain) and the orbit; the
  snapshot carries the launch beat and launch positions and the geometry draws the preview; host tests feed 500 seeded
  taps, slider drags and ship drags on certified levels at several sizes and orbits against an independent pick in the
  test; simulator tests send touches through the experience's pointer entry; a host test wins all 100 certified levels
  through panel actions alone. Impact: FR-R02G1604-005, 008, 009; SC-R02G1604-001 … 005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Queue a leg by tapping a star (Priority: P1) 🎯

A player taps a star to make it the next destination and sees the leg previewed: a gliding route from the ship to where
that star will be when the ship arrives. Tapping the chosen star again (a double tap) flies the leg.

**Why this priority**: flying legs is the game's only move; picking the destination on the chart is the natural way.

**Independent Test**: scripted taps and double taps choose and fly exactly what an independent pick predicts.

**Acceptance Scenarios**:

1. **Given** any stage, **When** the player taps a star other than the ship's, **Then** it becomes the chosen
   destination and no kernel action is sent.
2. **Given** a level while playing, **When** the player double-taps a star other than the ship's, **Then** exactly one
   leg to that star with the chosen wait is sent.
3. **Given** a tap on the ship's star or on empty space, **When** it lifts, **Then** no destination changes and no
kernel
   action is sent.

### User Story 2 - Drag the time slider to time the launch (Priority: P1)

A player drags along the time slider (the row of wait pips below the chart) to choose how many beats to wait before
launching; while dragging, the stars glide to where they will be at the launch beat and the leg preview follows, so the
player can see when a star comes within range or a hazard clears.

**Why this priority**: timing is the heart of the puzzle; windows, range and hazards all depend on the launch beat.

**Independent Test**: scripted drags along the slider choose exactly the wait an independent computation predicts from
the finger's position, and the preview shows the stars at the chosen launch beat.

**Acceptance Scenarios**:

1. **Given** any stage, **When** the player drags along the slider, **Then** the chosen wait follows the finger (0 … 8)
   and no kernel action is sent.
2. **Given** a chosen wait, **When** the preview is drawn, **Then** it shows every star at its kernel position at the
   launch beat (the current beat plus the wait) and the previewed leg from the ship to the destination's position at
   arrival.

### User Story 3 - Fly by dragging the ship to a star (Priority: P1)

A player drags from the ship onto a star and lifts: the leg to that star with the chosen wait is flown (one action).

**Independent Test**: scripted drags send exactly the leg an independent pick predicts, or nothing.

### User Story 4 - Look around the chart and come back (Priority: P1)

A player orbits the chart with two fingers within bounds to see stars behind others and returns to the authored view;
the view never changes the game.

**Independent Test**: orbit stays within bounds at every aspect, the scene stays inside the view, and the digest never
changes.

### User Story 5 - Every move without gestures (Priority: P1)

A player who cannot touch precisely can do everything through the labelled panel (star − and +, wait − and +, fly, undo,
redo, next level, "Reset view"), including winning every certified level.

**Independent Test**: all 100 certified witnesses are replayed through panel actions on the host and win.

### Edge Cases

- **A touch that never moves far enough:** a tap is below 10 points and lifted within 0.5 s; two taps on the same star
  within 0.35 s and 22 points are a double tap; two such taps on empty space reset the view; a press lifted at 0.5 s or
  later without moving does nothing.
- **A touch that moves 10 … 16 points:** neither a tap nor a drag; nothing changes.
- **A drag from the ship that ends on empty space, on the ship's star or on a star with no corridor:** the preview
  clears and nothing is sent (a missing corridor is explained in words).
- **A star hidden by a nearer star:** the front-most star under the finger is picked, as drawn.
- **A leg the kernel refuses or fails** (out of range, a window, a hazard, the deadline, a stray stroke, the budget, the
  stage): sent; a refusal is logged and shown with its reason code, a failure ends the level as the kernel decides.
- **A finished play (won or failed):** gestures send no kernel action (taps and the slider still change the presentation
  choice) and the description says the play is over (undo or next level); orbit still works.
- **A second finger during a gesture:** cancels it (nothing sent) and starts an orbit.
- **A cancelled touch:** changes nothing that the finger had not already chosen; a previewed drag from the ship is
  cleared and nothing is sent.
- **Very small or very wide views:** picking, the slider and orbit work at every supported aspect.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1604-001**: A tap on a star other than the ship's MUST choose it as the destination through `route.choose`
  (presentation only) in any stage; a double tap on such a star while playing MUST send exactly one `route.fly` to it
  with the chosen wait.
- **FR-R02G1604-002**: A drag along the time slider MUST choose the wait from the finger's position (0 … 8) through
  `route.choose` in any stage and MUST send no kernel action.
- **FR-R02G1604-003**: While a wait is chosen, the scene MUST preview the launch: every star drawn at its kernel
  position at the launch beat and the previewed leg from the ship to the destination's position at arrival; the preview
  is presentation only and never enters the digest, the snapshot's game state or the kernel.
- **FR-R02G1604-004**: A drag that starts on the ship while playing and lifts over a star other than the ship's MUST
  send exactly one `route.fly` to it with the chosen wait; any other release MUST send nothing.
- **FR-R02G1604-005**: Picking MUST be analytic and deterministic: each star's projected disc through the drawn camera
  (orbit and preview included), grown by a fixed margin, the front-most (drawn last) first; the ship and the slider
  have their own projected regions; anything else is empty space.
- **FR-R02G1604-006**: Two-finger orbit MUST stay within fixed yaw and pitch bounds, keep the scene inside the view with
  a 5 % margin at every aspect 0.4 … 2.5 and never enter the digest, the snapshot's game state or the kernel; a double
  tap on empty space or "Reset view" returns to the authored view.
- **FR-R02G1604-007**: Gestures on a finished play, cancelled touches and second fingers MUST send no kernel action.
- **FR-R02G1604-008**: The panel MUST keep every action available without gestures and gain "Reset view"; every
  certified witness MUST be replayable through panel actions.
- **FR-R02G1604-009**: Gestures MUST be tested on the host by scripted pointer sequences and on the simulator through
  the experience's pointer entry; existing tests pass; every new public name is documented; refusals are logged with
  their reason code (observability). Undo and redo stay the kernel's exact undo and redo through the panel.

### Key Entities

- **Gesture controller**: its state (idle, star press, ship press, ship drag, slider drag, empty press, orbiting,
  cancelled), the touched target, the start and last points, the press time and the last tap's time, place and target.
- **Orbit**: yaw and pitch offsets from the authored view.
- **Launch preview**: the launch beat, the stars' positions at it and the previewed leg.
- **Gesture action**: chooseDestination, chooseWait, fly, preview, clearPreview, resetView, explain; fly and the choices
  map onto the declared adapter controls `route.fly` and `route.choose`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1604-001**: For 500 seeded scripted taps and drags on certified levels at several sizes and orbits, the
  actions and choices equal an independent computation.
- **SC-R02G1604-002**: Second fingers, cancels and gestures on a finished play send no kernel action in every scripted
  case.
- **SC-R02G1604-003**: Orbit and the launch preview never change the digest in every scripted case.
- **SC-R02G1604-004**: At every orbit within bounds, every wait 0 … 8 and every aspect 0.4 … 2.5 the scene stays inside
  the view with a 5 % margin.
- **SC-R02G1604-005**: All 100 certified levels are won through panel actions alone.
- **SC-R02G1604-006**: Existing tests pass; the reference regression passes 7 of 7; each test under 10 seconds.
- **SC-R02G1604-007** {device}: after ImplementationLock-100, touch feel and latency are checked on D1/D2/D3.

## Assumptions

- Hints, failure explanations and progression come in R02-G16-05; announcements, haptics, sound and full accessibility
  in R02-G16-06; persistence in R02-G16-07. The snapshot schema stays 1 here (orbit, the choice and the preview are not
  saved).
- All gestures map onto the adapter's declared controls or onto presentation state; no new kernel action is added.
- Thresholds for taps, drags and double taps follow feature 444 (and 434) so every round-two game feels the same.
- "Tap route nodes to queue legs" is read as choosing and flying one leg at a time (the kernel flies legs one by one and
  each is undoable); "preview gliding 3D route" as the launch preview of the chosen leg.
- Original design: all interaction and drawing are original code; no third-party assets or copied game designs.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tap route nodes to queue legs | FR-R02G1604-001, 004 |
| Drag time slider | FR-R02G1604-002 |
| Preview gliding 3D route | FR-R02G1604-003 |
| Gesture-to-world actions (analytic picking) | FR-R02G1604-005 |
| Camera behavior (orbit, reset) | FR-R02G1604-006 |
| Undo, accessible panel | FR-R02G1604-007, 008, 009 |

## Negative Requirements / Excluded scope

- No new kernel action, no saved orbit or preview, no device run before ImplementationLock-100, no availability before
  X-R02-G16.
