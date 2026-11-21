# Feature Specification: R02-G03-04 — Wave Knot Keeper: gameplay spatial interaction

**Feature Branch**: `324-wave-knot-keeper-gameplay-spatial-interaction` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G03-04 (migration ledger, game feature of experience R02-G03) · ID namespace FR-R02G0304-###,
SC-R02G0304-###, T-R02G0304-###

**Input**: User description: the archived R02-G03-04 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Implement tactile 3D manipulation, camera and accessible fallback" for Wave Knot Keeper, with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/324-wave-knot-keeper-gameplay-spatial-interaction`; FR-R02G0304-###,
  SC-R02G0304-###, T-R02G0304-###.
- **Packaging (ADR-0009):** experience R02-G03 (`r02-g03.wave-knot-keeper`, free; a registered candidate) in the one
  app; this feature extends its Core and experience target.
- **Superseded parts of the source prompt:** price, "no IAP", the Round 2 lock and the per-round device campaign
  (ImplementationLock-100). **Device-only items:** gesture feel and touch-to-frame latency on D1/D2/D3, recorded as a
  `{device}` task. **Owner-only items:** none.
- **Shared features used:** R02-F22 (spatial handles, picking, drag and assistive steps), R02-F10 (camera), the kernel,
  certified levels and renderer of R02-G03-01 … 03.
- **Model:** feature 314 (Lissajous Labyrinth's gameplay spatial interaction).

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only, 2026-11-21): Lissajous Labyrinth's feature 314 solved the same problem with a host-tested
`LissajousLabyrinthGestureController` (idle, turning, orbiting, cancelled; one action per gesture), an orbit in its scene
geometry and handle picking; R02-F22 provides `SpatialHandle`, `HandlePicker.pick` (22 pt minimum radius), `HandleDrag`
and `AssistiveStep`; Wave Knot Keeper's camera looks down −z tilted 20° about x with a 45° field of view and fits the
bounding sphere for aspects 0.4 … 2.5; its handles are icospheres of radius 0.18 at the control points; its panel has a
point picker (`point.select`) and six direction buttons that each send one `point.move`; its adapter accepts
`point.move [point, direction 0…5]` and `point.select [point]`.

- Q: How does a drag become a move? → A: the drag starts on a handle (picked with `HandlePicker` at the drawn camera, the
  nearest to the eye among those within the touch radius); for each of the six directions the projected on-screen vector
  of one lattice step (1/8 world unit) from the handle is computed with the drawn camera; the candidate is the direction
  whose unit on-screen vector has the largest dot product with the drag vector, ties to the lower direction index, kept
  only when the drag's component along it exceeds half that step's projected length (at least 6 points, so a tiny
  projection cannot make a jitter a move); otherwise no candidate. Release sends exactly one `point.move [point,
  direction]` for the candidate, or nothing. Impact: FR-R02G0304-001, 002; SC-R02G0304-001.
- Q: How are touches arbitrated? → A: as features 304 and 314: a Core `WaveKnotKeeperGestureController` with idle,
  dragging, orbiting and cancelled states; one finger on a handle starts dragging and selects that point
  (`point.select`, presentation only); a second finger cancels the drag and orbits; a cancelled gesture sends nothing; a
  release without movement beyond the snap distance is a tap that only selects; handles move only while playing (taps
  still select); a refused move is announced with its reason and changes nothing. Impact: FR-R02G0304-003, 005;
  SC-R02G0304-002.
- Q: What can the camera do? → A: two-finger orbit of yaw (±40° around the authored view, 90° per view width) and pitch
  (the tilt from the z axis between 5° and 60°, 60° per view height, authored 20°); a double tap on empty space or
  "Reset view" returns to the authored view; the distance refits so the rope, handles and gates stay inside the view
  with a 5 % margin at every orbit and aspect 0.4 … 2.5. Presentation only: never in the digest, the snapshot or the
  kernel; not saved. Impact: FR-R02G0304-004; SC-R02G0304-003.
- Q: How is the selection shown, and does the panel need pending moves? → A: the selected handle is drawn in ember (as
  feature 323) and the description names it ("Point n selected"); a drag previews its candidate by drawing the selected
  handle's would-be position as an ember ghost sphere. The panel needs no pending values: each direction button is
  exactly one kernel move, the same unit a drag makes, so every certified solution is replayable through the panel with
  one select and one button per move; the panel gains "Reset view". Impact: FR-R02G0304-005, 006; SC-R02G0304-004, 005.
- Q: How are gestures tested without a screen? → A: the Core gesture controller takes pointer events with the view size
  and the drawn camera and returns at most one action per gesture plus the preview and selection; tests feed scripted
  drags (seeded directions and lengths from each handle, second fingers, cancels, empty space) at fixed sizes and compare
  with the direction computed independently from the camera; simulator tests send the same touches through the
  experience's pointer entry; a host test wins all 100 levels through `point.select` and panel moves. Impact:
  FR-R02G0304-007; SC-R02G0304-001, 002, 004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag a rope point to move it (Priority: P1) 🎯

A player puts a finger on one of the rope's control handles and drags it; the handle previews the lattice step the drag
points to — along the axis whose on-screen direction best matches the drag, so depth moves are possible from the tilted
view — and on release exactly one move is made (or none, if the drag was too short or the move is not allowed).

