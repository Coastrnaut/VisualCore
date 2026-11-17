# Feature Specification: Digital Zen Garden — Phase 04 Persistence, accessibility and still export

**Feature Branch**: `148-zg-p04-library-a11y` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A20-P04 (legacy ledger) · ID namespace FR-A20-4##, SC-A20-4##, T-A20-4##

**Input**: User description: archived manual `apps/20-digital-zen-garden.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):**
  - MVP: undo and redo for strokes and placements (built in A20-P01 and A20-P03; proven here across save and load);
  - regression fixture: memory remains bounded for long gesture histories;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-LIBRARY and G-A11Y of `docs/apps/digital-zen-garden/visualcore-contract.json`, plus a
  still picture of the garden handed to the system share sheet.
- **Experience A20 inside the one app; still a candidate.** Follow `specs/141-lw-p04-save-share`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- Fractal Explorer's `FractalBookmarks` keeps one file per saved item in the experience's `ExperienceStorage` (quota
  16 MiB and 64 files), replacing `NamedLibrary`, whose files sat outside the experience's storage.
- Generative Art Studio shares a still through SwiftUI `ShareLink` with a written file. Its registration declares
  `photo-library-add`, and the app's add-only usage string already exists.
- `GardenHistory` holds at most 100 undoable commands and folds older ones into a checkpoint. A stroke has at most 512
  points, the raw stroke in progress at most 2,048, and the document at most 262,144 bytes.
- The digest covers the document only, and `DigitalZenGardenExperience.make` receives the launch's `storage` (unused
  until now).

- Q: How are named gardens stored? → A: `GardenLibrary`, over the experience's `ExperienceStorage`:
  - **Files:** one file per garden, `garden-<n>.json`, where n is a counter kept in `library.json` (no UUIDs). Each
    holds `{name, order, document}`, with a 262,144-byte cap per file.
  - **Caps:** at most 12 gardens. A name is trimmed and 1…40 characters.
  - **Duplicate names:** saving under an existing name replaces that garden (after the person confirms it in the
    controls); renaming to a used name is refused.
  - **Refusals:** a damaged, newer-version or oversized file is listed as unreadable with its code and never opened or
    deleted automatically. Saving a 13th garden is refused with "The library holds 12 gardens."
  - **Opening:** replaces the garden; the undo history restarts at the opened document.
- Q: What is the bound for long histories? → A:
  - **Undo history:** `GardenHistory` holds at most 100 commands.
  - **Byte bound:** the encoded history (its done and undone lists) stays under 100 × 512 points × 2 coordinates × 24
    bytes ≈ 2.5 MB, an arithmetic bound on its JSON.
  - **Caps:** the document stays within its caps.
  - **Test:** 10,000 seeded commands of every kind. The stroke cap and the stone cap refuse beyond 400 strokes and 24
    stones, and undo of the oldest command never reaches past the checkpoint.
- Q: What is accessible, and how is it checked? → A:
  - **Labels:** every control has a spoken label and value.
  - **Description:** the canvas description says the tone, the number of strokes and stones, and the selected stone.
  - **Announcements:** `port.announce` reports undo and redo ("Undid a stroke", "Redid moving a stone"), save, open,
    delete and a refusal.
  - **Large text:** at the accessibility text sizes the controls stack in one column and wrap, never clipped. A unit
    test renders them with `ImageRenderer` at `.accessibility5` and checks the height grows and the width fits, as
    Living Wallpapers did.
  - **Audits:** system accessibility audits wait for the device campaign.
- Q: What is the still picture, and where does it go? → A:
  - **Picture:** a 1600 × 1200 PNG of the tray drawn by the session's still renderer (`experienceStillRenderer`),
    written to the experience's temporary folder, with at most one file, which a new export or a failure replaces or
    removes.
  - **Sharing:** the file is handed to `ShareLink`. "Save Image" uses the app's add-only string, and the registration
    declares `photo-library-add`.
  - **Photos:** the experience never calls PhotoKit.
- Q: Which controls and actions are added? → A: No new core action. The library and the still are presentation
  features that read and write files. "Open" restores the saved document through the shell's restore path, so the
  digest equals the opened document's and the undo history restarts. The library's buttons (save, open, rename,
  delete) and the share control are native only, with no gestures, so the gesture rule is unaffected.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Keep named gardens (Priority: P1) 🎯

A person saves the current garden under a name, sees it in a list of saved gardens, opens it later, renames it and
deletes it. A damaged or newer saved garden is reported, not opened, and the others still work.

**Why this priority**: the manual's version 0.1 feature 05.

**Independent Test**: save, list, open, rename and delete gardens in a temporary storage; open damaged and newer
samples.

**Acceptance Scenarios**:

1. **Given** a garden, **When** it is saved as "Morning", **Then** "Morning" is listed and opening it restores the
   garden exactly.
2. **Given** a damaged saved garden, **When** the list is read, **Then** it is marked as unreadable and the others
   open.

---

### User Story 2 - Every control can be reached without sight or fine touch (Priority: P1)

Every action has a native control with a spoken label and value; the garden is described in words (strokes, stones,
the selected stone); undo, redo, save and open are announced; the controls stay usable at the largest text size.

**Why this priority**: G-A11Y and the constitution's accessibility rules.

**Independent Test**: list the controls' labels; read the description; render the controls at the largest text size.

**Acceptance Scenarios**:

1. **Given** the experience, **Then** every control has a spoken label, and every gesture action has a control.
2. **Given** the largest text size, **Then** the controls stack and stay within the screen width.

---

### User Story 3 - Long sessions stay small (Priority: P1)

However long a person rakes and moves stones, the memory the garden holds stays bounded.

**Why this priority**: the manual's regression fixture.

**Independent Test**: apply thousands of commands; measure the history's size and the document's size.

**Acceptance Scenarios**:

1. **Given** 10,000 commands, **Then** the undo history holds at most its bound, the document stays within its caps,
   and the encoded history stays under its stated byte bound.

---

### User Story 4 - Share a picture of the garden (Priority: P2)

A person shares a still picture of the garden through the system share sheet, for example to save it.

**Why this priority**: the phase's "export still".

**Independent Test**: export a still; the file has the stated size and is handed to the share sheet.

**Acceptance Scenarios**:

1. **Given** a garden, **When** a still is shared, **Then** a picture of the stated size is written and offered to the
   share sheet, and nothing else is saved.

### Edge Cases

- **A name that is empty, too long or already used:** refused or made unique, as specified.
- **The library at its cap:** saving a new garden is refused with a message; replacing an existing one works.
- **A damaged, newer or oversized saved garden:** reported, never opened, never deleted automatically.
- **Opening a garden:** the undo history restarts.
- **A failed save** (the storage quota reached or a write error): a message; the previous file of that name, if any,
  is unchanged.
- **Deleting the saved garden that is open:** the open garden stays as it is; only the saved copy is removed.
- **A failed still export:** a message; no file is left behind.
- **The person declines saving to Photos:** the share sheet's other destinations still work.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A20-401**: Named gardens MUST be saved, listed, opened, renamed and deleted in the experience's own storage,
  with caps on count, name length and size.
- **FR-A20-402**: Damaged, newer-version and oversized saved gardens MUST be reported and never opened.
- **FR-A20-403**: Every control MUST have a spoken label and value; the garden MUST be described in words; undo, redo,
  save and open MUST be announced; the controls MUST stack at the largest text sizes.
- **FR-A20-404**: The undo history, the stroke in progress and the document MUST stay within stated bounds for any
  number of commands.
- **FR-A20-405**: A still picture of the garden MUST be written at a stated size and handed to the system share sheet,
  with no file left after a failure.
- **FR-A20-406**: No network request, no permission beyond the app's existing add-only Photos string used by the share
  sheet's "Save Image", and no Photos library call by the experience.

### Key Entities

- **Saved garden**: id, name, the document, a modification order.
- **Library**: the list of saved gardens and its caps.
- **Still picture**: a file of the garden at a stated size.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A20-401**: 100% of save-and-open round trips are exact; one sample of each refusal is reported.
- **SC-A20-402**: After 10,000 commands the history holds at most 100 commands and stays under its byte bound.
- **SC-A20-403**: 100% of controls have spoken labels; at the largest text size no control is clipped.
- **SC-A20-404**: Every test takes under 10 seconds; the runner passes on iOS 27.

## Assumptions

- The caps, the still size and the byte bound are those of the clarifications.

## Traceability

| Source | Requirement |
|---|---|
| MVP: undo/redo for strokes and placements | FR-A20-401 (across save and open), FR-A20-404 |
| Regression fixture: memory bounded for long histories | FR-A20-404, SC-A20-402 |
| Version 0.1 feature 05: save and load named gardens | FR-A20-401, 402 |
| Phase 04 title: accessibility and export still | FR-A20-403, 405 |
| Contract G-LIBRARY, G-A11Y | FR-A20-401–403 |

## Negative Requirements

- No network, no account, no Photos library call by the experience, no image asset, no texture snapshot for undo.
