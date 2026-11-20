# Feature Specification: R02-G01-04 — Aurora Loom: gameplay spatial interaction

**Feature Branch**: `304-aurora-loom-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G01-04 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0104-###,
SC-R02G0104-###, T-R02G0104-###

**Input**: User description: the archived R02-G01-04 `/speckit-specify` prompt (round2.md line 2380), verbatim in the
invocation: "Implement native gesture-to-world actions, undo and camera behavior" for Aurora Loom, with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/304-aurora-loom-gameplay-spatial-interaction`; FR-R02G0104-###, SC-R02G0104-###,
  T-R02G0104-###.
- **Packaging (ADR-0009):** experience R02-G01 (`r02-g01.aurora-loom`, free; a registered candidate since R02-G01-03) in
  `Packages/ExperiencesRound02/AuroraLoom`; this feature adds the touch controls to its Core (host-tested gesture logic)
  and Experience (presenter, scene highlights).
- **Superseded parts of the source prompt:** price and "no IAP"; the Round 2 lock and per-round device campaign
  (ImplementationLock-100). **Device-only items:** the feel of the gestures on real touch screens and their latency on
  D1/D2/D3, `{device}` tasks after the lock. **Owner-only items:** none.
- **Shared features used:** R02-F22 (spatial handles, handle picking, constrained drags, assistive steps), R02-F08
  (geometry), and the kernel, catalog and renderer of R02-G01-01 … 03.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): R02-F22 provides `SpatialHandle`, `HandlePicker.pick` (minimum touch radius 22 pt,
nearest wins, ties by id), `HandleDrag` (axis and plane constraints with grazing holds and `angle(around:)`) and
`AssistiveStep`; `PointerEvent`, `PointerTracker` and `PinchRecognizer` are in VisualCoreScenes and `ScreenProjection`
in VisualCoreMath, all host-testable; R02-G01-03's `AuroraLoomSceneGeometry` fits the loom for aspects 0.4 … 2.5 and its
presenter receives `pointer(_:viewSize:port:)`.

- Q: Where are the anchors and dials, and how do positions become steps? → A: each ribbon's anchor slides on a vertical
  rail just beyond the loom's right end in its own lane (x = +L/2 + 0.45); its height is H · (2 · wave / 15 − 1), so steps
  0 … 15 span −H … +H; a drag follows the rail (an axis constraint along y, clamped to −H … +H) and the candidate step is
  the nearest, round((y / H + 1) · 7.5). Each ribbon's dial is a ring of radius 0.3 standing across the loom just before
  its left end (x = −L/2 − 0.45) in its lane; its knob sits at angle phase · 22.5°; a drag follows the ring's plane and the
  candidate step is the start step plus round(turned angle / 22.5°), modulo 16. Rationale: the rail shows the wave as a
  height and the dial shows the phase as an angle, matching how the picture draws them. Impact: FR-R02G0104-001, 002;
  SC-R02G0104-001.
