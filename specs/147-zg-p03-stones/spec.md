# Feature Specification: Digital Zen Garden — Phase 03 Stone manipulation and undo

**Feature Branch**: `147-zg-p03-stones` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A20-P03 (legacy ledger) · ID namespace FR-A20-3##, SC-A20-3##, T-A20-3##

**Input**: User description: archived manual `apps/20-digital-zen-garden.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: stone placement, rotation, deletion and layer-aware selection;
  - regression fixture: changing orientation preserves stone positions and stroke paths;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-STONES, G-SELECTION and G-SHADOWS of `docs/apps/digital-zen-garden/visualcore-contract.json`.
- **Experience A20 inside the one app; still a candidate.** Follow `specs/140-lw-p03-editor`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Place, move, rotate and remove stones (Priority: P1) 🎯

A person chooses a stone from the palette and places it on the sand, drags it to another spot, turns it and removes it.
Each stone sits on the sand with a soft shadow. Every change can be undone and redone.

**Why this priority**: the manual's MVP.

**Independent Test**: place a stone, move, rotate and remove it, undoing each step; the garden returns exactly to each
earlier state and the drawn stones follow.

**Acceptance Scenarios**:

1. **Given** an empty tray, **When** a stone is placed, **Then** it is drawn at its position with a shadow, and undo
   removes it.
2. **Given** a placed stone, **When** it is moved, rotated or removed, **Then** the garden changes accordingly and undo
   restores the earlier state exactly.

---

### User Story 2 - Pick the stone that is on top (Priority: P1)

Where stones overlap, a touch selects the topmost one. The selected stone is marked by an outline and a spoken label,
never by colour alone. Native controls select the next or previous stone in layer order.

**Why this priority**: the manual's layer-aware selection.

**Independent Test**: overlap two stones; touch the overlap; the upper one is selected; the native control cycles.

**Acceptance Scenarios**:

1. **Given** two overlapping stones, **When** the overlap is touched, **Then** the upper stone is selected.
2. **Given** a selection, **When** the sand outside every stone is touched, **Then** nothing is selected.

---

### User Story 3 - Turning the device keeps the garden (Priority: P1)

Rotating the device or changing the window size moves nothing in the garden: every stone and stroke keeps its place in
the tray.

**Why this priority**: the manual's regression fixture.

**Independent Test**: draw the same garden in a portrait and a landscape view; compare positions in tray coordinates.

**Acceptance Scenarios**:

1. **Given** a garden with stones and strokes, **When** the view changes from portrait to landscape, **Then** the
   document is unchanged and every stone and stroke maps to the same tray position.

### Edge Cases

- **Placing at the stone cap:** refused with a message; the garden is unchanged.
- **Moving a stone past the tray edge:** clamped inside the tray.
- **Removing the selected stone:** the selection clears.
- **Undo of a removal:** the stone returns at its layer.
- **Raking under a stone:** the stone stays on top; raking does not move it.
- **Reduce Motion:** placing and moving are direct; nothing animates.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A20-301**: A person MUST be able to place any of the five stone kinds, move it, rotate it and remove it, each as
  an undoable command.
- **FR-A20-302**: Stones MUST be drawn as procedural shapes with soft shadows on the sand, in layer order.
- **FR-A20-303**: Selection MUST pick the topmost stone under a touch, clear on empty sand, show an outline and a spoken
  label, and have native controls to cycle through stones in layer order.
- **FR-A20-304**: Gestures MUST map to the same actions as the native controls (place, move, rotate, remove, select).
- **FR-A20-305**: Changing the view's size or orientation MUST leave the document and the tray positions of stones and
  strokes unchanged.
- **FR-A20-306**: Stones MUST be redrawn from the garden after undo, redo, restore, resize and a lost context.

### Key Entities

- **Selection**: the selected stone's id or none.
- **Stone layer**: the drawn stones and shadows, rebuilt from the garden.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A20-301**: Each stone command undone and redone gives a document equal to the one before and after it.
- **SC-A20-302**: In 100% of overlap tests the topmost stone is selected.
- **SC-A20-303**: Portrait and landscape views give the same document and tray positions within one cell.
- **SC-A20-304**: Every test takes under 10 seconds; the runner passes on iOS 27.

## Assumptions

- The stone kinds, commands and history of A20-P01 are reused; the sand renderer of A20-P02 is extended.

## Traceability

| Source | Requirement |
|---|---|
| MVP: placement, rotate, delete, layer-aware selection | FR-A20-301, 303 |
| Regression fixture: orientation preserves stones and strokes | FR-A20-305, SC-A20-303 |
| Manual §6 render stage 3 (stones and soft shadows) | FR-A20-302 |
| Constitution A20 accessibility (every gesture has a control; not colour alone) | FR-A20-303, 304 |
| Contract G-STONES, G-SELECTION, G-SHADOWS | FR-A20-301–306 |

## Negative Requirements

- No image asset, no second renderer, no GL call in the core, no texture snapshot for undo, no network.
