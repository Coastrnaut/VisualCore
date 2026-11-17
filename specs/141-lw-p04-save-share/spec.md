# Feature Specification: Living Wallpapers — Phase 04 Save, share and permission paths

**Feature Branch**: `141-lw-p04-save-share` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A19-P04 (legacy ledger) · ID namespace FR-A19-4##, SC-A19-4##, T-A19-4##

**Input**: User description: archived manual `apps/19-living-wallpapers.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):**
  - MVP: a short optional loop export only after encoder and resource feasibility is shown. A19-P01 recorded the
    no-go for version 0.1 (`docs/apps/living-wallpapers/video-decision.md`), so this gate is met by the decision and
    its guard scan staying green: nothing of the kind is added;
  - regression fixture: sharing works without broad Photos library permission;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here** (`docs/apps/living-wallpapers/visualcore-contract.json`):
  - G-SAVE: the written file handed to the system share sheet; "Save Image" uses the app's add-only string, and the
    registration declares `photo-library-add`;
  - G-EXPORTJOB: the export runs as a job with progress, cancellation between steps, error recovery and cleanup;
  - G-HISTORY: a bounded local history of exports.
- **Experience A19 inside the one app:** still a candidate.
- Follow `specs/134-ac-p04-night-power`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Keep the image where I want it (Priority: P1) 🎯

After an export the person opens the system share sheet with the file and saves it to Photos, puts it in Files or
hands it to another app, without the experience ever asking for access to their whole photo library.

**Why this priority**: the deliverable and the regression fixture.

**Independent Test**: export; read what the share control hands over; check the declared permission and that no
library access code exists.

**Acceptance Scenarios**:

1. **Given** a written export, **Then** the share control offers that file, with its image type and a readable name.
2. **Given** the app's permissions, **Then** the only Photos permission is the add-only one, and the experience never
   asks for read access or calls the library itself.
3. **Given** no written export, **Then** no share control is offered.

---

### User Story 2 - Exports never freeze or leave a mess (Priority: P1)

A person sees the export's progress, can cancel it, and if it fails is told why and can try again; nothing is left
behind after a cancel or a failure, and the live picture keeps running.

**Why this priority**: G-EXPORTJOB.

**Independent Test**: run the job; cancel at each step; force failures; count leftover files and GPU resources.

**Acceptance Scenarios**:

1. **Given** an export, **Then** progress rises through its steps to 1 on success.
2. **Given** a cancel at any step, **Then** the job stops, no temporary file and no export GPU resource remain, and the
   live picture renders.
3. **Given** a failure, **Then** the reason is named and a retry is offered.

---

### User Story 3 - See what I made before (Priority: P2)

A person sees a short list of their recent exports (scene, device, format, size and when) that survives closing the
app, and can clear it.

**Why this priority**: G-HISTORY.

**Independent Test**: export several times; reopen; check order, bound and clearing; open a damaged history.

**Acceptance Scenarios**:

1. **Given** exports, **Then** the history lists the newest first and keeps at most its bound.
2. **Given** a damaged or newer history file, **Then** it is reported and the experience opens with an empty history.

### Edge Cases

- **Photos access declined in the share sheet:** only that destination fails; Files and other apps still work.
- **The temporary file was removed** (by the system or a new export): the share control disappears; the history entry
  stays.
- **A cancel during the encode:** the job stops at the next step boundary and cleans up.
- **The history at its bound:** the oldest entry is dropped.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A19-401**: A written export MUST be offered to the system share sheet as a file of its image type; nothing is
  saved anywhere without the person's choice in the sheet.
- **FR-A19-402**: The experience MUST declare only the add-only Photos permission and MUST NOT read the photo library
  or call it directly; the app's usage descriptions MUST stay exactly the declared set.
- **FR-A19-403**: An export MUST run as a job with progress per step, cancellation between steps, named failures with
  retry, and cleanup of its file and GPU resources on every path; the interface stays responsive.
- **FR-A19-404**: A bounded history of exports MUST be kept in the experience's own storage, newest first, clearable,
  with damaged or newer files reported, not fatal.
- **FR-A19-405**: The short-loop decision of A19-P01 MUST stay recorded and its guard scan green.
- **FR-A19-406**: The GPU context stays in the host; no GL, wallpaper or Photos library call in the experience.

### Key Entities

- **Share item**: the written file and its type.
- **Export job**: steps, progress, state, failure reason.
- **History entry**: scene, device template, orientation, format, width, height, time made.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A19-401**: 100% of written exports are offered for sharing with the right type; 0 library-access calls in the
  sources; the usage-description check passes with the add-only key declared.
- **SC-A19-402**: Progress reaches 1 on every successful export; after a cancel at each step and after each failure,
  leftover files and export GPU resources are 0.
- **SC-A19-403**: The history keeps the newest entries up to its bound, round-trips exactly, and a damaged file gives
  an empty history and one reported problem.
- **SC-A19-404**: The platform scan stays green; unit tests run under 10 seconds each.

## Assumptions

- The share sheet's own "Save Image" is the system's; the experience only provides the file.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 deliverable: save, share and permission paths | FR-A19-401, 402 |
| MVP: short loop only after feasibility (no-go recorded) | FR-A19-405 |
| Regression fixture: share without broad photo permission | FR-A19-401, 402, SC-A19-401 |
| Gate: context ownership in the host | FR-A19-406 |
| Contract G-SAVE, G-EXPORTJOB, G-HISTORY | FR-A19-401–404 |
| Brainstorm journey 3: export to Photos or Files with explicit permission | FR-A19-401, 402 |

## Negative Requirements

- No photo library read or direct save; no loop or movie export; no network; no account; no wallpaper call; no
  purchased, generated or photographic image.
