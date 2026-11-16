# Feature Specification: Molecular Explorer — Phase 02 Camera/atom/bond renderer

**Feature Branch**: `111-me-p02-renderer` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A15-P02 (legacy ledger) · ID namespace FR-A15-2##, SC-A15-2##, T-A15-2##

**Input**: User description: archived manual `apps/15-molecular-explorer.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — ball-and-stick and space-filling rendering modes; regression fixture —
  the built-in water and ethanol coordinate tests produce the expected atom count; graphics context ownership stays
  solely in the audited VisualCore host.
- **Gaps built here** (contract `docs/apps/molecular-explorer/visualcore-contract.json`): G-RENDER (the molecule scene:
  atoms and bonds drawn from shared meshes under a draw budget), G-CAMERA (framing, orbit, tilt, zoom, reset, the
  camera kept apart from the molecule data) and G-DISPLAY (the two display modes; the contract placed it in A15-P03,
  this phase's MVP gate brings it forward). Picking, gestures, panning, labels, bond-order styling and the panel stay
  for A15-P03; the persisted library, recent molecules and settings for A15-P04; the import for A15-P05.
- **Experience:** the candidate of A15-P01 grows; no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A15; every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See atoms and bonds in two styles (Priority: P1) 🎯

A person sees the chosen molecule as balls joined by sticks, each half of a stick in the colour of the atom it touches,
and can switch to a space-filling view where every atom is shown at its van der Waals size and the sticks are hidden.

**Why this priority**: the phase's MVP and the manual's third journey ("change ball-and-stick vs space-filling
display").

**Independent Test**: open a molecule; read the drawn frame in both modes; switch back.

**Acceptance Scenarios**:

1. **Given** a molecule in ball-and-stick, **When** it is drawn, **Then** every atom and every recorded bond is drawn,
   each bond as two halves coloured by their atoms.
2. **Given** the same molecule, **When** the mode is switched to space-filling, **Then** atoms are drawn at their van der
   Waals radius, no bond is drawn, and the drawn frame differs.
3. **Given** either mode, **When** the molecule or the camera changes, **Then** the mode is kept.

---

### User Story 2 - Turn and zoom the molecule (Priority: P1)

A person turns the molecule left and right, tilts it up and down, zooms in and out within limits, and resets the view;
the molecule always stays centred, and every step is spoken.

**Why this priority**: the manual's second journey ("rotate/zoom") and gap G-CAMERA.

**Independent Test**: step the camera through its range; reset; read the frame and the control values.

**Acceptance Scenarios**:

1. **Given** a molecule, **When** the camera is turned, tilted or zoomed, **Then** the drawn frame changes and the
   centre of the molecule stays at the centre of the canvas.
2. **Given** the camera at a limit, **When** a further step is asked for, **Then** it is refused with a reason.
3. **Given** a changed camera, **When** the view is reset, **Then** the molecule is framed again with every atom in view.

---

### User Story 3 - The scene matches the data (Priority: P1)

The engineer can trust the drawing: the number of atoms and bonds drawn equals the molecule's, bonds end at their atoms'
centres, and the built-in water and ethanol produce exactly their atom counts.

**Why this priority**: the phase's regression fixture.

**Independent Test**: build the scene for water and ethanol; compare counts and bond ends.

**Acceptance Scenarios**:

1. **Given** water and ethanol, **When** their scenes are built, **Then** they hold 3 and 9 atoms and 2 and 8 bonds.
2. **Given** any library molecule, **When** its scene is built, **Then** each bond half runs from its atom's centre to the
   bond's midpoint.

### Edge Cases

- **A molecule saved under the first state schema:** opens with ball-and-stick and the default camera.
- **A single-atom molecule:** no bonds; the framing uses the atom's display radius.
- **A planar molecule (benzene) seen edge-on:** the default view is tilted so it is never edge-on.
- **Zooming far in:** the camera never enters the molecule's bounding sphere (the nearest zoom keeps it outside).
- **Changing the molecule:** the camera returns to the framed default for the new molecule; the mode is kept.
- **Context loss:** every mesh and renderer is rebuilt from the state; the drawing is the same.

## Requirements *(mandatory)*

### Functional Requirements

**Scene (story 3)**

- **FR-A15-201**: The scene of a molecule MUST hold one item per atom (position, element, display radius) and, in
  ball-and-stick, two halves per recorded bond (from each atom's centre to the bond's midpoint, coloured by that atom);
  it is computed without drawing and is the same for the same molecule, mode and camera.
- **FR-A15-202**: Drawing MUST stay within a stated draw budget (at most 1,500 items) and draw exactly the scene's items.

**Display modes (story 1)**

- **FR-A15-210**: Two display modes MUST exist: ball-and-stick (atoms at a stated fraction of their van der Waals radius,
  bonds as sticks of a stated radius) and space-filling (atoms at their van der Waals radius, no bonds), switched by a
  native control and an action, and kept across molecule and camera changes.

**Camera (story 2)**

- **FR-A15-220**: The camera MUST orbit around the molecule's centre: turn in stated steps, tilt within stated limits,
  zoom within stated limits that keep it outside the molecule's bounding sphere, and reset to the framed default; a step
  beyond a limit is refused with a reason.
- **FR-A15-221**: The camera settings MUST be stored in the experience state apart from the molecule data; a state saved
  under schema 1 MUST migrate to the new schema with the default mode and camera.

**Experience (all stories)**

- **FR-A15-230**: Native controls MUST exist for the display mode, turn left and right, tilt up and down, zoom in and out
  and reset view, each with an accessible label and value; the canvas description MUST name the display mode.
- **FR-A15-231**: The scenario manifest MUST gain fixtures for space-filling and for a changed camera, and the runner's
  standard scenarios MUST pass on iOS 27.

### Key Entities

- **Display mode**: ball-and-stick or space-filling.
- **Camera settings**: turn steps, tilt steps, zoom steps (stored), the derived orbit camera.
- **Scene**: atom items (position, element, radius) and bond halves (from, to, element, radius).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A15-201**: Water's and ethanol's scenes hold exactly 3 and 9 atoms and 2 and 8 bonds; 100 % of bond halves of all
  five library molecules end at their atom's centre and the bond midpoint within 1e-9 Å.
- **SC-A15-202**: Both display modes draw a non-blank frame for every library molecule on the iOS 27 simulator, and the
  two modes' frames differ.
- **SC-A15-203**: Every camera step inside its limits changes the drawn frame and keeps the molecule's centre at the
  canvas centre; 100 % of steps beyond a limit are refused.
- **SC-A15-204**: A schema-1 state opens in the new schema with ball-and-stick and the default camera.
- **SC-A15-205**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The UV sphere, the capped tube mesh, the lit mesh renderer with depth and the orbit camera of the A15-P00 contract
  are enough; no VisualCore change is needed (instanced lit meshes are assessed and recorded, not built).
- The bundled molecules are small (at most 24 atoms and 25 bonds), far below the draw budget.

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 MVP: ball-and-stick and space-filling modes | FR-A15-210, SC-A15-202 |
| Regression fixture: built-in water and ethanol produce the expected atom count | FR-A15-201, SC-A15-201 |
| Journey 2: rotate/zoom | FR-A15-220, 230 |
| Algorithm decisions 3 (instancing or batching) and 4 (camera kept apart from molecule data) | FR-A15-202, 221 |
| Contract gaps G-RENDER, G-CAMERA, G-DISPLAY | FR-A15-201–221 |
| EGL/context ownership in the VisualCore host | FR-A15-202 |

## Negative Requirements

- No picking, gestures, panning, labels, bond-order styling or panel in this phase; no second renderer and no
  VisualCore change; no images or textures; no network; no claim that the drawn radii are measured sizes beyond the
  stated display conventions.
