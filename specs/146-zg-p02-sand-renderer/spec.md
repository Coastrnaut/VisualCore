# Feature Specification: Digital Zen Garden — Phase 02 Sand and rake renderer

**Feature Branch**: `146-zg-p02-sand-renderer` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A20-P02 (legacy ledger) · ID namespace FR-A20-2##, SC-A20-2##, T-A20-2##

**Input**: User description: archived manual `apps/20-digital-zen-garden.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):**
  - MVP: continuous multi-sample touch strokes and a brush preview;
  - regression fixture: fast drags have no gaps after resampling;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-SAND, G-RELIEF and G-PREVIEW of `docs/apps/digital-zen-garden/visualcore-contract.json`. The
  experience target is added in `Packages/ExperiencesCreative/DigitalZenGarden/Experience` and registered as a
  candidate (not available until X-A20).
- **Experience A20 inside the one app.** Follow `specs/139-lw-p02-still-renderer`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Rake the sand by dragging (Priority: P1) 🎯

A person opens Digital Zen Garden and sees a tray of softly lit sand. Dragging a finger rakes grooves along the path,
however fast the finger moves; lifting the finger finishes the stroke. Undo and redo controls remove and restore the
last stroke.

**Why this priority**: the manual's MVP and its regression fixture.

**Independent Test**: send a fast, sparse drag through the experience; the stroke the core stores has no gap larger
than the spacing, and the drawn sand changes along the whole path.

**Acceptance Scenarios**:

1. **Given** a fresh garden, **When** a drag crosses the tray in a few far-apart events, **Then** the stored stroke has
   evenly spaced points and the drawn grooves follow the whole path.
2. **Given** a raked garden, **When** undo is used, **Then** the last stroke disappears from the sand; redo restores it.

---

### User Story 2 - See where the rake will touch (Priority: P1)

While a finger rests or moves on the tray, a preview outline shows the rake's width and its tines at the finger, in the
chosen rake style.

**Why this priority**: the manual's MVP brush preview.

**Independent Test**: start a drag; the preview appears at the finger with the style's width; lifting the finger
removes it.

**Acceptance Scenarios**:

1. **Given** a touch on the tray, **Then** the preview shows the rake's width and tine count at the touch.
2. **Given** the other rake style chosen, **Then** the preview changes to its width and tine count.

---

### User Story 3 - The sand stays when the screen changes (Priority: P2)

The sand is rebuilt from the garden after a size change, a rotation or a lost graphics context, and it looks the same.

**Why this priority**: the constitution's rebuild rule; the picture is never the only copy of the garden.

**Independent Test**: rake, resize or recreate the context, compare the drawn sand with a fresh replay.

**Acceptance Scenarios**:

1. **Given** a raked garden, **When** the drawing context is recreated, **Then** the sand matches the garden's replay.

### Edge Cases

- **A touch outside the tray:** ignored until it enters the tray; positions are clamped to the tray edge while
  raking.
- **A second finger:** ignored while one finger rakes.
- **A stroke at its point cap:** it ends there; the next drag starts a new stroke.
- **The garden at its stroke cap:** a new drag is refused, the garden is unchanged and a short message says so.
- **No half-float drawing support:** the sand uses the 8-bit fallback and still draws.
- **Reduce Motion:** nothing animates on its own; raking is direct.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A20-201**: The experience MUST turn a drag into a stroke whose points are evenly spaced within the spacing, sent
  to the core in pieces, and commit it when the finger lifts.
- **FR-A20-202**: The sand MUST be drawn as lit relief from a height field into which the strokes are raked in order,
  with the two rake styles' grooves.
- **FR-A20-203**: The sand MUST be rebuilt from the garden after undo, redo, restore, resize and a lost context, and the
  rebuilt sand MUST match the core's reference field within a stated tolerance.
- **FR-A20-204**: A brush preview MUST show the chosen rake's width and tines at the touch while a finger is down.
- **FR-A20-205**: Native controls MUST choose the rake style and undo and redo, each with a spoken label.
- **FR-A20-206**: The experience MUST be registered as a candidate with its scenarios, and make no GL call outside the
  host's scenes, no network request and no clock read in its core.

### Key Entities

- **Stroke in progress**: the points received so far and the rake style.
- **Sand target**: the drawn height field, rebuilt from the garden.
- **Brush preview**: the rake outline at the touch.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A20-201**: A drag of at least three far-apart events gives a stored stroke with 0 gaps larger than the spacing.
- **SC-A20-202**: The drawn height field matches the core's reference field within the stated tolerance.
- **SC-A20-203**: After a context recreation, the drawn sand is identical to the drawing before it.
- **SC-A20-204**: Every test takes under 10 seconds; the verification runner passes on iOS 27.

## Assumptions

- Stones, their shadows and selection come in A20-P03; named gardens and accessibility in A20-P04.
- The tolerance and the target size are decided in clarification.

## Traceability

| Source | Requirement |
|---|---|
| MVP: continuous multi-sample touch strokes and brush preview | FR-A20-201, 204 |
| Regression fixture: fast drags have no gaps after resampling | FR-A20-201, SC-A20-201 |
| Manual §6 render sequence stages 1–2 (replay, process touch, update height) | FR-A20-202, 203 |
| Manual §6 rendering lifecycle (rebuild after context loss and resize) | FR-A20-203 |
| Contract G-SAND, G-RELIEF, G-PREVIEW | FR-A20-201–204 |

## Negative Requirements

- No second renderer or EGL path, no GL call in the core, no texture snapshot for undo, no image asset, no network.
