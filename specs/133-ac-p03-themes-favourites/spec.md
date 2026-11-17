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

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `RenderContext.redirected(to:width:height:)` redirects a scene to another framebuffer.
- `ResourceRegistry.makeRenderTarget(width:height:format:depth:label:)` and `RenderTarget.bind`, `bindColor(unit:)`
  and `readPixels` exist.
- `RenderHost.replaceScene` is a hard cut.
- `transitionDuration(_:reduceMotion:)` (VisualCoreSimulation) gives 0 under Reduce Motion.
- `NamedLibrary<Payload>` (VisualCorePersistence) holds entries with a name of at most 60 characters, a favourite
  flag and a payload, and is validated through a `DocumentStore` with a `MigrationChain`.
- Snapshot schemas above 1 need registered schema examples (`AnatomySchemaExamples.swift`, X-A17).

- Q: Where does the crossfade live? → A: In VisualCoreRendering, as an additive `CrossfadeScene: RenderScene`. It
  has two consumers: A18's theme change, and Generative Art Studio's family switch, which keeps its cut for now.
  - It owns two `RenderTarget`s of the drawable size and draws the outgoing and the incoming scene into them through
    `context.redirected`.
  - It mixes them in one full-screen pass with `progress` 0…1 (linear mix in display space), and rebuilds both
    targets on resize and in `setup` after a context loss.
  - Under Reduce Motion the caller sets the duration with `transitionDuration` (0, a cut).
  - Existing scenes are unchanged.
- Q: Which themes, palettes and budgets? → A: Four themes, each a fragment over `vc/`:
  - `noise-gradient`: the existing theme, fbm with 5 / 3 octaves;
  - `particle-drift`: hashed cells holding one soft disc each, drifting; 48 / 24 cells along the shorter side;
  - `wave-field`: the sum of sine waves; 6 / 3 waves;
  - `sdf-shapes`: slowly rotating SDF circles and rounded boxes; 8 / 4 shapes.

  Each theme has three curated dark palettes of four colours. White text MUST reach at least 4.5 : 1 against every
  colour (a test checks all 12 palettes). The budgets per level are the counts above, and one draw (two during a
  crossfade plus the mix).
- Q: What is a theme preset, and what changes in the saved state? → A: `ThemePreset` holds:
  - `theme` (0–3), `palette` (0–2), `speed` (0.25–2) and `motion` (0/1);
  - kind `a18.theme-preset`, schema 1, at most 4,096 bytes;
  - refusals `damaged`, `newer-version`, `too-large` and `out-of-range`.

  The experience snapshot moves to schema 2, adding `theme` and `palette`. Schema 1 migrates to theme 0 and palette 0,
  with registered schema-1 and schema-2 examples. New controls: `theme.select` [0…3] and `theme.palette` [0…2].
- Q: How are favourites stored and capped? → A: In one file, `favourites.json`, written and read through the public
  `ExperienceStorage` API, which namespaces the file and counts it against the experience's quota. It is an envelope
  of kind `a18.favourites`, schema 1, at most 65,536 bytes.

  `NamedLibrary` needs a folder URL, and `ExperienceStorage` gives an experience only flat files, so it is not used.
  Up to 12 entries; a 13th is refused as `over-cap`.
  - Names are trimmed and limited to 60 characters; an empty name becomes "Favourite N".
  - A duplicate name is refused as `duplicate-name`.
  - Applying a favourite sends `theme.select`, `theme.palette`, `theme.speed` and `theme.motion`.
  - A damaged, newer or oversized file gives an empty list with its problem shown, and the file is kept until the
    person saves again.
- Q: How long is the crossfade, and what happens on repeated changes? → A: 1.2 s, eased with smoothstep; 0 under
  Reduce Motion. A new change during a crossfade starts a new one from the current mixed picture: the outgoing
  target keeps the last mixed frame.

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
   new theme; midway their average within 2 of 255 per channel; no frame is black.
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
- **SC-A18-303**: The crossfade's start, middle and end frames match the old picture, the average (within 2 of 255 per
  channel) and the new picture; under Reduce Motion the change takes no frames.
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
