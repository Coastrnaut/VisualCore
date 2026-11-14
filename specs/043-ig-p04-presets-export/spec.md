# Feature Specification: Infinite Geometry — Phase 04 Scene editing and export

**Feature Branch**: `043-ig-p04-presets-export` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A05-P04 (legacy ledger) · ID namespace FR-A05-4##, SC-A05-4##, T-A05-4##

**Input**: User description: archived manual `apps/05-infinite-geometry.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — deterministic presets and still export; regression fixture — repeated preset
  transitions leave GPU objects stable; graphics-context ownership stays solely in the VisualCore host.
- **VisualCore contract** (`docs/apps/infinite-geometry/visualcore-contract.md`): M17 named presets and persistence and
  M18 still export are **available**; the only framework change is raising the per-action value limit from 8 to 24
  (Clarifications, T-A05-416). The experience follows the Particle Universe saved-scene library and the Fluid Art
  still-capture patterns. The contract document gains these consumers.
- **Owner rulings of 2026-11-13:** short tests; audits wait for the device campaign; parallel agents; no wall-clock
  assertions on CI runners.

## Clarifications

### Session 2026-11-13

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
controls change the experience only through actions (`ExperienceActionPort.send`); Particle Universe opens a saved
scene by sending its document's actions (`openActions()`) and names duplicates with a numeric suffix (`uniqueName`, "Name
2"); `ExperienceStorage` allows 64 files (`StorageQuota.maxFiles`) and replaces files atomically; the host hands controls
an `experienceStillRenderer` that calls `RenderHost.renderOffscreen` on the session's context; `StillImageEncoder.pngData`
encodes through ImageIO (PNG file bytes are not documented to be stable across runs or OS versions).

- Q: How is a saved composition restored when controls can only send actions? → A: By one atomic action
  `composition.open` whose values carry the whole stored composition (preset index, kind, order, repeats, scale, palette,
  motif seed, the 2D camera and the 3D camera); the core validates all values together and either applies all or refuses
  all, so a partial open is impossible and the digest after opening equals the digest at save time.
- Q: What is stored in a saved-composition file? → A: `composition-<uuid>.json` in the experience's storage:
  `{"document": <GeometryDocument version 1>, "digest": "<hex at save time>", "format": 1, "id": "<uuid>", "saved":
  <seconds>}` with sorted keys, following `ParticleLibrary` (unreadable files counted and never deleted; a newer
  `format` or document version is listed and refused).
- Q: What happens when a name is already taken? → A: As in Particle Universe, the saved composition gets the first free
  numeric suffix ("Spiral 2"); renaming to a taken name does the same. Nothing is replaced silently.
- Q: What does "byte-identical exports" mean when the PNG encoder may vary its bytes? → A: The decoded pixels of two
  exports are identical byte for byte (RGBA), and the PNG files have the same size in pixels; file-byte equality is not
  required.
- Q: An action carries at most 8 values in VisualCore (`ExperienceControl.maxValues`, found in implement), but the
  atomic open needs 18 — split the open or raise the limit? → A: Raise the limit to 24 (VisualCore task T-A05-416,
  approved here): splitting the open into several actions would reintroduce the partial-open risk this clarification
  removed, and the limit is generic (any experience restoring a document needs it); the change is one constant, its
  tests, documentation and the ProjectM reference regression, as Principle XIII requires.
- Q: What does saving with an empty name do? → A: The name falls back to "Untitled" (then the numeric-suffix rule), as in
  Particle Universe; names are trimmed and cut to 60 characters, so saving is never refused for its name.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save a composition and get it back exactly (Priority: P1) 🎯

A person shapes a composition (preset, symmetry, repetitions, scale, palette, motif seed and camera), saves it under a
name, keeps exploring, and later opens the saved composition: it looks exactly as it did when saved. They can rename and
delete saved compositions. Journey 3 of the brainstorm: "orbit a 3D composition and save a named parameter preset".

**Why this priority**: half of the phase MVP ("deterministic presets").

**Independent Test**: save a composition, change everything, open the saved one; the experience state digest equals the
digest at save time.

**Acceptance Scenarios**:

1. **Given** a composition, **When** it is saved as "Spiral", **Then** "Spiral" appears in the list of saved compositions.
2. **Given** a saved composition, **When** it is opened after other changes, **Then** the state digest equals the digest
   recorded when it was saved, including the camera.
3. **Given** a saved composition, **When** it is renamed or deleted, **Then** the list shows the new name or no longer
   shows it, and other entries are untouched.
4. **Given** the experience is closed and reopened, **When** the list is shown, **Then** every saved composition is still
   there.

---

### User Story 2 - Export a still picture (Priority: P1)

A person exports the current composition as a picture and shares or saves it through the system share sheet.

**Why this priority**: the other half of the phase MVP ("still export").

**Independent Test**: export twice without changes; both pictures are identical, have the requested size and match the
on-screen picture.

**Acceptance Scenarios**:

1. **Given** any preset, **When** the person exports, **Then** a PNG picture with a long edge of 2048 pixels in the
   canvas's aspect is offered to the share sheet.
2. **Given** an unchanged composition, **When** it is exported twice, **Then** the two pictures' pixels are identical.
3. **Given** the 3D composition, **When** it is exported, **Then** the picture is depth-correct (as on screen).
4. **Given** an export that cannot be made (for example the size exceeds the device's limit), **When** it fails,
   **Then** a plain message is shown, the live view keeps running and no file is left behind.

---

### User Story 3 - Switching presets many times never leaks (Priority: P2)

A person flips through presets and saved compositions for a long time; the app's graphics resources do not grow.

**Why this priority**: the phase's regression fixture.

**Independent Test**: cycle through all presets several times while drawing; the resource ledger's live counts after
the cycles equal those after the first cycle and nothing is reported leaked.

**Acceptance Scenarios**:

1. **Given** the experience drawing, **When** all presets are cycled three times with a frame drawn after each change,
   **Then** the live GPU object counts after cycles 2 and 3 equal those after cycle 1.
2. **Given** saved compositions of every preset kind, **When** each is opened in turn twice, **Then** the counts are
   equal after both rounds.

### Edge Cases

- Saving with an empty or whitespace name saves as "Untitled"; names are trimmed and cut to 60 characters.
- Saving or renaming to a name that already exists (ignoring case) uses the first free numeric suffix ("Spiral 2").
- The storage quota is reached: the save is refused, existing entries stay intact, a message is shown.
- A saved file that cannot be read (damaged or from a newer version) is listed as unreadable, never deleted, and opening
  it is refused with a message.
- Opening a saved composition whose camera is out of the current bounds is refused (the restore rule of Phase 03).
- Export while the canvas has zero size is refused with a message.
- Export never changes the composition's state (digest before = digest after).

## Requirements *(mandatory)*

### Functional Requirements

**Saved compositions (story 1)**
- **FR-A05-401**: The person MUST be able to save the current composition under a name (trimmed, at most 60 characters,
  empty → "Untitled", made unique ignoring case with a numeric suffix) and see the saved compositions listed by name.
- **FR-A05-402**: Opening a saved composition MUST restore the complete experience state in one all-or-nothing step so
  that its digest equals the digest recorded at save time.
- **FR-A05-403**: The person MUST be able to rename and delete saved compositions; other entries MUST stay untouched.
- **FR-A05-404**: Saved compositions MUST persist in the experience's own storage across closing and reopening, within
  its quota; a refused save MUST leave existing entries unchanged.
- **FR-A05-405**: Unreadable or newer-format files MUST be listed as such, never deleted or rewritten, and refused when
  opened.

**Still export (story 2)**
- **FR-A05-410**: The person MUST be able to export the current picture as a PNG with a long edge of 2048 pixels (capped
  by the device) in the canvas's aspect, offered through the system share sheet.
- **FR-A05-411**: Export MUST be drawn by the host on its own graphics context (no second context or renderer) and MUST
  not change the composition's state.
- **FR-A05-412**: Two exports of an unchanged composition MUST have byte-identical decoded pixels.
- **FR-A05-413**: A failed export MUST show a plain message, keep the live view running and leave no file.

**Stability (story 3)**
- **FR-A05-420**: Repeated preset changes and repeated opening of saved compositions MUST leave the live GPU object
  counts stable (equal after each full cycle) with no leaked resources.

**Common**
- **FR-A05-430**: Every new control MUST have an accessible label and identifier; saving, opening, renaming, deleting and
  exporting MUST all be possible with buttons (no gesture-only path).
- **FR-A05-431**: No network, no account, no analytics; exported pictures leave the app only through the share sheet
  chosen by the person and carry no metadata beyond size and colour space (no location, device or time); no imported
  assets.
- **FR-A05-432**: The nine standard scenarios and five fixtures MUST stay valid.

### Key Entities

- **Saved composition**: an identifier, a name, the save time, the composition document (preset index and fields, motif
  seed, 2D and 3D cameras; version 1) and the digest at save time.
- **Exported picture**: PNG data held in memory for the share sheet only (nothing is written to a file), released when
  the share sheet closes or the next export replaces it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A05-401**: For every preset kind, a saved composition reopened after changes restores its digest in 100% of cases.
- **SC-A05-402**: Save, rename, delete and reopen keep the list and files consistent in 100% of the tested sequences,
  including a refused save at the quota.
- **SC-A05-403**: Two exports of each preset kind have byte-identical decoded pixels, have the exact requested size and match the
  on-screen picture within 2/255 per channel at probe pixels after scaling.
- **SC-A05-404**: After three full preset cycles, live GPU object counts equal those after the first cycle on both
  simulator runtimes; nothing leaked.
- **SC-A05-405**: The runner passes the nine scenarios and five fixtures on both runtimes.
- **SC-A05-406**: Every new test finishes in under 10 seconds.

## Assumptions

- The saved document is versioned on its own (version 1); a later phase that changes it adds a document migration.
- The host exposes a still renderer to controls (as used by Fluid Art); exports are drawn at the requested size through
  it.
- Pixel comparisons are done on the simulator; device colour fidelity is checked in the device campaign.
- One export holds at most 2048 × 2048 × 4 bytes (16 MiB) of pixels plus its PNG in memory, released when the share sheet
  closes; the offscreen target is released by the host after the render.

## Out of Scope

- Video or animated export; mesh export (manual: "import/export arbitrary mesh formats" is out of MVP).
- Sharing saved compositions between devices; iCloud.
- Editing individual motif points by hand.

## Traceability

| Source | Requirement |
|---|---|
| Brainstorm journey 3 (save a named parameter preset) | FR-A05-401–405 |
| v0.1 feature 04 (deterministic presets and still export) | FR-A05-401–413 |
| Manual §9 Phase 04 fixture "repeated preset transitions leave GPU objects stable" | FR-A05-420, SC-A05-404 |
| Contract rows M17, M18 | FR-A05-404, 410, 411 |

## Negative Requirements

- No second renderer or graphics context; no Metal code.
- No network, analytics, accounts, advertising or imported art.
- No long tests: no soak or endurance runs.
