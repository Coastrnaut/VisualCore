# Feature Specification: Molecular Explorer — Phase 03 Selection and display styles

**Feature Branch**: `112-me-p03-selection` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A15-P03 (legacy ledger) · ID namespace FR-A15-3##, SC-A15-3##, T-A15-3##

**Input**: User description: archived manual `apps/15-molecular-explorer.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — touch orbit, pan, zoom and atom picking; regression fixture — atom
  selection is correct for camera transforms and the occlusion policy; graphics context ownership stays solely in the
  audited VisualCore host.
- **Gaps built here** (contract `docs/apps/molecular-explorer/visualcore-contract.json`): G-PICK (atom picking, the
  selection and its control alternative) and G-PANEL (element labels, bond-order styles with inferred bonds marked, the
  metadata panel and the spoken wording), plus the canvas gestures and panning moved here from A15-P02. The persisted
  library, recent molecules and settings stay for A15-P04; the import and data review for A15-P05.
- **Experience:** the candidate grows; no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A15; every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Touch the molecule (Priority: P1) 🎯

A person drags on the molecule to turn and tilt it, pinches to zoom, moves two fingers to pan it, and taps an atom to
select it; the same things can be done with buttons.

**Why this priority**: the phase's MVP and the manual's second journey ("rotate/zoom, select an atom").

**Independent Test**: play synthetic touches over the canvas and compare the state with the same changes made by
buttons.

**Acceptance Scenarios**:

1. **Given** a molecule, **When** a finger drags across the canvas, **Then** the camera turns and tilts in steps, as the
   buttons would.
2. **Given** a molecule, **When** two fingers spread, pinch or move together, **Then** the camera zooms or pans in steps
   within its limits.
3. **Given** a molecule, **When** an atom is tapped, **Then** it is selected; **When** empty space is tapped, **Then**
   the selection is cleared.

---

### User Story 2 - The right atom is picked (Priority: P1)

The engineer can trust selection: from any camera position, tapping where an atom is drawn selects that atom, and where
atoms overlap on screen the one nearest the viewer wins.

**Why this priority**: the phase's regression fixture.

**Independent Test**: for each library molecule and a set of camera positions, tap each atom's projected centre and
compare with the nearest atom along that line of sight.

**Acceptance Scenarios**:

1. **Given** any camera position, **When** the projected centre of a visible atom is tapped, **Then** that atom is
   selected unless a nearer atom covers that point, in which case the nearer atom is selected.
2. **Given** either display mode, **When** atoms are picked, **Then** the drawn atom size of that mode is used.

---

### User Story 3 - Read the molecule (Priority: P2)

A person sees element symbols beside the atoms, sees double and triple bonds drawn differently from single bonds and
inferred bonds drawn as estimates, and reads a panel about the selected atom: its element, number, position, radii and
its bonds; VoiceOver speaks the same.

**Why this priority**: the manual's journey ("view element metadata") and the v0.1 feature "element labels, bond types
and metadata panel".

**Independent Test**: select atoms; read the overlay, the panel and the canvas description.

**Acceptance Scenarios**:

1. **Given** a molecule, **When** labels are placed, **Then** no two labels overlap and atoms off the canvas get none.
2. **Given** caffeine in ball-and-stick, **When** it is drawn, **Then** its double bonds look different from its single
   bonds without relying on colour.
3. **Given** a selected atom, **When** the panel is read, **Then** it names the element, the atom's place in the
   molecule, its position, its radii and each bond with its order and whether it was recorded or inferred.

### Edge Cases

- **A tap that hits nothing:** clears the selection; a tap during a drag or pinch is not a tap.
- **Very small or fast gestures:** movements below the step threshold send nothing; large movements send several steps.
- **Overlapping atoms on screen:** the atom nearest the viewer along the tap's line of sight is picked.
- **A selected atom behind others:** stays selected and is still marked; its label is shown first.
- **Changing the molecule:** clears the selection and resets the camera, pan included; the mode is kept.
- **Changing the mode:** keeps the selection and the camera.
- **Panning at a limit:** a further step is refused with a reason.
- **An inferred bond:** shown thinner and named "inferred" in the panel; never given an order other than single.
- **A state saved under schema 2:** opens with no selection and no pan.

## Requirements *(mandatory)*

### Functional Requirements

**Gestures (story 1)**

- **FR-A15-301**: A one-finger drag MUST turn and tilt the camera in its steps, a two-finger pinch MUST zoom in its steps
  and moving the two fingers' midpoint MUST pan in stated steps; a tap MUST pick; each gesture result MUST also be
  reachable by a native control.
- **FR-A15-302**: Panning MUST move the camera's target within stated limits; a step beyond a limit is refused with a
  reason; reset view returns the pan to zero.

**Picking (story 2)**

- **FR-A15-310**: A tap MUST select the atom whose drawn sphere the line of sight through the tapped point meets first;
  a miss clears the selection; selection works in both modes with their drawn sizes and survives a mode change.
- **FR-A15-311**: Native controls MUST select the previous and the next atom in atom order and clear the selection.

**Reading (story 3)**

- **FR-A15-320**: Element symbols MUST be shown beside the atoms without overlapping, the selected atom first, then
  nearer atoms before farther ones; atoms off the canvas get no label; the selected atom is marked on the canvas.
- **FR-A15-321**: In ball-and-stick, double and triple bonds MUST be drawn as two and three parallel sticks and inferred
  bonds as a thinner stick, so bond order and provenance never depend on colour alone.
- **FR-A15-322**: A metadata panel MUST show, for the selected atom, the element name and symbol, the atom's number in
  the molecule, its position in ångström, its covalent and van der Waals radii and each of its bonds with the bonded
  atom, the order and "recorded" or "inferred"; the canvas description MUST name the selected atom.
- **FR-A15-323**: Each user action MUST produce at most one announcement, and a selection change MUST be announced.

**State and experience**

- **FR-A15-330**: The experience state MUST hold the pan and the selected atom apart from the molecule data (schema 3);
  a schema-2 state MUST migrate with no selection and no pan.
- **FR-A15-331**: The scenario manifest MUST gain fixtures for a picked atom and a panned view, and the runner's standard
  scenarios MUST pass on iOS 27.

### Key Entities

- **Selection**: the selected atom index, or none.
- **Pan**: horizontal and vertical pan steps.
- **Pick**: a line of sight from the camera through a canvas point and the first atom it meets.
- **Label**: element symbol, canvas point, box.
- **Bond style**: number of parallel sticks and stick radius from the order and the provenance.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A15-301**: For all five molecules, both modes and at least eight camera positions, tapping each atom's projected
  centre selects the nearest atom along that line of sight in 100 % of cases; tapping empty corners clears the selection.
- **SC-A15-302**: Synthetic drags, pinches and two-finger moves produce the same states as the equivalent buttons.
- **SC-A15-303**: No two placed labels overlap in any library molecule at the default view; caffeine's four double
  bonds are drawn with two sticks each.
- **SC-A15-304**: The panel and canvas description name the selected atom, its element and its bonds; a schema-2 state
  opens in schema 3 with no selection.
- **SC-A15-305**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The gesture recognizers and arbiter, ray casts against spheres, the orbit camera's rays and the host's canvas
  overlay slot of the A15-P00 contract and A14 are enough; no VisualCore change.
- Bond picking is not part of version 0.1.

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 MVP: touch orbit, pan, zoom and atom picking | FR-A15-301, 302, 310 |
| Regression fixture: selection correct for camera transforms and occlusion | FR-A15-310, SC-A15-301 |
| v0.1 feature: element labels, bond types and metadata panel | FR-A15-320–322 |
| Algorithm decision 4: CPU ray-to-sphere picking; camera kept apart from molecule data | FR-A15-310, 330 |
| Domain rule: inferred bonds never presented as measured | FR-A15-321, 322 |
| Contract gaps G-PICK, G-PANEL | FR-A15-310–323 |
| EGL/context ownership in the VisualCore host | FR-A15-320 |

## Negative Requirements

- No bond picking, measurement tools, persisted library or settings, import or network in this phase; no information
  carried by colour alone; no VisualCore change.
