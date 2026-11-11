# Feature Specification: Fractal Explorer — Phase 03 Navigation and bookmarks

**Feature Branch**: `028-fe-p03-navigation-bookmarks` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A03-P03 · ID namespace FR-A03-3##, SC-A03-3##, T-A03-3##

**Input**: User description: archived manual `apps/03-fractal-explorer.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates:**
  - MVP: location bookmarks that include the coordinates and the rendering precision mode.
  - Regression fixture: aspect-ratio changes keep the center and never distort the picture.
  - EGL/context ownership stays solely in the VisualCore host.
- **Reuse:** VisualCorePersistence `DocumentStore` and `MigrationChain`, and VisualCoreMath `PlaneViewport`.
- **Maximize reuse:** the named-document library pattern (A01's `CompositionLibrary`) and the size-independent
  plane framing are generalized into VisualCore, not written again in the app.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2), choosing the recommended option each time.
Facts checked in code:
- `DocumentStore` reports `newerVersion`, `corrupt`, `wrongKind` and `tooLarge` without touching the file, and limits
  documents to 256 KiB;
- `FractalState.zoom` = default width ÷ (units per point × shorter side), with default widths 4 (Mandelbrot) and
  3.2 (Julia);
- `PlaneViewport.resized(to:)` keeps the units per point (not the span), so the explorer's span-keeping resize
  belongs in the new framing type.

- Q: What does the "zoom" typed in Go to mean? → A: The same magnification the canvas description speaks: the mode's
  default width divided by the span across the shorter side. Go to sets span = default width ÷ zoom, so a typed
  1000× reads back as "zoom 1000×".
- Q: When is the precision note shown after opening a bookmark? → A: Only when the precision clamp changed the
  opened view (the saved span is finer than this device's limit). It names the saved bits and the bits in use. It
  disappears on the next zoom out, pan or reset. A bookmark saved with more bits that still fits shows no note.
- Q: How are the bookmark controls presented? → A: A Bookmarks button (`fe.bookmarks`) in the explorer opens a sheet
  with the list and a Save current view button (`fe.bookmark.save`). Saving asks for a name in an alert text field.
  Rows use swipe actions and context menus (rename, favorite, delete) plus accessibility actions, so VoiceOver can
  use them. Go to (`fe.goto`) opens a sheet with three fields and a Go button. Sheets keep the canvas unchanged
  underneath.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save the current location as a bookmark (Priority: P1) 🎯

A person who finds an interesting place saves it under a name. The bookmark keeps everything needed to come back:
mode, center coordinates, zoom, Julia seed, iteration cap, palette and the precision mode the view was rendered in.

**Why this priority**: The phase's MVP gate (v0.1 feature 03).

**Independent Test**: Zoom somewhere, save a bookmark, and inspect the stored bookmark's fields.

**Acceptance Scenarios**:

1. **Given** the explorer at some view, **When** the person taps Save bookmark and enters a name, **Then** the
   bookmark list shows the name with the coordinates and zoom, and the stored bookmark holds mode, center, span,
   seed, cap, radius, palette and precision mode.
2. **Given** an empty or whitespace-only name, **When** saving, **Then** the bookmark is named "Untitled". Names
   longer than 60 characters are cut to 60.
3. **Given** a bookmark, **When** the person renames it, marks it a favorite or deletes it, **Then** the list
   updates, and favorites are listed first.

---

### User Story 2 - Return to a bookmark exactly (Priority: P1)

A person opens a bookmark and gets the same place back, even after the app was closed, on a screen of another shape.

**Why this priority**: Saving is useless without an exact return.

**Independent Test**: Save, relaunch (or reload the library), open the bookmark at another view size, and compare
the center and the span.

**Acceptance Scenarios**:

1. **Given** a saved bookmark, **When** it is opened, **Then** the mode, seed, cap, radius and palette are
   restored. The center is restored exactly (bit-for-bit). The span across the shorter side of the canvas equals
   the saved span within 1e-12 relative.
2. **Given** a bookmark saved in portrait, **When** it is opened in landscape (or any other canvas size), **Then**
   the center is the same, the shorter side shows the same span, and pixels stay square.
3. **Given** the library folder after an app relaunch, **When** the explorer loads it, **Then** all bookmarks are
   listed, and a damaged file is reported and skipped, never deleted.

---

### User Story 3 - Precision mode travels with the bookmark (Priority: P2)

A deep location saved with a given shader precision must not pretend to be reproducible on hardware with less
precision.

**Why this priority**: The A03 truthful-precision rule applied to saved places.

**Independent Test**: Save a bookmark near the 23-bit limit, then open it with a forced 10-bit precision.

**Acceptance Scenarios**:

1. **Given** a bookmark, **Then** it records the precision mode: the shader float format ("GPU float32"), the
   mantissa bits in use when it was saved, and the precision level then (reliable, near limit, limit reached).
2. **Given** a bookmark whose span is finer than the current device's limit, **When** it is opened, **Then** the
   view is clamped at the limit, the precision banner shows "Precision limit reached — zoom stops here", and a note
   says "Saved at higher precision (23 bits); shown at this device's limit (10 bits)".
3. **Given** the bookmark list, **Then** each row names its precision level when it is not reliable.

---

### User Story 4 - Navigate to coordinates (Priority: P2)

A person types a center and a zoom (from a book or a website) and goes there.

**Why this priority**: Navigation (phase title) beyond gestures; completes "coordinates" in v0.1 feature 03.

**Independent Test**: Enter real and imaginary parts and a zoom, tap Go, and check the canvas description.

**Acceptance Scenarios**:

1. **Given** the Go to dialog, **When** the person enters −0.743643887, 0.131825904 and a zoom of 1000 and taps Go,
   **Then** the center is that point and the zoom is 1000×. The canvas description names them.
2. **Given** non-numeric, non-finite or out-of-range input (|x| or |y| > 4, zoom ≤ 0 or > 1e15), **When** Go is
   tapped, **Then** nothing changes and the field says what is wrong.
3. **Given** a zoom beyond the precision limit, **Then** the clamp of Phase 02 applies with its banner.

### Edge Cases

- A rotation or split-view resize: the center and the span across the shorter side are kept; pixels stay square
  (regression fixture).
- A zero or non-finite canvas size: the last valid size is kept (PlaneViewport rule).
- A bookmark file from a newer schema version: reported as unsupported and left untouched.
- A bookmark with a NaN or infinite center, span, cap or seed: rejected on load and reported as damaged.
- Duplicate names are allowed; identity is a generated identifier.
- More than 500 bookmarks: no limit is needed for this slice; the list is lazy.
- A bookmark of Julia mode opened while in Mandelbrot mode: the mode switches with the bookmark.
- A failed bookmark write (disk full, write error): an alert says the bookmark was not saved; the list and the
  current view are unchanged (checklist CHK002).
- No bookmarks yet: the sheet shows "No bookmarks yet. Save the current view to come back to it later." (CHK004).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A03-301**: VisualCore MUST provide a size-independent plane framing: center and span across the shorter
  side, both finite and positive where required. It converts to and from a plane viewport for any canvas size,
  keeping the center bit-exact and the span within 1e-12 relative, with square pixels. It is stored as plain
  numbers, has host tests, docs and a baseline entry.
- **FR-A03-302**: VisualCore MUST provide a generic named-document library over the document store:
  - entries with an identifier, a name (trimmed, at most 60 characters, "Untitled" when empty), a favorite flag, and
    creation and modification times stored to whole seconds;
  - save (new or in place), rename, favorite, duplicate and delete;
  - ordering: favorites first, then most recently modified, then name;
  - reload that reports unreadable or invalid entries without deleting them;
  - a caller-supplied validation of the payload.

  It has host tests, docs and a baseline entry. A01's existing library is not changed in this phase.
- **FR-A03-303**: The app MUST store bookmarks through that library in `Application Support/Bookmarks`, with schema
  version 1. A bookmark holds mode, framing, Julia seed, iteration cap, escape radius, palette id and precision mode
  (format, mantissa bits, level). Loading validates every field.
- **FR-A03-304**: The explorer MUST offer Save bookmark (`fe.bookmark.save`, with a name field) and a Bookmarks list
  (`fe.bookmarks`). Each row shows the name, the center and the zoom (and the precision level when it is not
  reliable), and offers open, rename, favorite and delete (swipe actions, context menu and accessibility actions).
  Opening restores the state per US2 and applies the precision clamp. When the clamp changes the opened view, the
  US3 note (`fe.bookmark.note`) is shown until the next zoom, pan or reset.
- **FR-A03-305**: The explorer MUST offer Go to coordinates (`fe.goto`) with real part, imaginary part and zoom
  fields. The zoom is the spoken magnification (span = default width ÷ zoom). Input is validated per US4 with an
  inline error (`fe.goto.error`).
- **FR-A03-306**: Canvas resizes MUST keep the center and the span across the shorter side, using the VisualCore
  framing (regression fixture), and the GPU picture MUST stay undistorted at non-square sizes. GPU classes match the
  CPU reference at 64 × 32 and 32 × 64 within the Phase 02 tolerance.
- **FR-A03-307**: The contract MUST record the new VisualCore pieces (framing, library) as closed gaps with
  evidence. The fast checks, documented API, isolation, the ProjectM regression (7/7) and the A01 and A02 builds MUST
  pass.

### Negative requirements

- No network, sharing, iCloud sync or export of bookmarks in this slice.
- No claim that a bookmark reproduces the same picture on another device; the precision note says when it cannot.
- No bookmark thumbnails (capture is Phase 04).
- No change to A01's library in this phase.

### Key Entities

- **Plane framing** (VisualCore): center and span across the shorter side.
- **Library entry** (VisualCore, generic): identifier, name, favorite, created, modified, payload.
- **Bookmark** (app): mode, framing, seed, cap, radius, palette id, precision mode.
- **Precision mode** (app): float format, mantissa bits, level at save time.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A03-301**: Save → reload → open returns the same center bit-for-bit and the span within 1e-12 relative, for
  100 random views and 5 canvas sizes from 320 × 568 to 1366 × 1024.
- **SC-A03-302**: Across 100 random resizes, the center never moves and the span across the shorter side stays
  within 1e-12 relative; pixels are square (one scale for both axes).
- **SC-A03-303**: GPU vs CPU class agreement ≥ 99% at 64 × 32 and 32 × 64, on both simulator runtimes.
- **SC-A03-304**: A bookmark beyond the current precision opens clamped, with the banner and the note, in 100% of
  test cases.
- **SC-A03-305**: Library operations (save, rename, favorite, duplicate, delete, reload with a damaged file) pass
  their host tests; UI tests save, list, open, rename and delete a bookmark and use Go to, on both runtimes, and the
  accessibility audit passes at default size and XXXL.
- **SC-A03-306**: The fast checks, ProjectM regression 7/7, and the A01 and A02 builds pass.

## Assumptions

- Bookmarks are local files in the app container; no permission is involved.
- The span across the shorter side is the natural size-independent zoom measure (the default views use it).
- Coordinates are typed with "." as the decimal separator or the locale's separator; both are accepted.
- Precision levels and bits come from the Phase 02 advisor and capabilities; simulator values are context only.
- The bookmark store reads file attributes (the file size check), a FileTimestamp required-reason API. The app's
  privacy manifest is created from the built-app scan in the release phase (Phase 06) and must declare it (C617.1,
  as A02 does) (checklist CHK017).
- The iteration-cost estimate (G-COST) moves to Phase 04, which names it as its MVP; Phase 03 keeps the cap fixed.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 03 — location bookmarks with coordinates and precision mode | FR-A03-303, FR-A03-304, US1–US3 |
| Phase 03 regression fixture — aspect changes keep center, no distortion | FR-A03-301, FR-A03-306, SC-A03-302/303 |
| Brainstorm — interactive explorer, adjustable parameters | FR-A03-305 (Go to) |
| Constitution A03 — truthful precision | US3, FR-A03-304, SC-A03-304 |
| Constitution Principle II / owner reuse rule | FR-A03-301, FR-A03-302 |
