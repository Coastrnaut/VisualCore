# Feature Specification: Light Maze — Phase 02 Rendering and tap interactions

**Feature Branch**: `097-lm-p02-interaction` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A13-P02 (legacy ledger) · ID namespace FR-A13-2##, SC-A13-2##, T-A13-2##

**Input**: User description: archived manual `apps/13-light-maze.md` §9 Phase 02 `/speckit-specify` prompt (verbatim
in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — drag and rotate interactions snapped to the puzzle grid; regression
  fixture — repeating mirror loops end at a bounded bounce budget; graphics context ownership stays solely in the
  VisualCore host.
- **Gaps built here** (contract `docs/apps/light-maze/visualcore-contract.json`): G-SNAP (tap, drag and rotate on the
  board resolved to grid cells and snapped orientations, each with a native alternative) and G-BEAMS (the beam drawn
  with a capped glow from the tracer's exact segments, the targets and selection legible without colour alone). Level
  select with progression, undo and saved progress stay for A13-P03 (G-LEVELS); hints, spoken polish and success
  feedback for A13-P04 (G-FEEDBACK); the solvability checker for A13-P05.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A13; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`VisualCoreScenes` offers `TapRecognizer` (10 points, 0.3 s), `DragRecognizer` (begins after 10 points),
`RotateRecognizer` (two fingers) and `GestureArbiter` with `GestureDeclaration(id:kind:priority:pointers:)`, as Tiny
Worlds' `WorldsGestures` uses them (a pure value type over the arbiter, host-testable with synthetic pointer events,
sending actions through the caller's `send`); `GestureAlternatives.missing(gesture:native:)` checks every gesture
action has a native control; `MazePresenter` draws through `PrimitiveRenderer` with a `Camera2D` fitting the board and
already offers `tile.select [index]` and `tile.turn`; `AnnouncementSink`/`ViewAnnouncer`-style rate limiting exists in
Tiny Worlds (`ViewAnnouncer`, one per second of frame time).

- Q: How does a canvas point map to a cell, and what does a tap do? → A: The presenter inverts its board camera (view
  points → board units, cell = floor of x and y); a tap on a turnable tile sends `tile.select [index]` when it is not
  selected and `tile.turn` when it is; a tap on anything else sends nothing and is answered in words ("Nothing to turn
  there." / "Outside the board."). Taps on fixed tiles never change the board.
- Q: How does a drag snap? → A: A drag that begins (10 points) on a turnable tile is measured from touch-down to the
  latest point in board units; once it is at least 0.35 of a cell long it snaps the tile to `/` when the direction lies
  within 45° of north-east or south-west, else to `\`: when the tile's orientation differs, the gesture sends
  `tile.select [index]` and `tile.turn` (the same actions as the Select and Turn controls, so no new action exists and
  every gesture action has a native control); when it already matches, it sends nothing. At most one turn per drag
  movement; later movement may turn it back if the direction crosses over. A drag that begins elsewhere does nothing.
- Q: How does the two-finger rotation snap? → A: `RotateRecognizer` over the selected tile; each time the accumulated
  angle passes ±45° from the last snap the tile turns once (`tile.turn`) and the reference resets; less than 45° does
  nothing. Arbiter priorities: rotate 3 (two fingers), drag 2, tap 1.
- Q: How is the glow drawn and bounded? → A: Layered primitives under the core line: a halo line of width 0.30 cell at
  opacity 0.25 and the core line of width 0.08 cell at full opacity, in the beam colour; nothing post-processed, nothing
  animated; the glow never exceeds 0.15 cell from the segment. Lit targets get a ring (an outline square inset 0.05 from
  the target) and the selected tile an outline square inset 0.04 from its cell; both shapes, not colour alone.
- Q: What do the loop fixtures and the spoken changes cover? → A: Core tests with committed boards: a mirror-only board
  whose path returns to the emitter (ends "emitter"), a prism board whose branches meet (ends "loop"), a long mirror
  spiral that reaches the bounce cap, each within 64 bounces per branch and 256 segments; a spoken change ("Beam ends at
  the target; solved.") when the beam's end words or the solved state change, at most once per second of frame time,
  while VoiceOver runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Touch a mirror to turn it (Priority: P1) 🎯

A person taps a mirror or prism on the board to select it and taps it again to turn it; the beam redraws at once.
Taps anywhere else never change the board.

**Why this priority**: the manual's first journey by touch, and the phase's interaction slice.

**Independent Test**: tap board points on the simulator's canvas through the presenter's gesture entry; read the
selection, orientations and beam.

**Acceptance Scenarios**:

1. **Given** level 1, **When** the mirror's cell is tapped, **Then** the mirror is selected; **When** tapped again,
   **Then** it turns and the beam changes.
2. **Given** a tap on an empty cell, a wall, the emitter, a target or outside the board, **Then** nothing on the board
   changes and the tap is answered in words.

---

### User Story 2 - Drag or twist snaps to a diagonal (Priority: P1)

A person drags across a mirror along one diagonal, or twists two fingers over it, and the mirror snaps to the nearest
of its two orientations — never stopping in between.

**Why this priority**: the phase's MVP requirement.

**Independent Test**: feed drag and rotation gestures to the gesture resolver; read the snapped orientations.

**Acceptance Scenarios**:

1. **Given** a drag that starts on a turnable tile, **When** it moves mostly towards north-east or south-west, **Then**
   the tile becomes `/`; towards north-west or south-east, `\`; a drag shorter than the snap distance changes nothing.
2. **Given** a selected tile, **When** two fingers rotate it by at least the snap angle, **Then** it turns once; less
   than that snaps back and changes nothing.
3. **Given** any gesture, **Then** it reaches the board only through the same actions the native controls send.

---

### User Story 3 - A glowing beam that never hides its path (Priority: P2)

A person sees the beam as a bright line with a soft glow, the lit targets clearly marked, and the selected tile
outlined — and can still follow the beam's path exactly, with or without colour.

**Independent Test**: draw frames; compare the beam core with the tracer's segments; measure the glow's width; check
lit targets carry a non-colour mark.

**Acceptance Scenarios**:

1. **Given** a traced beam, **When** drawn, **Then** every drawn beam line lies on a tracer segment and the glow stays
   within a stated width of it.
2. **Given** a lit target, **Then** it differs from an unlit one by a shape (a ring) as well as colour; the selected
   tile has an outline.

---

### User Story 4 - Loops stay bounded (Priority: P2)

The engineer can trust that any board whose beam would repeat stops within the bounce budget.

**Independent Test**: committed loop boards traced and checked against the budget.

**Acceptance Scenarios**:

1. **Given** boards built to loop with mirrors and with prisms, **When** traced, **Then** every branch ends within 64
   bounces with a stated reason and the total segments stay within 256.

### Edge Cases

- **A drag that leaves the board or crosses several tiles:** only the tile where it started is affected.
- **A gesture on a fixed tile** (emitter, wall, target): ignored, answered in words.
- **Simultaneous drag and rotation:** the gesture arbiter picks one; the other is ignored.
- **Very small canvases:** the board fits the canvas; cells smaller than the minimum touch size still resolve by cell.
- **Reduce Motion and Reduce Flashing:** nothing animates or flashes in this slice; the glow is static.
- **Context loss:** the glow and beam are rebuilt from the state.
- **VoiceOver:** changes to the beam are spoken at most once per second.

## Requirements *(mandatory)*

### Functional Requirements

**Interactions (G-SNAP, stories 1–2)**

- **FR-A13-201**: A tap MUST resolve the touched board point to a cell; on a turnable tile it MUST select it, or turn it
  if already selected; elsewhere it MUST change nothing and answer in words.
- **FR-A13-202**: A drag starting on a turnable tile MUST snap the tile to the diagonal nearest the drag direction once
  the drag exceeds a snap distance; shorter drags MUST change nothing.
- **FR-A13-203**: A two-finger rotation over a selected tile MUST turn it once per snap angle crossed; smaller rotations
  MUST change nothing.
- **FR-A13-204**: Every gesture MUST go through the same replayable actions as the native controls (`tile.select`,
  `tile.turn`), so every gesture action has a native control.

**Drawing (G-BEAMS, story 3)**

- **FR-A13-210**: The beam MUST be drawn as a core line on each tracer segment with a glow of capped width and opacity,
  without any decision about the solved state in drawing.
- **FR-A13-211**: Lit targets MUST carry a ring and the selected tile an outline (not colour alone); the beam's path MUST
  stay legible where glows overlap.
- **FR-A13-212**: Beam changes MUST be spoken at most once per second while VoiceOver runs.

**Loops (story 4)**

- **FR-A13-220**: Committed loop fixtures MUST prove every repeating beam ends within the bounce and segment budgets.

### Key Entities

- **Gesture**: tap point, drag start and end, rotation angle.
- **Snap rule**: snap distance, snap angle, diagonal choice.
- **Glow**: core width, glow width, glow opacity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A13-201**: 100 % of taps on turnable tiles select or turn as stated; 0 board changes from taps elsewhere.
- **SC-A13-202**: 100 % of drags beyond the snap distance land on the nearest diagonal; 0 changes below it.
- **SC-A13-203**: Rotations turn exactly once per snap angle crossed.
- **SC-A13-204**: Every drawn beam core lies on a tracer segment; the glow never extends beyond its stated width.
- **SC-A13-205**: Every loop fixture ends within 64 bounces per branch and 256 segments.
- **SC-A13-206**: The runner's nine scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The tracer, the 20 levels, the actions and the presenter of A13-P01 exist; VisualCore's gesture recognizers and
  arbiter, `Camera2D` and the primitive renderer are reused.
- Glow is drawn with layered primitives in this slice (no post-processing pass); success feedback animation is A13-P04.

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 MVP: drag and rotate snapped to the grid | FR-A13-201–204, US1, US2 |
| Regression fixture: repeating mirror loops end at a bounded bounce budget | FR-A13-220, US4 |
| EGL/context ownership in the VisualCore host | FR-A13-210 |
| Brainstorm: touch controls, compositing and visual feedback, shaders | FR-A13-201–212 |
| Manual feature 5 (glow and colour cues without hiding connectivity) | FR-A13-210, 211 |
| Contract gaps G-SNAP, G-BEAMS | FR-A13-201–212 |

## Negative Requirements

- No free placement of tiles; no animation or flashing; no shader deciding the solved state; no sprites or textures;
  no progression, undo or saved progress in this phase.
