# Feature Specification: Ambient Clock — Phase 03 Theme customization and persistence

**Feature Branch**: `133-ac-p03-themes-favourites` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A18-P03 (legacy ledger) · ID namespace FR-A18-3##, SC-A18-3##, T-A18-3##

**Input**: User description: archived manual `apps/18-ambient-clock.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):**
  - MVP: readable 12/24-hour typography and optional seconds, kept readable over every theme;
  - regression fixture: theme colours pass the contrast review for the primary time text;
  - graphics context ownership stays solely in the audited VisualCore host.
- **Gaps built here** (`docs/apps/ambient-clock/visualcore-contract.json`):
  - G-THEMES: the other three themes (particle drift, wave field, SDF shapes) and the theme presets;
  - G-TRANSITION: a crossfade between two full-screen scenes, assessed for VisualCoreRendering;
  - G-FAVOURITES: the theme document, the editor and the favourites.
- **Visuals are code:** every theme is a fragment shader over VisualCore's GLSL library; the particles of "particle
  drift" are drawn procedurally in the shader.
- Follow `specs/126-ia-p03-layers-search` and `specs/132-ac-p02-overlay-theme`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Four calm themes, all readable (Priority: P1) 🎯

A person picks one of four themes (noise gradient, particle drift, wave field, SDF shapes) and one of its palettes;
the time stays readable over every combination.

**Why this priority**: the manual's four-theme MVP and its contrast regression fixture.

**Independent Test**: for every theme and palette, compute the contrast of the time text against every palette colour;
draw a frame of each theme at each quality level.

**Acceptance Scenarios**:

1. **Given** any theme and palette, **Then** the time text reaches a contrast of at least 4.5 : 1 against every palette
   colour.
2. **Given** each theme at each quality level, **When** a frame is drawn, **Then** it is not blank and stays within the
   level's budget.

---

### User Story 2 - Changing theme without a jolt (Priority: P1)

A person switches theme and sees a short crossfade; with Reduce Motion on, the change is a cut.

**Why this priority**: the brainstorm's scene transitions.

**Independent Test**: render the crossfade at its start, middle and end; turn Reduce Motion on.

**Acceptance Scenarios**:

1. **Given** a theme change, **When** the crossfade is at its start, **Then** the frame is the old theme; at its end the
   new theme; midway their average within a small tolerance; no frame is black.
2. **Given** Reduce Motion on, **Then** the change is immediate.

---

### User Story 3 - Saving favourites (Priority: P2)

A person edits a theme (theme, palette, speed, motion), saves it as a named favourite, and finds it again after
reopening the clock.

**Why this priority**: version 0.1 feature 04.

**Independent Test**: save, reopen, apply; feed damaged, newer and oversized documents; exceed the cap.

**Acceptance Scenarios**:

1. **Given** a saved favourite, **When** the clock reopens, **Then** the favourite is listed and applies exactly.
2. **Given** a damaged, newer or oversized favourites file, **Then** it is refused, nothing crashes and the defaults
   apply.
3. **Given** the favourites cap is reached, **Then** one more favourite is refused with a reason.

### Edge Cases

- **A theme fails to compile:** the previous theme stays, and the time stays correct.
- **A theme change during a crossfade:** the crossfade restarts from the current picture.
- **A context loss during a crossfade:** both pictures are rebuilt; the change completes.
- **A favourite name that is empty, too long or a duplicate:** normalised or refused with a reason.
- **An older saved clock state (from A18-P02):** migrates to the noise gradient with its first palette.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A18-301**: The clock MUST offer four procedural themes, each with curated palettes, a speed and motion on or
  off, at both quality levels.
- **FR-A18-302**: Every palette MUST give the time text a contrast of at least 4.5 : 1 against each of its colours;
  a palette that does not is refused.
- **FR-A18-303**: A theme change MUST crossfade over a short, fixed duration, and MUST cut under Reduce Motion; the
  shown time never depends on the crossfade.
- **FR-A18-304**: A theme preset (theme, palette, speed, motion) MUST be versioned and validated; damaged, newer,
  oversized or out-of-range presets MUST be refused with a reason.
- **FR-A18-305**: Favourites MUST be stored in the experience's own storage with a name, a cap and validation, and MUST
  survive a reopen.
- **FR-A18-306**: The clock's saved state MUST migrate from the A18-P02 schema to the new one.
- **FR-A18-307**: If the crossfade lands in VisualCore, it MUST carry `///` documentation, an API baseline update and
  tests, and the reference regression at X-A18.
- **FR-A18-308**: The verification scenarios MUST include a theme change and a favourite applied.

### Key Entities

- **Theme**: id, name, palettes, shader, octave or step budgets per level.
- **Theme preset**: theme, palette index, speed, motion, schema version.
- **Favourite**: name, preset.
- **Crossfade**: from-picture, to-picture, progress, duration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A18-301**: 100 % of the theme and palette combinations reach 4.5 : 1 for the time text.
- **SC-A18-302**: All four themes draw non-blank frames at both quality levels.
- **SC-A18-303**: The crossfade's start, middle and end frames match the old picture, the average and the new picture
  within the stated tolerance; under Reduce Motion the change takes no frames.
- **SC-A18-304**: Favourites round-trip after a reopen; every damaged, newer, oversized and over-cap case is refused.
- **SC-A18-305**: Every test runs in under 10 seconds; the experience passes the nine standard scenarios on iOS 27.

## Assumptions

- Night mode, screen care and keep-awake come in A18-P04; the editor offers only curated palettes, so no free colour
  choice can break contrast.

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 deliverable: theme customization and persistence | FR-A18-301, 304, 305 |
| MVP: readable 12/24-hour typography with optional seconds over every theme | FR-A18-302 |
| Regression fixture: theme colours pass contrast review | FR-A18-302, SC-A18-301 |
| Feature 02: four procedural themes with quality and motion controls | FR-A18-301 |
| Feature 04: theme editor with saveable favourites | FR-A18-304, 305 |
| Brainstorm: scene transitions, configuration and presets | FR-A18-303, 304 |
| Contract G-THEMES, G-TRANSITION, G-FAVOURITES | FR-A18-301–308 |

## Negative Requirements

- No free colour picker that could break contrast; no text drawn by a shader; no network; no imported or downloaded
  themes; no purchased, generated or photographic image.
