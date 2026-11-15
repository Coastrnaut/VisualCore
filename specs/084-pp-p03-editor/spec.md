# Feature Specification: Physics Playground — Phase 03 Gesture editor and overlays

**Feature Branch**: `084-pp-p03-editor` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A11-P03 (legacy ledger) · ID namespace FR-A11-3##, SC-A11-3##, T-A11-3##

**Input**: User description: archived manual `apps/11-physics-playground.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — object spawn, grab, pin and delete gestures; regression fixture — a body
  of mass zero is treated as static and never divided by zero; graphics-context ownership stays solely in the
  VisualCore host.
- **Gaps built here** (contract `docs/apps/physics-playground/visualcore-contract.json`): G-EDITOR (the gesture
  editor over VisualCore's recognizers) and G-OVERLAYS (velocity and force arrows and the measured state panel), both
  app-local; no VisualCore change is planned.
- **Out of this phase:** drawing new springs by gesture, presets and saved experiments (A11-P04), stability caps and
  sleeping bodies (A11-P05).
- **Owner rulings:** short tests; iOS 27 at phase gates; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`VisualCoreScenes` offers `TapRecognizer` (≤ 10 pt movement, ≤ 0.3 s), `DoubleTapRecognizer` (second tap within
0.3 s and 30 pt), `LongPressRecognizer` (≥ 0.5 s, ≤ 10 pt), `DragRecognizer` (≥ 10 pt) and `GestureArbiter` with
`GestureDeclaration`s (id, kind, priority, pointers); a presenter receives `pointer(_:viewSize:port:)` and declares
`gestureActions`; actions go through `ExperienceActionPort`; `Springs2D.apply` exists for the grab pull; the world is
schema 2 with `WorldDiagnostics` (kinetic, potential, spring and total energy, momentum).

- Q: Which actions carry the edits, and with which values? → A: `edit.add [x 0…10, y 0…8, kind 0…1]` (refused with
  `a11.body-cap`, or `a11.no-room` when the new body's bounds would cross the stage edge or overlap a body by more than
  half its size); `edit.select [id -1…10000]` (−1 clears; an unknown id → `a11.unknown-body`); `edit.grab [id, x, y]`
  (dynamic, unpinned bodies only, else `a11.not-grabbable`; the anchor is the touched point in the body's frame),
  `edit.move [x, y]` (clamped to the stage; refused `a11.no-grab` without a grab), `edit.release` (ends the grab; the
  body keeps its own velocity); `edit.pin [id]` (toggles; a pinned body has inverse mass and inertia 0 and zero
  velocity; static bodies cannot be unpinned → `a11.static-body`); `edit.delete [id]` (removes the body, its springs,
  its cache entries, the grab and selection if they name it); `edit.nudge [dx −1…1, dy −1…1]` (adds 1 m/s × value to
  the selected dynamic body's velocity); `overlay.velocity [0…1]`, `overlay.forces [0…1]`. Coordinates are stage
  metres; ids are whole numbers.
- Q: How do gestures map to those actions? → A: The presenter converts view points to stage metres through its
  letterbox mapping and arbitrates: double-tap on a body → `edit.delete`; long-press on a body → `edit.pin`; drag
  starting on a body → `edit.grab`, then `edit.move` per move, `edit.release` on end, cancel or a second finger; tap on
  a body → `edit.select`; tap on empty stage → `edit.add` with the shape picker's kind. Priority: double-tap > long-press
  > drag > tap; a tap waits for the double-tap window (0.3 s). Native controls: previous/next body (select), Pin,
  Delete, Add at centre, four nudge buttons, the shape picker, two overlay toggles.
- Q: How does the grab pull work? → A: A spring from the body's anchor to the target with stiffness at the body's
  stable bound (`Springs2D.stableStiffness`) and damping ratio 1.0 (critically damped), applied each tick with the
  world's springs; it is not stored as a world spring and draws as a thin line. Measured target: within 5 cm of a still
  target in 1 s.
- Q: How are arrows and the panel computed? → A: Velocity arrow: from the centre along v, length 0.25 s × |v| m,
  capped at 2 m. Force arrows per dynamic body: weight m·g (down) and net spring force (sum of the springs' last-tick
  forces on the body), each drawn at 0.05 m per newton, capped at 2 m; arrowheads are triangles 0.12 m long. The panel
  shows kinetic, potential (above the floor), spring and total energy in joules (2 decimals), total momentum in
  kg·m/s (2 decimals) and the selected body's speed in m/s (2 decimals), with the line "Educational approximation".
  Arrows and the panel never write to the world.
- Q: What is stored, and how does schema 2 migrate? → A: Schema 3 adds per-body `pinned` (false), `selectedId` (nil),
  `grab` (nil: body id, local anchor, target), `showVelocity` and `showForces` (false). Migration 2 → 3 sets those
  defaults; reset clears them. Pinning keeps the body's material; unpinning restores mass from it. The digest covers
  all of them.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Edit the stage with touch (Priority: P1) 🎯

A person taps an empty spot to add a circle or a box there, drags a body to throw it, holds a body to pin it in place
(or unpin it), and double-taps a body to delete it — and every one of these also works through on-screen controls for
people who cannot use the gestures.

**Why this priority**: the manual's MVP for this phase (version 0.1 feature 03) and journey 1 (drop objects).

**Independent Test**: each gesture on the canvas produces the matching change in the world; the same change is
reachable by native controls for the selected body.

**Acceptance Scenarios**:

1. **Given** an empty spot on the stage, **When** the person taps it, **Then** a body of the chosen shape appears
   centred there (if it fits inside the stage and the body limit is not reached).
2. **Given** a dynamic body, **When** the person drags it, **Then** it follows the finger through a soft pull (it still
   collides) and, on release, keeps the velocity it had.
3. **Given** a dynamic body, **When** the person holds it, **Then** it becomes pinned — fixed in place, treated as
   immovable — and holding it again releases it.
4. **Given** a body, **When** the person double-taps it, **Then** it and every spring attached to it are removed.
5. **Given** VoiceOver or no touch precision, **When** the person uses the controls, **Then** they can select the next
   or previous body, pin or unpin it, delete it, add a body at the stage centre and nudge the selected body.

---

### User Story 2 - See the forces (Priority: P1)

A person turns on arrows that show each body's velocity and the forces acting on it, and a panel that shows measured
energy and momentum, all labelled as educational approximations.

**Why this priority**: version 0.1 feature 06 (velocity and force overlays, measured state panel) and journey 3
(inspect energy).

**Independent Test**: with overlays on, arrows are drawn at each body with lengths proportional to the measured values;
with them off, none are drawn; the panel's numbers equal the world's diagnostics.

**Acceptance Scenarios**:

1. **Given** velocity arrows on, **When** a body moves, **Then** an arrow from its centre points along its velocity,
   with a length proportional to its speed (capped on screen).
2. **Given** force arrows on, **When** gravity and springs act, **Then** each dynamic body shows its weight and its net
   spring force as separate arrows.
3. **Given** the state panel, **When** it is read, **Then** it shows kinetic, potential, spring and total energy, total
   momentum and the selected body's speed, rounded, with the note that they are educational approximations.
4. **Given** overlays off, **When** a frame is drawn, **Then** no arrow appears and the world is unchanged.

---

### User Story 3 - Pinned bodies are truly static (Priority: P1)

A pinned body or a body of zero mass never moves, is never divided by its mass, and other bodies collide with it.

**Why this priority**: the phase's regression fixture (manual §11 fixture 3).

**Acceptance Scenarios**:

1. **Given** a pinned body hit repeatedly for 1,000 ticks, **When** the world runs, **Then** its position and angle are
   unchanged exactly and every number stays finite.
2. **Given** a spring between a pinned body and a dynamic one, **When** the world runs, **Then** the pinned end stays put
   and the dynamic body swings.
3. **Given** a pin released, **When** the world runs, **Then** the body regains its mass from its material and falls.

---

### User Story 4 - Edits are saved and replayable (Priority: P2)

Edits are actions with their ticks, so a recorded editing session replays exactly, and a saved world keeps its pins,
selection and overlay choices; a world saved by Phase 02 opens with nothing pinned and overlays off.

**Acceptance Scenarios**:

1. **Given** a recorded list of edits, **When** it is replayed twice, **Then** the worlds are identical.
2. **Given** a Phase 02 saved world, **When** it is restored, **Then** it migrates with no pins, no selection, no grab
   and overlays off.

### Edge Cases

- **Tap where a body already is:** selects it instead of adding one; a tap outside the stage does nothing.
- **Adding beyond the body limit or where the new body would cross a wall:** refused with a reason, nothing changes.
- **Grabbing a pinned or static body:** refused (pinned bodies stay put); unpinning while grabbed is allowed.
- **Deleting the grabbed or selected body:** the grab ends and the selection clears.
- **Deleting a spring's body:** its springs are removed with it.
- **Two fingers or a cancelled gesture:** the grab ends as on release.
- **A drag outside the stage:** the pull target is clamped inside the stage.
- **Very fast flicks:** the release velocity is the body's own (capped by the speed limit), never computed from the
  finger alone.
- **Reduce Motion:** arrows are static drawings of the current values; nothing decorative moves.

## Requirements *(mandatory)*

### Functional Requirements

**Editing (G-EDITOR, app-local)**

- **FR-A11-301**: The world MUST support adding a circle or box at a point, grabbing a dynamic body with a soft pull
  toward a moving target and releasing it, pinning and unpinning a body, deleting a body with its springs, and
  selecting a body, each as a validated action applied at its tick.
- **FR-A11-302**: A pinned body MUST be treated as static (zero inverse mass and inertia) while pinned and regain its
  material mass when unpinned; nothing may divide by a zero mass.
- **FR-A11-303**: Canvas gestures MUST map to those actions (tap empty → add; tap body → select; drag body → grab,
  move, release; hold body → pin toggle; double-tap body → delete) using VisualCore's recognizers and arbiter, and
  every action MUST have a native control alternative with a VoiceOver label and value.

**Overlays (G-OVERLAYS, app-local)**

- **FR-A11-310**: Velocity and force arrows MUST be optional (off by default) and drawn from the world's measured
  values at the physics positions, with stated scales and on-screen caps.
- **FR-A11-311**: A state panel MUST show kinetic, potential, spring and total energy, total momentum and the selected
  body's speed in stated units, labelled as educational approximations, computed without changing the world.

**State**

- **FR-A11-320**: The world MUST become schema 3 (pins, selection, grab, overlay choices) with a migration from schema
  2; drawing, overlays and the panel MUST never change the world.
- **FR-A11-321**: The scenario manifest MUST add fixtures for add, grab and release, pin and the static fixture,
  delete with springs, selection, overlays on and off, and the schema-2 migration.

### Key Entities

- **Grab**: body id, local anchor point, target point.
- **Overlay settings**: velocity arrows on or off, force arrows on or off.
- **World (schema 3)**: schema-2 world plus per-body pinned flags, selected body id, grab and overlay settings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A11-301**: Each of the five gestures produces its action in 100 % of the scripted gesture tests; each action is
  also reachable by a native control.
- **SC-A11-302**: A pinned body moves by exactly 0 over 1,000 ticks of impacts with no non-finite value; unpinned it
  falls at g within 1 %.
- **SC-A11-303**: A grabbed body reaches within 5 cm of a still target within 1 s; a released body keeps its velocity at
  release.
- **SC-A11-304**: The panel's values equal the world's diagnostics to display precision; arrows have the stated
  lengths within one pixel.
- **SC-A11-305**: Replays of editing sessions are identical; schema-2 worlds migrate in 100 % of fixtures.
- **SC-A11-306**: The standard scenarios and fixtures pass on iOS 27; each package test finishes in under 10 s.

## Assumptions

- VisualCore's tap, double-tap, long-press and drag recognizers and gesture arbiter are reused as they are (contract
  row M08); arrows use its lines and polygons (row M11).
- The pull of a grab is an app-local spring to the target using the world's existing spring code.

## Out of Scope

- Drawing new springs by gesture, editing materials, presets, saved experiment files, undo.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 03 (spawn, grab, pin, delete) | FR-A11-301–303; story 1 |
| v0.1 feature 06 (velocity and force overlays, measured state panel) | FR-A11-310, 311; story 2 |
| Phase 03 regression fixture (mass zero static) | FR-A11-302; story 3 |
| Journeys 1 and 3 | stories 1, 2 |
| Contract gaps G-EDITOR, G-OVERLAYS | FR-A11-301–311 |
| Constitution A11 (truthful claims; accessibility alternatives) | FR-A11-303, 311 |

## Negative Requirements

- No artwork; no network; no permission; no simulation in shaders; drawing and overlays never change the world; no claim
  of engineering accuracy.
