# Feature Specification: Living Wallpapers — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `137-lw-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A19-P00 (legacy ledger) · ID namespace FR-A19-0##, SC-A19-0##, T-A19-0##

**Input**: User description: archived manual `apps/19-living-wallpapers.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Living Wallpapers (`a19.living-wallpapers`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/LivingWallpapers` (Auto-Creator.md §16 layout). It never gets a standalone target,
  bundle identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell"
  is met by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A18. The contract lives in `docs/apps/living-wallpapers/`.
- **Visuals are code:** every background is a shader, field, particle or SDF drawing; no purchased, generated or
  photographic image.
- **Constitution:** 2.15.0 adds the A19 experience rules (committed at the start of this gate, `2f592d76`).
- Follow `specs/130-ac-p00-boundary-audit`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code by a read-only survey:
- **Commits:** the A19 constitution commit is `2f592d76` and the A19-P00 specify commit is `530855ef`. The specify
  commit is the phase start for the no-change diff of `Packages` and `External`. The reference submodule is pinned at
  `d93edd1`.
- **Registry:** eighteen experiences are registered in `Catalog/registrations.json` (A01–A18). `a19` appears only in
  the catalog, the id golden file, their test fixtures and `AppModelTests` (as a synthetic not-yet-integrated id).
- **VisualCore offers** (public in a framework product and tested):
  - in `VisualCoreRendering`:
    - `RenderHost.renderOffscreen(width:height:time:)`: any size, independent of the screen, on the host's own
      context. It validates the size first, releases its target on every path and restores the live scene
      (`OffscreenExportTests`).
    - `RenderHost.maxRenderSize`: the smallest of the maximum texture, renderbuffer and viewport sizes, reported by
      `RenderCapabilities` with a floor of 2048. Also `RenderHost.maxOffscreenPixels` (64,000,000).
    - `StillImage` (RGBA8, top-down), `OffscreenRenderError` and `StillImageEncoder.pngData` (an opaque PNG tagged
      sRGB, the only encoder).
    - `StillCapture` (one PNG in a temporary folder; it writes nothing to Photos).
    - `RenderContext.redirected`, `ResourceRegistry.makeRenderTarget`, `RenderTarget.readPixels`, `CachedScene`,
      `CrossfadeScene`, `FullScreenShaderScene`, `ShaderBundle` and the GLSL library `vc/`;
  - in `VisualCoreExperienceHost`: `ExperienceSession.renderStill(width:height:)` and the `experienceStillRenderer`
    environment value (`StillRenderTests`). It always renders at time 0;
  - in `VisualCoreScenes`: `ExportGeometry` (`hardMaxEdge` 8192, `defaultMaxPixels`), `ExportAspect` (square, 4:5,
    16:9, 9:16) and `ExportSize` (`ExportGeometryTests`);
  - in `VisualCoreDiagnostics`: `ResourceBudget` (GPU bytes, refusal when over budget);
  - in `VisualCorePersistence`: `TemporaryFolder`; and in `VisualCoreExperience`: `ExperienceStorage` with
    `StorageQuota` (16 MiB, 64 files);
  - in the host: preparation with cancellation (`ExperienceEngine.prepare`, `ExperienceShell.cancelPreparation`),
    memory-warning handling and the canvas overlay.