**Why this priority**: moving points is the game.

**Independent Test**: scripted drags on handles at fixed view sizes end in exactly the move their direction and length
imply, computed independently.

**Acceptance Scenarios**:

1. **Given** a playing level, **When** a handle is dragged along an axis's on-screen direction past the snap distance and
   released, **Then** exactly one `point.move` for that point and direction is sent.
2. **Given** a drag shorter than the snap distance, **When** it is released, **Then** nothing is sent.
3. **Given** a move the kernel refuses (a strand would pass through another, bounds, tension), **When** it is released,
   **Then** the refusal is announced with its reason and nothing changes.

### User Story 2 - Look around without changing the puzzle (Priority: P1)

Two fingers orbit the camera to see which strand passes over which; a double tap on empty space or "Reset view" returns
to the authored view. The puzzle never changes.

**Independent Test**: orbiting to every limit and resetting changes no digest; the rope, handles and gates stay inside
the view.

### User Story 3 - Play with the panel alone (Priority: P1)

A player who cannot drag selects a point with the panel's point picker and moves it with the six labelled direction
buttons; every level can be won this way.

**Independent Test**: all 100 certified levels are won through `point.select` and the panel's direction actions alone in
exactly their certified shortest number of moves.

### User Story 4 - Know what is selected (Priority: P2)

The selected handle is drawn in ember and described; a tap on a handle selects it without moving it.

**Independent Test**: on the simulator the selected handle is ember and the description names it.

### Edge Cases

- **Second finger during a drag:** the drag is cancelled (nothing sent) and the gesture becomes an orbit.
- **Touch on empty space:** nothing is picked; a double tap resets the view.
- **Overlapping handles on screen:** the nearest handle to the eye under the touch is picked (within the minimum touch
  radius of 22 points).
- **Stage not playing (won, failed, replay later):** handles do not move; taps still select.
- **Ambiguous drag direction:** the drag's axis is the one with the largest projected component; ties go to the lower
  direction index.
- **Orbit limits and every aspect 0.4 … 2.5:** the scene stays inside the view with a 5 % margin.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0304-001**: Every control point MUST be a pickable handle with a minimum touch radius of 22 points; the
  nearest to the eye wins where handles overlap.
- **FR-R02G0304-002**: A one-finger drag on a handle MUST preview and, on release, send at most one `point.move` for the
  lattice direction whose projected on-screen unit step best matches the drag, once the drag exceeds half of that step's
  projected length.
- **FR-R02G0304-003**: Gestures MUST be arbitrated: one finger drags or taps a handle; two fingers orbit; a second finger
  cancels a drag; a cancelled gesture sends nothing; handles move only while playing.
- **FR-R02G0304-004**: The camera MUST orbit within stated limits, reset on request and never change the kernel's state,
  digest or snapshot; the scene MUST stay inside the view at every orbit and aspect.
- **FR-R02G0304-005**: The selected handle MUST be drawn and described; a tap MUST select without moving.
- **FR-R02G0304-006**: The panel MUST make every level winnable without gestures (point picker and six direction
  buttons), and undo, redo and "Reset view" MUST be reachable from it.
- **FR-R02G0304-007**: Gesture logic MUST be deterministic and testable without a screen.
- **FR-R02G0304-008**: Existing tests MUST pass; every new public name is documented; the reference regression passes.

### Key Entities

- **Handle**: a control point's pickable sphere with its screen position, depth and touch radius.
- **Gesture**: idle, dragging (point, start, candidate direction), orbiting, cancelled.
- **Orbit**: yaw and pitch offsets from the authored view, presentation only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0304-001**: For 500 seeded scripted drags, each gesture ends in exactly the action its release position
  implies (independently computed), or none.
- **SC-R02G0304-002**: Every arbitration case (second finger, cancel, empty space, not playing, refused move) sends
  nothing or the stated action, and is tested.
- **SC-R02G0304-003**: Orbiting to every limit and resetting changes no digest; the scene stays inside the view with a
  5 % margin at every orbit limit and at 7 aspects.
- **SC-R02G0304-004**: All 100 certified levels are won through the panel's actions alone in exactly their certified
  shortest number of moves.
- **SC-R02G0304-005**: On the simulator, the selected handle is ember and its description matches the state; a scripted
  drag through the experience's pointer entry moves the point.
- **SC-R02G0304-006**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10 s.
- **SC-R02G0304-007** {device}: after ImplementationLock-100, gesture feel and touch-to-frame latency are recorded on
  D1/D2/D3.

## Assumptions

- Hints, progression and modes are R02-G03-05; accessibility polish, sound and haptics R02-G03-06; persistence R02-G03-07.
- Gesture handling follows Lissajous Labyrinth's Core gesture controller pattern (feature 314).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Tactile 3D manipulation (drag depth-aware handles with snapping) | FR-R02G0304-001, 002 |
| Camera (two-finger orbit for occlusion disambiguation) | FR-R02G0304-004 |
| Accessible fallback (stepper controls for all essential changes) | FR-R02G0304-006 |
| Gesture arbitration | FR-R02G0304-003, 007 |
| No Stage One breakage | FR-R02G0304-008 |

## Negative Requirements / Excluded scope

- No hints, modes, sound, haptics or persistence here; no device run before ImplementationLock-100; no change to the
  rules.
