# Feature Specification: Living Wallpapers — Phase 03 Project and preset editing and crop interface

**Feature Branch**: `140-lw-p03-editor` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A19-P03 (legacy ledger) · ID namespace FR-A19-3##, SC-A19-3##, T-A19-3##

**Input**: User description: archived manual `apps/19-living-wallpapers.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: still-image export in common formats with a verified colour profile, now shown to the person in the editor;
  - regression fixture: a size the device cannot render shows a clear fallback;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here** (`docs/apps/living-wallpapers/visualcore-contract.json`):
  - G-EDITOR: project and preset editing, the template picker and the crop interface (app-local);
  - G-HELP: how to apply a saved image through the system's own controls (app-local);
  - G-A11Y: labels, large text and announcements for the editor and the export result (app-local).
- **Experience A19 inside the one app:** still a candidate. Visuals are code.
- Follow `specs/133-ac-p03-themes-favourites`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Make the colours my own (Priority: P1) 🎯

A person starts from a preset and changes any of its four colours, or resets them, and the scene, the preview and the
export follow; the edited colours are kept with the project.

**Why this priority**: "preset editing", the phase's deliverable.

**Independent Test**: edit each colour slot, reset, save and restore; compare pictures.

**Acceptance Scenarios**:

1. **Given** a preset, **When** a colour slot is changed, **Then** the picture changes, the colour is opaque, and the
   change is a recorded action.
2. **Given** edited colours, **When** the preset is reset or another preset or scene is chosen, **Then** the preset's
   own colours return.
3. **Given** a project saved before colours could be edited, **When** it is opened, **Then** it opens with its preset's
   colours and nothing else changes.

---

### User Story 2 - A clear answer when the size will not fit (Priority: P1)

A person who picks a template larger than the device can render sees, before exporting, a plain message naming the
template's size, the device's limit and the size that will be used instead, and can export at that size.

**Why this priority**: the manual's regression fixture.

**Independent Test**: plan exports for each template at limits of 2048, 4096 and 8192; read the notice and the
offered size.

**Acceptance Scenarios**:

1. **Given** a template that fits, **Then** no notice is shown.
2. **Given** one that does not, **Then** the notice names the template's pixel size, the limit and the offered size,
   and exporting uses the offered size.

---

### User Story 3 - Know what was made and how to use it (Priority: P1)

After an export the person sees the file's format, its exact pixel size and its colour profile as read from the file,
and can open help that explains how to make it their wallpaper through the system's own Settings or Photos controls.

**Why this priority**: the MVP made visible and the G-HELP gap.

**Independent Test**: export; read the result line; open the help; scan its words.

**Acceptance Scenarios**:

1. **Given** a finished export, **Then** the result names format, width × height and "sRGB" from the read-back file.
2. **Given** the help, **Then** it describes the system's own steps and never claims the app sets the wallpaper.

---

### User Story 4 - Usable by everyone (Priority: P2)

A VoiceOver user hears a label for every control and hears the export's result once; at the largest text size the
controls stay usable.

**Why this priority**: the G-A11Y gap.

**Independent Test**: list every control's label; trigger an export and count announcements; lay the controls out
at the largest text size.

**Acceptance Scenarios**:

1. **Given** the controls, **Then** each has a non-empty spoken label naming its purpose and value.
2. **Given** an export finishes or fails, **Then** exactly one announcement is made, at a bounded rate.

### Edge Cases

- **A colour slot outside 0…1 or with transparency:** refused; the picture is unchanged.
- **A limit of 0 (no picture open):** the notice says the export is not possible yet, with no offered size.
- **Reduce Motion:** the editor's live preview is still; edits still apply.
- **A project or snapshot from a newer version:** refused with a named reason; the defaults stay.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A19-301**: A person MUST be able to change each of the four colours of the chosen preset, keep them with the
  project and the snapshot, and reset them; older saved projects and snapshots MUST open with their preset's colours.
- **FR-A19-302**: The template picker, orientation and crop frame MUST stay together in the editor, and the fallback
  notice MUST name the template size, the limit and the offered size, with export at the offered size.
- **FR-A19-303**: The export result MUST show the format, the exact pixel size and the colour profile read back from
  the written file.
- **FR-A19-304**: Help MUST explain how to apply a saved image through the system's own controls, reachable from the
  editor and the export result, and MUST contain no claim that the app sets or installs a wallpaper.
- **FR-A19-305**: Every control MUST carry a spoken label with its value; the export's outcome MUST be announced once
  at a bounded rate; the controls MUST stay usable at the largest text size.
- **FR-A19-306**: The GPU context stays in the host; no GL, wallpaper or Photos call in the experience.

### Key Entities

- **Custom colours**: four opaque colours overriding the preset, or none.
- **Fallback notice**: template size, limit, offered size, sentence.
- **Export result line**: format, width, height, profile.
- **Help text**: steps, statements, no claims.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A19-301**: Each of the four colour slots changes the picture; a reset returns the preset's pixels exactly; a
  schema-1 project and snapshot open unchanged except for the new fields' defaults.
- **SC-A19-302**: For limits of 2048, 4096 and 8192, every template above the limit gets a notice with the three
  numbers; every template that fits gets none.
- **SC-A19-303**: 100% of controls have a non-empty label; one announcement per export outcome.
- **SC-A19-304**: The help and the editor's words contain none of the refused claims (the platform scan passes).
- **SC-A19-305**: Unit tests run under 10 seconds each.

## Assumptions

- The share sheet, the export job with progress and the history come in A19-P04; this phase writes only the temporary
  file of A19-P02.

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 deliverable: project and preset editing, crop interface | FR-A19-301, 302 |
| MVP: still export with verified colour profile | FR-A19-303 |
| Regression fixture: unsupported sizes show a clear fallback | FR-A19-302, SC-A19-302 |
| Gate: context ownership in the host | FR-A19-306 |
| Contract G-EDITOR, G-HELP, G-A11Y | FR-A19-301–305 |
| Brainstorm journey 2: personalize palette and preview safe crop | FR-A19-301, 302 |

## Negative Requirements

- No claim that the app sets, installs or animates the system wallpaper; no GL, Photos or wallpaper call; no network;
  no purchased, generated or photographic image.