- **Missing everywhere:**
  - an encoder other than PNG (no JPEG, HEIC or colour space other than sRGB);
  - any video encoding (no AVFoundation writer, pixel buffer or VideoToolbox use);
  - tiled rendering (no sub-rectangle projection);
  - a catalog of device screen sizes and safe areas;
  - an export job with progress (the offscreen render is synchronous on the main thread);
  - an offscreen render of an experience at a chosen animation time (the session's still is at time 0).
- **Experience-only:** the `ShareLink` image paths of Generative Art Studio, Fluid Art Playground, Fractal Explorer,
  Infinite Geometry and Simulation Lab (`Transferable` PNG files). No experience calls PhotoKit. Saving to Photos goes
  through the share sheet's "Save Image" with the app's existing add-only usage string (`project.yml`,
  `NSPhotoLibraryAddUsageDescription`), declared per experience as the permission word `photo-library-add` (only A01
  declares it today). The release step `app-usage-descriptions` requires the app's usage keys to equal the union of
  the declared words.

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: As for A18: the one app is the shell.
  This phase proves it builds for testing with Living Wallpapers absent, and the targets come with A19-P01's first
  model.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least
  one test that exercises it. An implementation that exists only inside another experience or a harness is "requires
  adaptation" at best.
- Q: Which package holds Living Wallpapers? → A: `Packages/ExperiencesCreative/LivingWallpapers` (Auto-Creator.md
  §16), as A05–A18 did; no new package is created.
- Q: How does an exported image leave the device, and which permission does that need? → A: Through the system share
  sheet only (SwiftUI `ShareLink` with a file), as the five experiences above do. "Save Image" there writes to Photos
  with the existing add-only usage string, and "Save to Files" or another app needs no permission. The experience
  never calls PhotoKit and never asks for read access to the library. Its registration will declare
  `photo-library-add` (A19-P04), so the usage-description step stays exact, and its copy check will allow the word
  "share" (as Simulation Lab and Infinite Geometry do). The in-app help explains how to apply the saved image as a
  wallpaper through the system's own Settings or Photos controls. Recorded as gaps G-SAVE and G-HELP.
- Q: What do the audit and later phases assume for formats, sizes and video? → A:
  - **Stills:** PNG through the existing encoder, plus JPEG and HEIC through the same ImageIO path in
    `VisualCoreRendering`, all tagged sRGB (the renderer draws 8-bit sRGB). The colour profile and dimensions are
    verified by reading the written file back. Recorded as gap G-ENCODE (VisualCore, A19-P02).
  - **Sizes:** device templates are app-local data with a provenance record (Apple's published screen sizes). A
    template whose edge exceeds `maxRenderSize`, or whose pixel count exceeds the cap, is refused before allocation
    and offered at the largest size that fits. Version 0.1 has no tiling; it is recorded as rejected for 0.1, not as
    a gap.
  - **Video:** optional. A19-P01 decides feasibility from public APIs and records it. Until it is shown feasible, no
    video code, copy or control exists. Recorded as gap G-VIDEO (decision A19-P01; any encoder is assessed for
    VisualCore ownership then).

  Export at a chosen animation time needs a time on the session's still. That is gap G-STILLTIME
  (`VisualCoreExperienceHost`, A19-P02). Export progress, cancellation and cleanup run off the interface's critical
  path with a local history in `ExperienceStorage`: gaps G-EXPORTJOB and G-HISTORY (app-local, A19-P04).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Living Wallpapers gets a map of what VisualCore already provides. It covers each
capability the experience needs (offscreen rendering, high-resolution rendering, effects and compositing, frame
capture, export pipelines) and each version 0.1 feature. Every entry has real files, declared names and package
products, and is marked available, requires adaptation, or upstream gap.

**Why this priority**: the manual's first review gate; every later phase depends on it.

**Independent Test**: run the contract checker; every cited file exists, every cited name is declared, every product
exists, and every non-available row has a gap entry.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the checker runs, **Then** it passes with 0 problems.
2. **Given** a cited name that does not exist, **When** the checker runs, **Then** it fails naming it.
3. **Given** the five brainstorm capabilities and the six version 0.1 features, **When** the traceability is read,
   **Then** each maps to at least one matrix row.

---

### User Story 2 - The reference stays proven (Priority: P1)

The owner sees that the ProjectM reference regression passes before any Living Wallpapers work, and the starting
commit is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Living Wallpapers absent.
Phase 01 then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Living Wallpapers is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Living Wallpapers can proceed, what is missing upstream, and which
module will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or an offscreen render-and-read-back path were missing and could
   not be built over the existing renderer, **Then** the decision is "stop" and names the blocker (a missing host is
   never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a render target that can be drawn into but whose pixels cannot be
  read back at output size): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example another experience's image export or share
  path): not counted as available; reuse needs it in VisualCore first.
- **Restricted wallpaper behaviour** (the manual's risk 1): the audit records that no public API sets the system
  wallpaper or installs a live wallpaper, and that the person applies an exported file through the system's own
  controls. No private API is assessed as an option.
- **Very large output sizes** (the manual's risk 2): the audit records where the GPU's maximum texture size and a
  memory budget can be queried before allocation, and whether a tiled strategy exists.
- **Video encoding** (the manual's risk 3): the audit records whether any encoder path exists and assigns the
  feasibility decision to a phase; video stays optional until feasibility is shown.
- **Saving to Photos:** saving goes through the share sheet with the app's existing add-only usage string; the
  experience declares `photo-library-add` and never calls PhotoKit. Export to Files needs no permission.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A19-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (full-screen shaders, fields, palettes, render targets, compositing), the experience
  host, the build and release steps, source ownership and the reference regression steps, each with real paths.
- **FR-A19-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A19-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - curated procedural backgrounds with colour presets;
  - iPhone and iPad canvas templates with crop and safe-area guides;
  - offscreen rendering at output resolution, independent of the screen, with pixel read-back;
  - the maximum texture size and memory headroom, queried before allocation, and the fallback for a size that does
    not fit (no tiling in version 0.1);
  - still-image encoding in common formats with a verified colour profile;
  - optional short video encoding and its feasibility;
  - export progress, cancellation, cleanup of GPU resources and temporary files, error recovery and a local history;
  - saving to Photos (permission) and handing a file to Files or another app (no permission);
  - instructions for applying an exported image by hand;
  - resize and context-loss rebuild.
- **FR-A19-004**: The ProjectM reference regression MUST run in two chunks and pass. A baseline document MUST record
  the phase-start commit, the reference pin and the results.
- **FR-A19-005**: The one app MUST build for testing with Living Wallpapers absent. The experience package check MUST
  pass. Living Wallpapers MUST stay unregistered and unavailable; its targets come with A19-P01's first rules.
- **FR-A19-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking, no private API, no
    automatic setting of the system wallpaper, no claim that an export is a live wallpaper, no unbounded output size,
    and no purchased, generated or photographic images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: restricted
    wallpaper behaviour, out-of-memory at very high resolution, and video encoding cost;
  - a stop/go decision with reasons.
- **FR-A19-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A19-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A19-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A19-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A19-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A19-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (18 registered experiences, none of them A19).
- **SC-A19-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A19-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides the 2D pieces earlier experiences used (Generative Art Studio, Fluid Art Playground, Fractal
  Explorer, Ambient Clock): full-screen shader scenes, fields, palettes, parameters, quality tiers, render targets,
  the canvas overlay, accessibility planners and experience storage. Earlier experiences may already export images;
  the audit confirms each from the code and records what is missing.
- The scenes, templates, copy and interface are app-local; generic pieces (offscreen render at output size, read-back,
  image encoding) are assessed for VisualCore ownership.
- Later phases (A19-P01 to A19-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A19-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A19-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A19-005, US3 |
| Review gate: written stop/go decision | FR-A19-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A19-008 |
| Brainstorm capabilities (offscreen rendering, high-resolution rendering, effects and compositing, frame capture, export pipelines) | FR-A19-002 |
| Manual non-goals and risks 1–3 | FR-A19-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no private API; no claim that the experience sets or installs a wallpaper.
