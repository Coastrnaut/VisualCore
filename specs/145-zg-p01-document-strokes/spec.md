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

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `Vec2` (VisualCoreMath) is `Codable`, `Hashable` and `Sendable`. `ExperienceControl.maxValues` is 24, so A20-P02 sends
  a stroke to the core in segments. `ExperienceSnapshot` allows 1 MiB and `StorageQuota` 16 MiB and 64 files.
- The only undo in the repository is Light Maze's experience-local `MazeState.undo()`; no VisualCore product offers a
  command history (contract G-UNDO).
- Earlier pending cores (Living Wallpapers, Ambient Clock) were added as `<Name>Core` and `<Name>CoreTests` targets
  in `Packages/ExperiencesCreative/Package.swift`.

- Q: What is the tray, and how are positions stored? → A: One tray, `small-tray`, with a 4:3 aspect. Positions are
  normalized: x in 0…1 across the width, y in 0…1 down the height. Distances are measured in tray-width units, with y
  scaled by 0.75. There are three sand tones (`pale`, `warm`, `grey`), each an opaque sRGB colour. The reference sand
  field is 160 × 120 cells (1/160 of the width per cell). Heights are in units of the deepest groove (−1…1); untouched
  sand is 0.
- Q: What are the caps and the resampling rule? → A:
  - **Resampling:** points every 0.004 tray widths, linearly along each segment. Repeated points (closer than 1e-6)
    are dropped, points outside the tray are clamped to its edge, and a non-finite point refuses the stroke.
  - **Caps:** 512 points per stroke; a longer stroke ends at the cap and is marked capped. A garden holds at most 400
    strokes and 24 stones, and the document is at most 262,144 bytes.
  - **Dabs:** a stroke of one point is a dab.
  - **Tolerance:** neighbouring points are at most the spacing plus 1e-9 apart.
- Q: What are the two rake styles and the stone palette? → A:
  - **Rake styles:**
    - `fine-rake`: 5 tines, 0.06 tray widths wide, depth 0.6;
    - `wide-rake`: 3 tines, 0.10 tray widths wide, depth 1.0.

    The groove profile across a rake is depth·cos(2π·tines·u/width) for |u| ≤ width/2 (u being the signed distance
    from the stroke's centre line), giving alternating grooves and ridges. Raking replaces the height under its
    footprint rather than adding to it, so later strokes overwrite earlier ones in order.
  - **Stone palette:** five kinds, `river-pebble`, `flat-slate`, `round-granite`, `tall-basalt` and `moss-boulder`,
    each a procedural shape with base radii in tray widths. A stone has an id, kind, position (0…1), rotation (−π…π),
    scale (0.5…2) and a depth order. Stones sit on the sand and do not change its heights in this phase.
- Q: What are the commands and the history? → A:
  - **Commands:** `rake(stroke)`, `place(stone)`, `move(id, position)`, `rotate(id, angle)`, `remove(id)` and
    `tone(tone)`. Each command records what it needs to be undone exactly: `remove` keeps the removed stone and its
    depth order.
  - **Undo and redo:** they move commands between the two lists; a new command clears the redo list.
  - **History:** at most 100 undoable commands. Beyond that, the oldest command folds into the checkpoint, which is a
    document plus its reference field.
  - **Rebuilding:** the field is rebuilt from the checkpoint by replaying the commands. The CPU replay is exact, so
    the stated tolerance is a height difference of at most 1e-6 per cell.
  - **Ids and time:** stone ids are assigned from a counter in the document. No time is stored: there are no
    timestamps, and the core reads no clock.
- Q: Where does the core live, and what does it depend on? → A: `Packages/ExperiencesCreative/DigitalZenGarden/Core`
  as target `DigitalZenGardenCore` (dependencies `VisualCoreMath` and `VisualCoreExperience`), with
  `DigitalZenGardenCoreTests`. It is a pending core until A20-P02 adds the experience, and nothing is registered.

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

- The caps, spacing and tolerances of the clarifications are recorded in the data model.
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