- Q: How are touches arbitrated? → A: a gesture controller in the Core has four states — idle, dragging (one finger
  picked a handle with R02-F22's picker), orbiting (two fingers) and cancelled (until every finger lifts). One finger down
  on a handle starts a drag and selects its ribbon; one finger elsewhere does nothing. A second finger cancels a drag
  (nothing is sent) and starts orbiting; a cancelled touch ends any drag without a move. On release of a drag whose
  candidate differs from the start, exactly one `ribbon.move` is sent; equal means nothing. Handles respond only while the
  level is playing. A refused move shows the refusal's text and leaves the state unchanged. Impact: FR-R02G0104-002, 003,
  006; SC-R02G0104-002.
- Q: What can the camera do, and is it saved? → A: two fingers orbit: the midpoint's horizontal movement turns the azimuth
  (90° per view width) within base ± 40°, the vertical movement the elevation (60° per view height) within 10° … 60°; a
  double tap on empty space or the "Reset view" button returns to the authored pose; the camera distance is refitted so
  the whole loom stays inside the view with a 5 % margin at every orbit and aspect 0.4 … 2.5. The orbit is presentation
  only: never in the digest, the snapshot payload or the kernel; it is not saved (saving is R02-G01-07). Impact:
  FR-R02G0104-004; SC-R02G0104-003.
- Q: How is the selection shown and announced? → A: the selected ribbon is the one whose handle was last picked or whose
  stepper was last used (ribbon 1 at the start); the scene draws its anchor and dial with a gold outline ring and brighter
  knobs, the others dim; the canvas's accessibility value and the experience description say "Ribbon n selected: wave w,
  phase p" and the drag's candidate while dragging. Impact: FR-R02G0104-005; SC-R02G0104-004.
- Q: How are gestures tested without a screen? → A: `AuroraLoomGestureController` (Core) takes pointer events with the
  view size and the drawn camera and returns at most one `AuroraLoomMove` per gesture plus the current preview and
  selection; tests feed scripted touches (taps, drags along rails, circular drags around dials, second fingers, cancels)
  at fixed view sizes and compare the result with the step the end point names, computed independently in the test.
  On the simulator the presenter's wiring is tested by sending the same touches through the experience's pointer entry.
  Impact: FR-R02G0104-006; SC-R02G0104-001, 002.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag an anchor to reshape a ribbon (Priority: P1) 🎯

A player puts a finger on a ribbon's anchor and drags it up or down; the ribbon's wave follows in sixteen stable steps,
and when the finger lifts the new wave is played as one move (which can be undone).

**Why this priority**: the anchor is the game's primary verb; without it the game is only steppers.

**Independent Test**: a scripted drag on a ribbon's anchor ends in exactly one kernel move to the step under the finger;
a drag that returns to its start sends nothing.

**Acceptance Scenarios**:

1. **Given** a playing level, **When** the player drags ribbon 2's anchor up by three steps and lifts, **Then** one move
   sets ribbon 2's wave three steps higher and the move counter rises by one.
2. **Given** a drag in progress, **When** a second finger lands, **Then** the drag is cancelled and nothing is sent.

### User Story 2 - Turn a dial to shift a ribbon's phase (Priority: P1)

A player turns a ribbon's orbital dial; the phase follows in sixteen steps per turn, and lifting the finger plays it as
one move.

**Independent Test**: a scripted circular drag around a dial by a quarter turn ends in one move of four phase steps.

### User Story 3 - Look around without changing the puzzle (Priority: P1)

A player pans with two fingers to orbit the camera within limits and can reset it; the camera never changes the level's
state, digest or outcome.

**Independent Test**: orbiting to every limit changes no digest and keeps the whole loom in view.

### User Story 4 - Know what is selected and undo it (Priority: P2)

The ribbon under control is outlined and announced; undo and redo restore the previous controls exactly, including
after gestures.

**Independent Test**: after a gesture the selected ribbon's outline is drawn and its description spoken; undo returns
the exact previous digest.

### Edge Cases

- **A touch between handles or on empty space:** nothing is selected or sent.
- **Two handles under one touch:** the nearest on screen wins, ties by the lower handle id (R02-F22's picking rule).
- **A drag beyond the anchor rail or past a full dial turn:** clamped to steps 0 … 15 (wave) or wrapped modulo 16
  (phase).
- **A gesture that ends at the start value, a cancelled touch, a second finger mid-drag:** no move.
- **A gesture while paused, won or failed:** the handles do not respond; nothing is sent.
- **A gesture whose move the kernel refuses** (for example the allowance is spent): the refusal is shown, the state is
  unchanged.
- **Camera at its limits or a tiny view:** orbit is clamped; picking still uses the drawn camera.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0104-001**: Each ribbon MUST have an anchor (wave) and a dial (phase) drawn in the scene and pickable by touch
  with at least the platform's minimum touch target (a 44-point target: R02-F22's 22-point minimum pick radius).
- **FR-R02G0104-002**: Dragging an anchor MUST map the finger's position to a wave step 0 … 15 and turning a dial MUST map
  the angle to a phase step modulo 16; while dragging, the candidate step is previewed; on release a changed step MUST be
  sent as exactly one kernel move.
- **FR-R02G0104-003**: Gestures MUST be arbitrated: one finger on a handle drags it; two fingers orbit the camera; a second
  finger during a handle drag cancels it; cancelled touches send nothing.
- **FR-R02G0104-004**: The camera MUST orbit within stated limits, reset on request and never change the kernel's state,
  digest, verdict or the framing guarantee (the whole loom stays in view).
- **FR-R02G0104-005**: The selected ribbon MUST be outlined in the scene and described for VoiceOver; undo and redo MUST
  restore exact previous states after gestures as after steppers.
- **FR-R02G0104-006**: Gesture-to-move logic MUST be deterministic and testable without a screen (scripted touches in,
  moves out); the steppers MUST remain an equal alternative for every gesture.
- **FR-R02G0104-007**: Existing tests MUST pass unchanged; every new public name is documented; the reference regression
  passes.

### Key Entities

- **Handle set**: for each ribbon an anchor (position on its rail, step) and a dial (centre, angle, step).
- **Gesture session**: the touches, the picked handle, the start and candidate step, the state (idle, dragging, orbiting,
  cancelled).
- **Camera orbit**: azimuth and elevation offsets within limits; presentation only.
- **Selection**: the ribbon last touched or focused.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0104-001**: For 500 seeded scripted drags on anchors and dials, each gesture ends in exactly the move the
  finger's end position or angle names (or none when unchanged), and the kernel's state equals applying that move.
- **SC-R02G0104-002**: For every arbitration case (second finger, cancel, empty space, paused, won, failed, refused move)
  nothing is sent or the state is unchanged, in 1,000 seeded gesture scripts.
- **SC-R02G0104-003**: Orbiting to every limit and resetting changes no digest; the whole loom stays inside the view with a
  5 % margin for aspects 0.4 … 2.5.
- **SC-R02G0104-004**: On the simulator, the selected ribbon's outline is drawn and its description matches the state;
  undo after a gesture restores the exact earlier digest.
- **SC-R02G0104-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test finishes in under
  10 seconds.
- **SC-R02G0104-006** {device}: after ImplementationLock-100, gesture feel and touch-to-frame latency are recorded on
  D1/D2/D3.

## Assumptions

- Hints and progression are R02-G01-05; full accessibility polish (VoiceOver rotor, large text) R02-G01-06; persistence
  of the camera and progress R02-G01-07.
- The gestures and visuals are original; nothing is copied from another game.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Native gesture-to-world actions (anchor drag, orbital dial) | FR-R02G0104-001, 002, 006 |
| Gesture arbitration, accessible steppers | FR-R02G0104-003, 006 |
| Undo | FR-R02G0104-005 |
| Camera behaviour (two-finger pan, reset, puzzle-neutral) | FR-R02G0104-004 |
| Selected control highlight and VoiceOver description | FR-R02G0104-005 |
| INV-05 undo camera-independent, INV-10 renderer purity | FR-R02G0104-004, 005 |
| No Stage One breakage | FR-R02G0104-007 |

## Negative Requirements / Excluded scope

- No new rules, no hints, no saving, no keyboard or controller requirement, no device run before ImplementationLock-100.
