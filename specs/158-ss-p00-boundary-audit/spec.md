# Feature Specification: Shader Studio — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `158-ss-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A22-P00 (legacy ledger) · ID namespace FR-A22-0##, SC-A22-0##, T-A22-0##

**Input**: User description: archived manual `apps/22-shader-studio.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Shader Studio (`a22.shader-studio`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/ShaderStudio` (Auto-Creator.md §16 layout). It never gets a standalone target, bundle
  identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met
  by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A21. The contract lives in `docs/apps/shader-studio/`.
- **Visuals are code:** templates, their textures and every preview are code; no purchased, generated or
  photographic image.
- **Constitution:** 2.18.0 adds the A22 experience rules (committed at the start of this gate, `27d7d83e`); 2.18.1 words its compile rule for the main-thread host (checklist CHK006).
- Follow `specs/151-au-p00-boundary-audit`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code by a read-only survey, then spot-checked:
- **Commits:** the A22 constitution commit is `27d7d83e` and the A22-P00 specify commit is `6218b9a1`, the phase start
  for the no-change diff of `Packages` and `External`. The reference submodule is pinned at `d93edd1`.
- **Registry and catalog:**
  - twenty-one experiences are registered in `Catalog/registrations.json` (A01–A21), and the candidates list is empty;
  - `a22` appears in neither `Catalog/registrations.json` nor `Apps/VisualCore/App/ExperienceRegistry.swift`, and
    `AppModelTests` uses it as a synthetic not-yet-integrated id;
  - `release_check.py --list` prints 163 lines;
  - the catalog lists Shader Studio as free, family "Developer and creator tools", launcher category tools.
- **Host rule:** `RenderHost`, `ResourceRegistry`, `ShaderProgram`, `RenderScene` and the presenter are main-actor.
  GL work happens only inside a scene's `setup`, `resize`, `render` and `teardown`, with the host's context current.
  The pure modules (shader source, parameters, persistence, diagnostics) are `Sendable`.
- **VisualCore offers** (public in a framework product and tested):
  - **source expansion:** `ShaderLibrary` (VisualCoreShaderSource) expands `#include`s and defines up to 64 KiB, at
    most 8 levels deep. It accepts only `#version 300 es`, inserts the version line when it is missing, and records
    each expanded line's `SourceOrigin` (`ExpandedShader.origin(ofExpandedLine:)`). It adds no precision line and no
    `#line`. Its refusals are `ShaderSourceError`;
  - **diagnostics:** `InfoLogParser.parse(_:stage:map:)` turns a compile or link log into `[ShaderDiagnostic]`
    (file, line, stage, severity, message; line only, no column) mapped to the original file and line;
  - **compile and link:** `ResourceRegistry.program(vertex:fragment:defines:library:…)` throws
    `ShaderError.source`, `.compile([ShaderDiagnostic])` or `.link([ShaderDiagnostic])`, and a failure never touches a
    program the caller holds. It keeps a 64-program LRU cache. `ShaderProgram` reads the active uniforms (name, type,
    size) and has typed setters. `ShaderProgram.lastFailureLog` is one global string;
  - **full-screen drawing:** `FullScreenShaderScene` binds `u_time`, `u_resolution`, `u_seed`, an 8-entry palette and
    one float per parameter. Its source is fixed at creation, it keeps only the first diagnostic, it has no texture
    input, and a failure draws dark grey;
  - **capabilities:** `RenderCapabilities` (GL and GLSL versions, extensions, texture, viewport and uniform limits,
    shader precisions) on `RenderHost.capabilities`; the context is GLSL ES 3.00 only;
  - **textures and targets:** `ResourceRegistry.makeTexture`, `Texture.upload(rgba:)`, `makeRenderTarget`,
    `ResourceRegistry.stats`, `ResourceBudget` (256 MiB);
  - **parameters:** `ParameterDefinition`, `ParameterSchema` (at most 64, NaN refused, out of range clamped),
    `ParameterEditor`;
  - **persistence:** `ExperienceStorage.write(_:to:)`, `read`, `list` and `remove` under `StorageQuota` (64 files,
    16 MiB), `setValue(_:for:)` (64 values of 4 KB), `ExperienceSnapshot` and `MigrationChain`;
    VisualCorePersistence's `DocumentStore` and `NamedLibrary` work on a directory, not on the experience storage;
  - **pacing:** `FramePacing`, `PacingMeter`, `PerformanceRecord` and the presenter's `maxFramesPerSecond`.
