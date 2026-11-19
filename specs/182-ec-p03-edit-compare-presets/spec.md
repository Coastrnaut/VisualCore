# Feature Specification: Effects Composer — Phase 03 Chain editing, compare and presets

**Feature Branch**: `182-ec-p03-edit-compare-presets` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A25-P03 (legacy ledger) · ID namespace FR-A25-3##, SC-A25-3##, T-A25-3##

**Input**: User description: archived manual `apps/25-effects-composer.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03), binding:**
  - MVP: before and after compare, and preset saves;
  - regression fixture: temporary targets never alias read and write in a pass;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here:** G-EDIT, G-COMPARE and G-PRESETS of `docs/apps/effects-composer/visualcore-contract.json`. The
  manual's later gates move the rest: image import (G-IMPORT with the upstream U-RGBAUPLOAD) is A25-P04's gate and
  still export (G-EXPORT) A25-P05's; the contract's phases are updated in this phase.
- **No VisualCore or ProjectM change.** Follow `specs/169-vpl-p04-graph-library` for the preset library.

## Clarifications

### Session 2026-11-19

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Library precedent:** Visual Programming Lab's `GraphLibrary` (A23-P04) keeps one file per graph and an index in
  `ExperienceStorage` (quota 16 MiB and 64 files), refuses damaged, newer and oversized files with a code, never deletes
  them automatically, makes a newer index read only, and writes atomically through `storage.write`.
- **Pass audit:** `FieldPass.runObserver` (VisualCoreRendering, public, app-wide, set by tests) receives every validated
  run with its label, output texture or framebuffer name and the input texture names.
- **Accessibility actions:** SwiftUI's named accessibility actions on a view; the presenter applies the same core
  actions the buttons send.

- Q: How is compare shown? → A: A core action `view.compare [0…1]` (not stored; a restored session shows the result).
  While on, the present pass draws the source target instead of the result; the result is still drawn when the chain
  changes, so turning compare off shows it at once. A `compare` toggle (identifier `compare`, label "Show original" /
  "Show result") is in the controls; the status says "Original" while on.
- Q: What are the preset files? → A: After `GraphLibrary`: `preset-<n>.json` (envelope `{"body", "kind": "a25.preset",
  "version": 1}`, body `{name, order, chain}` with the chain file's object embedded, at most 69,632 bytes) and
  `presets.json` (envelope kind `a25.preset-library`, version 1, body `{next, entries: [{file, name, order}]}`); at most
  24 presets; a name is trimmed and 1…40 characters; a name another preset has, ignoring case, is refused. Refusal
  codes: `damaged`, `newer-version`, `too-large` and the chain file's codes. Messages: "The library holds 24 presets.",
  "A name has 1 to 40 characters.", "A preset is already called <name>." and "There is not enough space to save this
  preset.". Listed newest first; unreadable files by number after the readable ones.
- Q: How does opening a preset become one undoable edit? → A: The core's `ChainEdit` gains `replace(EffectChain)`, whose
  inverse replaces back the earlier chain; `EditHistory` handles it like every other edit. The presenter's library
  actions (`save(name:)`, `open(file:)`, `rename(file:to:)`, `remove(file:)`) call the library and, for open, apply
  `replace` through the core; the controls show a `presets` list (`preset-row-<n>`, `preset-open-<n>`,
  `preset-remove-<n>`, `preset-name`, `preset-save`) inline, never as a system menu.
- Q: How is the aliasing fixture proved? → A: A test sets `FieldPass.runObserver`, runs 50 edits (every kind, compare
  toggled every 5) with a frame after each, and checks every run: no input texture equals the output, and no output is
  the source target's texture. The pure plan check of A25-P02 (no pass reads its output) stays.
- Q: Which accessibility actions does a node offer? → A: "Move up", "Move down" (absent at the ends), "Turn off" or
  "Turn on", and for each parameter "Raise <name>" and "Lower <name>" (a tenth of the range), listed by the pure
  `ComposerLabels.actions(for:)` and applied through the core's actions; the contract's phases move G-IMPORT and
  U-RGBAUPLOAD to 4 and G-EXPORT to 5 with this phase's contract update.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Compare the look with the original (Priority: P1) 🎯

A person turns compare on and sees the untouched picture; turning it off shows the chain's result again. The
original is never changed by any effect.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: draw with compare on and off; compare the shown pixels with the source and the result.

**Acceptance Scenarios**:

1. **Given** a chain with effects, **When** compare is on, **Then** the shown picture equals the original.
2. **Given** compare is turned off, **When** drawn, **Then** the shown picture equals the chain's result.

---

### User Story 2 - Save a look and open it again (Priority: P1)

A person saves the chain under a name, changes it, and opens the saved look to get it back exactly. Saved looks can
be renamed and removed; a damaged or newer file is listed as unreadable and never deleted automatically.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: save, change, open; rename and remove; read damaged and newer files.

**Acceptance Scenarios**:

1. **Given** a saved look, **When** opened after changes, **Then** the chain equals the saved chain.
2. **Given** a damaged or newer preset file, **When** the presets are listed, **Then** it is shown as unreadable with
   its reason and kept.
3. **Given** the preset cap is reached, **When** another save is tried, **Then** it is refused with a message and
   nothing changes.

---

### User Story 3 - No pass reads what it writes (Priority: P1)

A reviewer audits every pass drawn across many edits and frames, with compare on and off, and finds no pass whose
input is its own output, and the original never written.

**Why this priority**: the manual's regression fixture for this phase.

**Independent Test**: observe every pass of a sequence of edits and frames.

**Acceptance Scenarios**:

1. **Given** 50 edits and frames, **When** every pass is observed, **Then** no pass samples its output and no pass
   writes the original.

---

### User Story 4 - Edit without dragging (Priority: P2)

A person using VoiceOver moves an effect up or down, turns it on or off and changes a value with named actions, and the
preview follows at once.

**Independent Test**: perform the named actions on a node and read the chain and the preview.

**Acceptance Scenarios**:

1. **Given** a chain, **When** the move-up action of the second effect is performed, **Then** it becomes the first and
   the preview redraws.

### Edge Cases

- **Compare with an empty chain:** both views show the original.
- **Saving under an empty or too long name:** refused with a message.
- **A name another preset has** (compared after trimming, ignoring case): refused with "A preset is already called
  <name>."
- **Opening a preset:** becomes one undoable edit of the chain.
- **A context loss with compare on:** the original is uploaded again; compare still shows it.
- **Storage full:** a save is refused with a message and nothing changes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A25-301**: Compare MUST show the untouched original while on and the chain's result while off; no pass may
  write the original.
- **FR-A25-302**: A preset library MUST save the chain under a name, list, open, rename and remove presets, in the
  experience's own storage, with a cap; opening MUST give back the saved chain exactly and be one undoable edit.
- **FR-A25-303**: Preset files MUST be versioned; damaged, newer, oversized and invalid files MUST be listed as unreadable
  with a reason and never opened, rewritten or deleted automatically.
- **FR-A25-304**: An audit of every drawn pass MUST find no pass reading its output and no pass writing the original.
- **FR-A25-305**: Each node MUST offer named accessibility actions to move up and down, turn on or off, and change each
  value, with the preview following at once.
- **FR-A25-306**: Every public name MUST carry documentation; G-EDIT, G-COMPARE and G-PRESETS MUST be closed with
  evidence, and the contract's phases MUST follow the manual's gates.

### Key Entities

- **Compare mode**: on or off; not stored.
- **Preset**: a name, an order, and the chain file.
- **Preset library**: presets in the experience's storage with an index, a cap and refusal reasons.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A25-301**: With compare on, 100% of the shown pixels equal the original; off, they equal the result.
- **SC-A25-302**: A saved and reopened chain is equal with the same fingerprint; 100% of damaged and newer files are
  listed as unreadable and remain byte-identical.
- **SC-A25-303**: 0 passes read their output or write the original across 50 edits and frames.
- **SC-A25-304**: Every node exposes the named actions; each changes the chain as named.
- **SC-A25-305**: Each unit test finishes in under 10 seconds.

## Assumptions

- The preview source is still the built-in test image; imported images are A25-P04.
- Presets hold the chain only (no image).

## Traceability

| Source | Requirement |
|---|---|
| MVP: before and after compare, and preset saves | FR-A25-301, 302, 303 |
| Regression fixture: temporary targets never alias read and write in a pass | FR-A25-304 |
| EGL/context ownership solely in the VisualCore host | FR-A25-301, 304 |
| Brainstorm: preset serialization, effect parameters | FR-A25-302, 305 |
| Contract G-EDIT, G-COMPARE, G-PRESETS | FR-A25-301–306 |

## Negative Requirements

- No VisualCore or ProjectM change; no import or export; no network; no availability to a person; no automatic
  deletion of a stored file.
