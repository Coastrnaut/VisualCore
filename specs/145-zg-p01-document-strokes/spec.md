# Feature Specification: Digital Zen Garden — Phase 01 Document and stroke math with fixtures

**Feature Branch**: `145-zg-p01-document-strokes` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A20-P01 (legacy ledger) · ID namespace FR-A20-1##, SC-A20-1##, T-A20-1##

**Input**: User description: archived manual `apps/20-digital-zen-garden.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: one tray with visual sand relief, two rake styles and a stone palette (here as data and a reference relief
    computed without the GPU; the drawn relief comes in A20-P02);
  - regression fixture: undo and redo yield an identical command list and a reconstructed sand picture within
    tolerance;
  - graphics context ownership stays solely in the audited VisualCore host (this phase draws nothing).
- **Gaps built here:** G-DOCUMENT, G-STROKES and G-UNDO of `docs/apps/digital-zen-garden/visualcore-contract.json`, as a
  pending core in `Packages/ExperiencesCreative/DigitalZenGarden/Core` until A20-P02 adds the experience.
- **No VisualCore or ProjectM change.** Follow `specs/138-lw-p01-export-contract`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A garden is a small, safe file (Priority: P1) 🎯

A person's garden (the tray, its sand tone, the stones and the rake strokes) is stored as a compact document in tray
coordinates, so it opens the same on any screen. A damaged, newer or oversized file is refused with a reason, and the
garden stays as it was.

**Why this priority**: every later phase stores and rebuilds the garden from this document.

**Independent Test**: round-trip a document; open one sample of each refusal.

**Acceptance Scenarios**:

1. **Given** a garden with strokes and stones, **When** it is saved and opened, **Then** it is identical.
2. **Given** a damaged, newer, oversized or out-of-range file, **When** it is opened, **Then** it is refused with its
   reason and nothing changes.

---

### User Story 2 - A rake stroke follows the finger without gaps (Priority: P1)

A drag becomes a stroke with evenly spaced points, however fast the finger moved, with a cap on the points per stroke.
Two rake styles leave different grooves in the sand.

**Why this priority**: the manual's touch precision and "fast drags have no gaps" rules start in the math.

**Independent Test**: resample a fast, sparse path; compare the spacing; rake a flat tray with each style.

**Acceptance Scenarios**:

1. **Given** a path whose input points are far apart, **When** it is resampled, **Then** no two neighbouring points
   are farther apart than the spacing, and the count stays within the cap.
2. **Given** the two rake styles, **When** each rakes the same stroke, **Then** their grooves differ in width and
   tine count, as their definitions say.

---

### User Story 3 - Undo and redo are exact (Priority: P1)

Every rake stroke and stone placement, rotation or removal is a command. Undo and redo walk the command list, and the
sand rebuilt from the list matches the sand before the undo.

**Why this priority**: the manual's regression fixture; it also avoids storing sand pictures for undo (risk 1).

**Independent Test**: apply a sequence, undo some, redo all; compare the command list and the rebuilt sand.

**Acceptance Scenarios**:

1. **Given** a sequence of commands, **When** all are undone and redone, **Then** the command list is identical and the
   rebuilt sand equals the original within tolerance.
2. **Given** a new command after an undo, **Then** the redo list is cleared.
3. **Given** a history longer than its bound, **Then** the oldest commands fold into a checkpoint, and rebuilding from
   the checkpoint equals rebuilding from the start.

### Edge Cases

- **A path with one point, repeated points or a non-finite value:** a single point is a dab; repeated points are
  dropped; a non-finite point is refused.
- **A point outside the tray:** clamped to the tray edge.
- **Too many strokes or stones:** the command is refused with a reason and the garden stays as it was.
- **Undo with nothing to undo, redo with nothing to redo:** refused without a change.
- **A stone of an unknown kind:** refused.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A20-101**: The garden document MUST hold the tray, the sand tone, the stones and the strokes in normalized tray
  coordinates, be versioned, and round-trip exactly.
- **FR-A20-102**: Opening a document MUST refuse damaged, newer-version, oversized, out-of-range, unknown-kind and
  over-cap content with a reason, without changing the open garden.
- **FR-A20-103**: A stroke MUST be resampled to a uniform spacing with a cap on its points; a fast drag MUST leave no
  gap larger than the spacing.
- **FR-A20-104**: Two rake styles MUST be defined with their own widths, tine counts and depths, and a stone palette
  of at least five procedural stone kinds MUST be defined.
- **FR-A20-105**: Strokes and stone placement, rotation and removal MUST be commands; undo and redo MUST be exact;
  the history MUST be bounded, folding its oldest commands into a checkpoint.
- **FR-A20-106**: A reference sand height field MUST be rebuilt from the command list without the GPU, and the same
  list MUST give the same field.
- **FR-A20-107**: The core MUST make no GPU call, no network request and read no clock.

### Key Entities

- **Garden document**: version, tray, sand tone, stones, strokes.
- **Rake stroke**: points in tray coordinates, rake style.
- **Stone**: kind, position, rotation, scale, depth order.
- **Command and history**: command kinds, undo and redo lists, checkpoint.
- **Reference sand field**: a grid of heights rebuilt from the commands.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A20-101**: 100% of document round trips are exact; one sample of each refusal is refused with its reason.
- **SC-A20-102**: After resampling, 0 neighbouring points are farther apart than the spacing (with a small numeric
  tolerance), and no stroke exceeds its cap.
- **SC-A20-103**: Undoing and redoing a sequence of at least 50 commands gives an identical command list and a rebuilt
  sand field that differs from the original by at most a stated tolerance.
- **SC-A20-104**: Rebuilding from a checkpoint equals rebuilding from the start within the same tolerance.
- **SC-A20-105**: Every core test runs in under 10 seconds.

## Assumptions

- Exact caps, spacing and tolerances are decided in clarification and recorded in the data model.
- The drawn relief, stones and preview come in A20-P02 and A20-P03; this phase is the pure core.

## Traceability

| Source | Requirement |
|---|---|
| MVP: one tray, two rake styles, a stone palette | FR-A20-101, 104, 106 |
| Regression fixture: undo/redo identical list and picture within tolerance | FR-A20-105, 106, SC-A20-103 |
| Manual §6 algorithm 1: resample to uniform spacing, cap samples | FR-A20-103 |
| Manual §6 algorithms 3–4: normalized coordinates, rebuild from the command log, command-based undo | FR-A20-101, 105, 106 |
| Manual risk 1: expensive GPU feedback undo | FR-A20-105 |
| Contract G-DOCUMENT, G-STROKES, G-UNDO | FR-A20-101–106 |

## Negative Requirements

- No VisualCore or ProjectM change; no GPU call, network or clock in the core; no texture snapshot for undo; no
  image asset.