- **Missing everywhere:**
  - a watchdog or frame-time budget for a slow shader, and no hang detection;
  - a code editor, line-numbered text view or syntax assistance;
  - a scene that swaps in a new program only on success and keeps the last good one;
  - texture inputs for a full-screen shader;
  - a library of named files over the experience storage (Digital Zen Garden's `GardenLibrary` is app-local and
    internal);
  - per-shader compile logs (only the global `lastFailureLog`).

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: As for A21: the one app is the shell.
  This phase proves it builds for testing with Shader Studio absent, and the targets come with A22-P01's first model.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least
  one test that exercises it. An implementation that exists only inside another experience or a harness is "requires
  adaptation" at best.
- Q: How are compiling, diagnostics and the last-good preview built from what exists? → A:
  - **Assembly:** the person's fragment source is placed into the template with `ShaderLibrary`. The `vc/` includes
    and a precision line come first.
  - **Compile:** it goes through `ResourceRegistry.program` in an app-local preview scene, inside the host's context.
  - **Diagnostics:** the `[ShaderDiagnostic]` of `ShaderError` are mapped back through the expansion's origins to the
    person's lines. Diagnostics are line-only, and the column stays optional (none is shown).
  - **Swap:** the scene swaps programs only on success and keeps the last good one otherwise. That is an app-local gap
    (`FullScreenShaderScene` cannot replace its source and drops later diagnostics), with no VisualCore change
    planned; a second user would justify moving the swap upstream later.
  - **Per-shader logs:** the global `lastFailureLog` is not relied on.
- Q: How are resource limits and the watchdog handled when VisualCore has none? → A:
  - **Caps first:** the source size, line count, uniforms, inputs and the preview size are checked by an app-local
    pure validator before any compile. The expansion's own 64 KiB limit stays the hard ceiling.
  - **Preview pacing:** the preview is drawn at a capped size and at most 30 frames per second (the presenter's
    `maxFramesPerSecond`).
  - **Watchdog:** an app-local watchdog reads the drawn-frame intervals (`PacingMeter`). When frames stay slower than
    its limit, it stops the preview and offers a reset to the last good program.
  - **No sandbox claim:** a GPU shader can still hang a driver, and no sandbox is claimed.
- Q: Where do the editor, the project files, the texture inputs and the compatibility profile live? → A:
  - **Editor:** app-local SwiftUI, a monospaced text editor with line numbers, a diagnostics list that jumps to a
    line, and a hardware keyboard, iPad first;
  - **Project files:** named files in `ExperienceStorage`, after Digital Zen Garden's library (versioned envelopes,
    a capped count and size, damaged and newer files refused and never deleted). This is an app-local adaptation;
  - **Texture inputs:** small textures generated in code and uploaded with `Texture.upload(rgba:)` in the preview
    scene, an app-local adaptation;
  - **Compatibility profile:** read from `RenderCapabilities` (GLSL ES 3.00 only, highp, uniform and texture limits),
    available.

  No upstream gap is planned for Phase 00's decision.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Shader Studio gets a map of what VisualCore already provides for each capability the
experience needs (shader compilation, diagnostics and error reporting, render previews, the shader asset pipeline
and parameter controls) and for each version 0.1 feature. Every entry has real files, declared names and package
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

The owner sees that the ProjectM reference regression passes before any Shader Studio work, and the starting commit
is recorded, so later phases can prove what they changed upstream.

**Independent Test**: the regression's results are recorded for an unchanged tree; the baseline document names the
commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** its two chunks are read for the phase-start tree, **Then** 7 of 7
   steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Shader Studio absent. Phase 01
