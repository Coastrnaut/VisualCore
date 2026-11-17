# Feature Specification: Living Wallpapers — Phase 01 Platform API and export contract verification

**Feature Branch**: `138-lw-p01-export-contract` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A19-P01 (legacy ledger) · ID namespace FR-A19-1##, SC-A19-1##, T-A19-1##

**Input**: User description: archived manual `apps/19-living-wallpapers.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: curated procedural backgrounds and colour presets;
  - regression fixture: exported image dimensions and colour profile match the selected template;
  - graphics context ownership stays solely in the audited VisualCore host (this phase draws nothing on screen).
- **Gaps built here** (`docs/apps/living-wallpapers/visualcore-contract.json`):
  - G-MODEL: the project model, export requests and results with their validation (app-local);
  - G-TEMPLATES: iPhone and iPad templates with a provenance record, fitted to the reported size limit and the pixel
    cap with the largest fitting fallback (app-local);
  - G-VIDEO: the video feasibility decision, recorded with its public API, cost and owner.
- **Smallest vertical slice:** the experience's model is pure data tested without a GPU. The drawn scenes, the
  experience target, the registration and the catalog entry come in A19-P02, so nothing appears in the app now.
- Follow `specs/131-ac-p01-clock-a11y`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A curated background to start from (Priority: P1) 🎯

A person opening Living Wallpapers chooses from a small curated set of procedural backgrounds, each with a few colour
presets, and the choice is kept in a project they can come back to.

**Why this priority**: the manual's MVP requirement for this phase.

**Independent Test**: list the curated scenes and presets; build, save and reopen a project document.

**Acceptance Scenarios**:

1. **Given** the curated catalog, **Then** every scene has a stable id, a name, its parameters with ranges, and at
   least three colour presets, each colour opaque.
2. **Given** a project (scene, preset, seed, template, animation time), **When** it is saved and read back, **Then**
   it is equal; **Given** a damaged, oversized or newer file, **Then** it is refused with a named reason and the
   defaults stay.

---

### User Story 2 - The exported file is exactly the size asked for (Priority: P1)

A person picking "iPhone 16 Pro, portrait" gets a file of exactly that screen's pixel size, tagged with the colour
profile the app states, so it fits the screen without scaling.

**Why this priority**: the manual's regression fixture and the main validity risk (wrong sizes, wrong colours).

**Independent Test**: plan an export for each template; encode a picture of that size through the existing still
encoder; read the written file's dimensions and colour profile back.

**Acceptance Scenarios**:

1. **Given** a template, **When** an export is planned, **Then** the planned size is the template's pixel size and
   the file's read-back dimensions and colour profile equal the plan.
2. **Given** a reported size limit or pixel cap smaller than the template, **When** an export is planned, **Then** it
   is refused before anything is allocated and offers the largest fitting size with the same aspect.
3. **Given** every template, **Then** it records where its size and safe areas come from.

---

### User Story 3 - No promise the platform cannot keep (Priority: P2)

A person never sees a control or text that suggests the app sets the wallpaper itself, makes a live wallpaper, or
exports video, unless a recorded decision shows that to be possible with public means.

**Why this priority**: the manual's main validity risk and the G-VIDEO decision.

**Independent Test**: read the decision record; scan the experience's sources for video encoders and copy.

**Acceptance Scenarios**:

1. **Given** the video decision, **Then** it names the public interface assessed, its cost bounds, the owner and
   the result.
2. **Given** the experience's sources, **Then** no video encoder, system-wallpaper call or live-wallpaper wording
   appears unless the decision is go.

### Edge Cases

- **A template larger than the device can render:** refused before allocation, with the largest fitting size offered
  (even dimensions, same aspect); a limit of 0 (no context yet) refuses every export with a named reason.
- **A preset colour with transparency:** refused by the catalog's own check; exported pictures are opaque.
- **A project naming a scene, preset or template that no longer exists:** refused with a named reason, defaults kept.
- **Landscape and portrait:** each template has both orientations with the edges swapped.
- **Animation time:** a project's time is finite and non-negative; the same project and time always plan the same
  export.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A19-101**: The curated catalog MUST hold a fixed set of procedural scenes, each with a stable id, a name,
  parameters with ranges and defaults, and at least three opaque colour presets, with a license and provenance
  record.
- **FR-A19-102**: A project document MUST record scene, preset, seed, template, orientation and animation time in a
  versioned file with typed refusals (damaged, newer version, unknown scene, preset or template, too large); a
  refused file leaves the defaults.
- **FR-A19-103**: The template catalog MUST hold iPhone and iPad screen sizes in pixels with both orientations and
  safe-area guides, each with a provenance record.
- **FR-A19-104**: Export planning MUST turn a project and a format into an exact pixel size and colour profile, refuse
  sizes above the reported size limit or the pixel cap before any allocation, and offer the largest fitting size with
  the same aspect.
- **FR-A19-105**: A written file MUST be inspected by reading it back: its dimensions, colour profile and byte count
  form the export result, and a mismatch with the plan is a named failure.
- **FR-A19-106**: The video feasibility decision MUST be recorded with the public interface, its cost bounds, the
  owner and the result, and the sources MUST contain no video encoder or video copy unless it is go.
- **FR-A19-107**: Nothing in this phase draws, registers an experience or changes VisualCore or ProjectM; GPU context
  ownership stays in the host.

### Key Entities

- **Scene and preset**: id, name, parameters, colours; license and provenance.
- **Project**: scene, preset, seed, template, orientation, animation time; schema version.
- **Template**: id, device name, pixel size, safe-area guides, provenance.
- **Export plan and result**: format, pixel size, colour profile; read-back size, profile, bytes, failures.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A19-101**: 100% of curated scenes have three or more presets and a provenance record; 100% of templates have a
  provenance record and both orientations.
- **SC-A19-102**: For every template, the planned size, the written file's read-back dimensions and its colour profile
  are equal (0 mismatches).
- **SC-A19-103**: For size limits of 2048, 4096 and 8192, every template above the limit is refused before allocation
  and its offered fallback fits with the same aspect.
- **SC-A19-104**: A project round-trips exactly, and each refusal reason is produced by one sample.
- **SC-A19-105**: The experience's sources contain 0 video encoders, system-wallpaper calls and live-wallpaper words
  while the decision is no-go.
- **SC-A19-106**: Each unit test runs in under 10 seconds; the phase's test run finishes in one command under 10
  minutes.

## Assumptions

- The existing still encoder (sRGB PNG) and the reported size limit are used as they are; JPEG and HEIC come in
  A19-P02 (G-ENCODE).
- Device screen sizes come from Apple's published device specifications; they are data with a provenance record,
  not measured.

## Traceability

| Source | Requirement |
|---|---|
| Phase 01 deliverable: platform API and export contract, smallest slice, domain tests | FR-A19-102–105 |
| MVP: curated procedural backgrounds and colour presets | FR-A19-101, US1 |
| Regression fixture: dimensions and colour profile match the template | FR-A19-104, 105, SC-A19-102 |
| Gate: context ownership in the host | FR-A19-107 |
| Contract G-MODEL, G-TEMPLATES, G-VIDEO | FR-A19-101–106 |
| Brainstorm: high-resolution rendering, export pipelines | FR-A19-103–105 |
| Manual non-goals and risks 1–3 | FR-A19-104, 106, US3 |

## Negative Requirements

- No drawing on screen, experience target, registration or catalog change in this phase; no VisualCore or ProjectM
  change; no network; no private API; no system-wallpaper call; no video unless the decision is go; no purchased,
  generated or photographic image.
