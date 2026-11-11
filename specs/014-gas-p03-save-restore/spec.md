# Feature Specification: Generative Art Studio — Phase 03 Save and restore compositions

**Feature Branch**: `014-gas-p03-save-restore` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: A01-P03 · ID namespace FR-A01-3##, SC-A01-3##, T-A01-3##

**Input**: User description: archived manual `apps/01-generative-art-studio.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation). Canonical override: the reusable document store is built in VisualCorePersistence
(gap G-PERSIST; constitution Principle II):
- a versioned envelope;
- atomic writes;
- migrations;
- corruption handling;
- listing.

Evidence is host and simulator only.

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2); the recommended option was chosen in each case.

- Q: How are compositions laid out on disk? → A: One JSON file per composition, named `<identity>.json`, in
  `Application Support/Compositions/`. Each file is an envelope: kind `dev.visualcore.gas.composition`, schema
  version, saved time in ISO 8601 UTC, and the library entry as payload. Per-file size limit is 256 KiB. Files of
  another kind or with another extension are reported and ignored.
- Q: How is "atomic" achieved, and what protects the data at rest? → A: The file is written to a temporary file in
  the same folder and then replaced in one step, so readers never see a partial file. Files use the default iOS
  data protection (complete until first user authentication). There is no extra encryption, since the content is not
  sensitive.
- Q: How are versions handled? → A: The library entry has schema version 1, wrapping ArtDocument v1. The store applies
  an ordered migration chain (vN → vN+1) on load. Versions above the current one are reported as "newer version"
  and left untouched. The chain is proven by a test-only version-0 fixture.
- Q: Where do save and the library live in the UI? → A: The scene screen gains a "Save" toolbar button, which asks
  for a name on first save and saves in place afterwards. The gallery gains a "Library" toolbar button that opens
  the library list. Opening an entry shows its scene, and later saves update that entry.
- Q: How are times and ordering defined? → A: Created and modified times are stored as UTC instants. Ordering is
  favorites first, then modified time descending, then name ascending as a stable tie-break.

## User Scenarios & Testing *(mandatory)*

Users: makers who want to keep and revisit their compositions (manual §2 journeys 1 and 2), plus app developers
reusing the VisualCore document store.

### User Story 1 - Save a composition and reopen it exactly (Priority: P1) 🎯

From a scene, the user saves the current composition under a name. Later, from the library, they reopen it, and the
scene shows the same seed, palette and parameter values. Rendered at the same time, it gives the same image as when
it was saved.

**Why this priority**: It is journeys 1 and 2, version 0.1 feature 03 (seed reproducibility and presets) and the
first half of feature 04.

**Independent Test**: Save, relaunch the app, open the saved composition, and compare its image at a fixed time
with the image before saving: identical within tolerance.

**Acceptance Scenarios**:

1. **Given** an edited composition, **When** the user saves it with a name, **Then** it appears in the library with
   that name, its family and its modification time.
2. **Given** a saved composition, **When** it is reopened after an app relaunch, **Then** its seed, palette and
   parameters equal the saved ones, and its image at a fixed time matches the image at save time within tolerance.
3. **Given** a saved composition that is reopened and edited, **When** saved again, **Then** it updates in place (same
   identity, newer modification time).

---

### User Story 2 - Organize the library: favorites, duplicate, rename, delete (Priority: P1)

In the library the user marks favorites, which are listed first. They can duplicate a composition into a new,
independent copy, rename it, and delete it after confirming.

**Why this priority**: It is version 0.1 feature 04 (versioned local store with favorites and duplication).

**Independent Test**: Create three compositions, favorite one, duplicate one, rename one and delete one. The list
order and contents match the expectations after a relaunch.

**Acceptance Scenarios**:

1. **Given** several compositions, **When** one is marked favorite, **Then** favorites are listed first, then the
   others by most recently modified.
2. **Given** a composition, **When** it is duplicated, **Then** a new composition with a new identity and the name
   "<name> copy" appears. Editing either does not change the other.
3. **Given** a composition, **When** it is deleted and the deletion is confirmed, **Then** it disappears and does not
   return after a relaunch. Cancelling keeps it.

---

### User Story 3 - Damaged or newer files never break the library (Priority: P1)

If a stored file is damaged, or was written by a newer version, the library still opens. Every readable composition
is listed, and each unreadable one is reported with its reason. Nothing is overwritten or deleted automatically.

**Why this priority**: It reuses the Phase 02 recovery rule for stored data and protects user work.

**Independent Test**: Place a corrupt file and a future-version file next to valid ones. The library lists the valid
ones, shows "2 compositions couldn't be read", and leaves the bad files untouched.

**Acceptance Scenarios**:

1. **Given** a corrupt and a future-version file among valid ones, **When** the library loads, **Then** all valid
   compositions are listed, the problems are reported with reasons, and the bad files are not modified.
2. **Given** a save is interrupted, **When** the library loads, **Then** either the old or the new version is present,
   never a partial file.

---

### User Story 4 - Rapid edits never leak GPU resources (Priority: P1)

Editing quickly, for example switching palettes many times per second, never accumulates GPU programs, textures or
render targets.

**Why this priority**: It is the manual's Phase 03 regression-fixture gate.

**Independent Test**: Apply 200 palette, seed and preset changes over a live scene. Live GPU resource counts return
to their starting level, and 0 resources leak after destroy.

**Acceptance Scenarios**:

1. **Given** a live scene, **When** 200 rapid palette, seed and preset edits are applied with frames rendered between
   them, **Then** the live program, texture and render-target counts equal the counts before the edits, and destroy
   reports 0 leaked.

---

### User Story 5 - Reusable document store (Priority: P2)

Other apps reuse a VisualCore document store that provides:
- a versioned envelope (kind, schema version, payload);
- atomic writes and listing with per-file errors;
- a migration chain for older versions;
- rejection of newer versions;
- size limits.

**Independent Test**: Package tests for the store, its docs and an API-baseline entry. The ProjectM regression
still passes.

**Acceptance Scenarios**:

1. **Given** the new public API, **When** the API review runs, **Then** it is documented and the baseline is updated.
2. **Given** the VisualCore change, **When** the reference regression runs, **Then** it passes (7/7).

### Edge Cases

- Name handling: empty or whitespace-only names become "Untitled", names are trimmed and longer than 60 characters
  are cut, and duplicate names are allowed (identity is not the name).
- A file larger than the size limit (256 KiB) is reported as unreadable and is never loaded into memory in full.
- A file of another kind in the folder is ignored and reported.
- An older schema version is migrated on load. The file is rewritten in the current version only when the user saves
  it again.
- Deleting the composition that is currently open leaves the scene open as an unsaved composition.
- The store folder is missing on first launch: it is created, and the library is empty.
- Storage full or write failure: the save reports an error and the previous version stays intact.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A01-301**: The user MUST be able to save the current composition with a name, from the scene screen. Saving an
  already saved composition MUST update it in place (same identity, newer modification time).
- **FR-A01-302**: The library MUST list saved compositions with name, family and modification time: favorites first,
  then most recently modified first, with ties broken by name.
- **FR-A01-303**: Reopening a saved composition MUST restore its seed, palette and parameters exactly, and render the
  same image at a fixed time within the Phase 01 tolerance, also after an app relaunch.
- **FR-A01-304**: The library MUST support favorite/unfavorite, duplicate (new identity, "<name> copy",
  independent), rename (trimmed, ≤ 60 characters, empty becomes "Untitled") and delete with confirmation.
- **FR-A01-305**: Loading MUST list every readable composition and report each unreadable file:
  - corrupt;
  - newer version;
  - wrong kind;
  - too large.

  Files are never modified, moved or deleted automatically.
- **FR-A01-306**: Saves MUST be atomic: after any interruption either the previous or the new complete file exists. A
  failed save reports an error and keeps the previous version.
- **FR-A01-307**: Older stored versions MUST be migrated on load through an ordered migration chain. Newer versions
  MUST be rejected unmodified.
- **FR-A01-308**: 200 rapid palette, seed and preset edits on a live scene MUST leave live GPU program, texture and
  render-target counts at their starting level, with 0 leaked after destroy.
- **FR-A01-309**: The generic store MUST live in VisualCorePersistence:
  - versioned envelope;
  - atomic writes;
  - listing with per-file errors;
  - migration chain;
  - kind and size checks.

  It needs package tests, docs and an API-baseline update, and the ProjectM regression MUST pass afterwards.
- **FR-A01-310**: The app MUST store compositions only in its own app container (Application Support), with no
  networking, no permissions and no ProjectM linkage. Library and save controls MUST be accessible: labels, hints,
  a confirmation for delete, and Dynamic Type.
- **FR-A01-311**: The VisualCore contract MUST be updated: G-PERSIST closed and M08 available. The contract check
  MUST pass.

### Key Entities

- **Stored envelope** (VisualCore): kind, schema version, saved time, payload.
- **Library entry** (app): identity, name, favorite flag, created and modified times, composition.
- **Load report** (VisualCore): entries read, plus per-file problems (file name, reason).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A01-301**: 100% of ≥ 30 generated library entries round-trip through save and load with equal content,
  including seed 2^64−1 and every family.
- **SC-A01-302**: A composition saved, reloaded through a new store instance and rendered at a fixed time matches its
  pre-save image (≥ 99% of channels within 2/255), for all 4 families on both runtimes.
- **SC-A01-303**: Ordering, duplicate independence, rename rules and delete behave as specified in 100% of the domain
  tests, and the library UI test passes on both runtimes.
- **SC-A01-304**: With 2 bad files among 5 good ones, 5 are listed and 2 are reported, and the bad files are
  byte-identical afterwards.
- **SC-A01-305**: After 200 rapid edits, live program, texture and render-target counts equal the starting counts,
  with 0 leaked, for all 4 families.
- **SC-A01-306**: The API review, documented-API check, contract check, ProjectM regression (7/7) and app tests on
  both runtimes all pass.

## Assumptions

- Thumbnails of saved compositions come with the still exporter in Phase 04. Library rows show the family symbol and
  a palette swatch.
- iCloud sync, sharing, import and export of composition files are not in scope (manual non-goals and later
  phases).
- Interrupted writes are simulated in tests by writing a partial temporary file without replacing the target.