then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Shader Studio is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Shader Studio can proceed, what is missing upstream, and which module
will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** compiling a runtime fragment shader in the host's context, reading its compile
   log, or drawing it full screen were missing and could not be built over the existing renderer, **Then** the
   decision is "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example a compile that fails without a structured log): marked "requires
  adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example another experience's runtime shader rebuild):
  not counted as available; reuse needs it in VisualCore first, or it stays app-local by decision.
- **Expensive or hanging shaders** (the manual's risk 1): the audit records the caps on source and preview, the stop
  and reset, and that no execution sandbox is claimed.
- **Editing on a small screen** (the manual's risk 2): the audit records the editor's ownership, hardware-keyboard
  support and the iPad-first layout.
- **Shader language support varies** (the manual's risk 3): the audit records which capability queries exist and
  where the compatibility profile is owned.
- **A compile requested while another waits:** only the newest request is kept, and at most one compile runs per
  frame.
- **Line numbers shifted by inserted code:** the audit records where a prefix (version, precision, includes) is added
  and how the person's line numbers are recovered.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A22-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (shader compilation and linking, full-screen shaders, the GLSL library, textures and
  render targets, capability queries), the experience host, the build and release steps, source ownership and the
  reference regression steps, each with real paths.
- **FR-A22-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A22-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - the project, template and uniform models, versioned and validated, with documented caps;
  - a source validator run before any compile (size, lines, uniforms, inputs);
  - compiling and linking a person's fragment shader in the host's context, with the complete log captured. The
    host's thread is the main thread (VisualCore has no other GL thread), so a compile is never run from a control's
    action: the action queues a request that the preview scene compiles at its next frame, after the pre-compile caps,
    one request at a time, with the newest request replacing a waiting one;
  - mapping log lines to the person's lines after inserted template code;
  - an explicit Compile and Run action that swaps programs only on success and keeps the last good preview;
  - a bounded preview surface (size and frame rate) with a stop, reset and watchdog for slow frames;
  - a parameter inspector for bounded uniforms and defined texture inputs made in code;
  - local project save and open with versioned files, and refusal of damaged or newer files;
  - a code editor with line numbers, syntax assistance and a hardware keyboard;
  - a compatibility profile from the host's capability queries;
  - resize, orientation and context-loss rebuild from the project's source.
- **FR-A22-004**: The ProjectM reference regression results for the phase-start tree MUST be recorded in two chunks
  with 7 of 7 steps passing. A baseline document MUST record the phase-start commit, the reference pin and the results.
- **FR-A22-005**: The one app MUST build for testing with Shader Studio absent. The experience package check MUST
  pass. Shader Studio MUST stay unregistered and unavailable; its targets come with A22-P01's first rules.
- **FR-A22-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking, no shader gallery or
    marketplace, no private API, no compile off the host's thread, no sandbox claim, no unmeasured performance claim,
    and no purchased, generated or photographic images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: expensive
    driver behaviour from user shaders, editor ergonomics on iPhone, and varying shader language support;
  - a stop/go decision with reasons.
- **FR-A22-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A22-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A22-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A22-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A22-003**: The reference regression passes 7 of 7 steps in two chunks for the phase-start tree.
- **SC-A22-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (21 registered experiences, none of them A22).
- **SC-A22-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A22-006**: The contract checker finishes in under 10 seconds; each build or check runs in under 10 minutes
  (one foreground command each).

## Assumptions

- VisualCore provides the pieces earlier experiences used (full-screen shader scenes, the GLSL library, shader
  compilation inside its scenes, capability probes, parameters, experience storage and named files as Digital Zen
  Garden used them): the audit confirms each from the code and records what is missing.
- The templates, editor, copy and interface are app-local; generic pieces are assessed for VisualCore ownership.
- Later phases (A22-P01 to A22-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A22-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A22-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A22-005, US3 |
| Review gate: written stop/go decision | FR-A22-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A22-008 |
| Brainstorm capabilities (shader compilation, diagnostics and error reporting, render previews, shader asset pipeline, parameter controls) | FR-A22-002 |
| Manual non-goals and risks 1–3 | FR-A22-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no private API; no permission and no usage string.
