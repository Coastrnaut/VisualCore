# Feature Specification: Effects Composer — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `179-ec-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A25-P00 (legacy ledger) · ID namespace FR-A25-0##, SC-A25-0##, T-A25-0##

**Input**: User description: archived manual `apps/25-effects-composer.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Effects Composer (`a25.effects-composer`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/EffectsComposer` (Auto-Creator.md §16 layout). It never gets a standalone target,
  bundle identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell"
  is met by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A24. The contract lives in `docs/apps/effects-composer/`.
- **Visuals are code:** the five effects and the built-in test image are generated in code; a person's imported image
  is their input, never bundled.
- **Constitution:** 2.21.0 adds the A25 experience rules (committed at the start of this gate, `eec911ea`).
- Follow `specs/172-gbl-p00-boundary-audit`.

## Clarifications

### Session 2026-11-19

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code by a read-only survey, then spot-checked:
- **Commits:** the A25 constitution commit is `eec911ea` and the A25-P00 specify commit is `a2d68e21`, the phase start
  for the no-change diff of `Packages` and `External`. The reference submodule is pinned at `d93edd1`.
- **Registry and catalog:** twenty-four experiences are registered in `Catalog/registrations.json` (A01–A24) and the
  candidates list is empty; `a25` is no registration (`AppModelTests` uses it as the synthetic not-yet-integrated id);
  the catalog lists Effects Composer as free, family "Developer and creator tools", launcher category tools,
  unavailable.
- **Host rule:** `RenderHost`, `ResourceRegistry`, `RenderScene` and `ExperiencePresenter` are main-actor. GL work
  happens only inside a scene's `setup`, `resize`, `render` and `teardown`, with the host's context current. A
  presenter receives a `RenderContext` (generation, pixel size, framebuffer, `resources`), never the host.
- **VisualCore offers** (public in a framework product and tested):
  - **passes and targets:** `FieldPass` (a full-screen fragment program with named `RenderTarget` inputs and
    `FieldUniform` values float, vec2, vec4 and int; `FieldPassError.compile`), `ResourceRegistry.makeRenderTarget`
    (completeness checked), `acquireTarget`/`recycle`/`trimPools`, `PingPongTarget`, `TextureFormat` rgba8, rgba16f and
    r8, `FloatRenderSupport`, `ResourceBudget` and `ResourceRegistry.stats`;
  - **an effects graph:** `EffectGraphDescription`, `EffectGraphValidator` (quota, cycles, at most 32 passes) and the
    GPU `EffectRenderer`/`EffectScene` with pooled targets, over a closed set of pass types (copy, colorMatrix, blur,
    bloom, distort, composite, feedback, flashLimit) whose runners and shaders are internal;
  - **shaders:** `ShaderLibrary` with `#include`, the bundled `vc/color.glsl` (`vc_srgbEncode`, `vc_srgbDecode`),
    `InfoLogParser` and `ShaderDiagnostic`, the program cache on `ResourceRegistry.program`;
  - **parameters and persistence:** `ParameterDefinition`, `ParameterSchema`, `ExperienceControl`, `ExperienceStorage`,
    `MigrationChain`, `DocumentStore`, `NamedLibrary` and versioned envelopes;
  - **export:** `RenderTarget.readPixels`, `RenderHost.renderOffscreen`, `StillImage`, `StillImageEncoder` (PNG,
    JPEG, HEIC through ImageIO, tagged sRGB), `ExportGeometry` (hard maximum edge 8,192) and `TemporaryFolder`;
  - **limits:** `RenderCapabilities.maxTextureSize` and `ResourceRegistry.maxTextureSize`.
- **Missing:**
  - a byte-wise upload into a render target: `Texture.upload(rgba:)` fills a `Texture`, which `FieldPass` cannot sample,
    and a `RenderTarget` takes only `upload(rgbaFloats:)` (four floats per pixel);
  - any image decoding into pixels (no CGImage or UIImage path) and any photo picker in the repository;
  - an sRGB texture format, `vec3` and `mat4` field uniforms, and a shared still-export `Transferable`.

- Q: How are the five effects drawn? → A: App-locally as `FieldPass` programs compiled from the experience's own
  linear chain (gaps G-EFFECTS and G-COMPILER, A25-P01 and A25-P02), after Visual Programming Lab's preview pipeline:
  each pass reads named targets and writes a pooled target, never the one it reads. The internal `EffectRenderer` pass
  set is not used, because new effects cannot be added to it from outside. Parameters wider than `vec4` are packed into
  several `vec4` uniforms; no VisualCore change is planned for passes or uniforms.
- Q: How does an imported image become an input? → A: The person picks it with the system photo picker, which runs out
  of process and needs no usage string or permission word (gap G-IMPORT, A25-P03); the experience decodes it with
  ImageIO into RGBA bytes on the CPU, scaled by a stated rule so its longer edge is at most the smaller of the texture
  limit and the experience's cap, and keeps those bytes so the source is uploaded again after a context loss. The
  upload needs a byte-wise `RenderTarget.upload(rgba:)` in VisualCoreRendering (gap U-RGBAUPLOAD, A25-P03, with tests,
  docs, the API baseline and the reference regression), because four floats per pixel would quadruple the memory of a
  large image. A cancelled pick leaves the built-in test image.
- Q: Where are colour-space boundaries? → A: The source and the export are sRGB-encoded bytes; each pass states whether
  it decodes to linear light (`vc_srgbDecode`) and encodes back (`vc_srgbEncode`), with intermediate targets in
  `rgba16f` where `FloatRenderSupport` reports it renderable and `rgba8` otherwise (gap G-COLOR, A25-P05).
- Q: How are diagnostics, presets and export owned? → A: App-locally. Compile and link failures arrive as
  `FieldPassError.compile` text and are mapped to `ShaderDiagnostic` lines after Shader Studio (gap G-DIAG, A25-P02).
  Presets are versioned envelopes in `ExperienceStorage` with damaged and newer files refused and never deleted
  automatically (gap G-PRESETS, A25-P04). Export renders the chain at the export size into a pooled target, reads it
  back, encodes it with `StillImageEncoder` after a size and format check against `ExportGeometry` and
  `StillImageEncoder.isAvailable`, and hands the file to a `Transferable` and `ShareLink` the person opens, after Living
  Wallpapers (gap G-EXPORT, A25-P04).
- Q: Which permission does the experience declare? → A: `photo-library-add`, like Living Wallpapers and Digital Zen
  Garden, because the share sheet's Save Image writes to the photo library; the app already carries
  `NSPhotoLibraryAddUsageDescription`. No read permission is declared, because the picker needs none. The
  registration's permissions are set when the experience registers (A25-P02) and checked at release (G-RELEASE).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Effects Composer gets a map of what VisualCore already provides for each capability the
experience needs (render graph, framebuffer pipelines, shader library, effect parameters, preset serialization, and
offscreen rendering and export) and for each version 0.1 feature. Every entry has real files, declared names and
package products, and is marked available, requires adaptation, or upstream gap.

**Why this priority**: the manual's first review gate; every later phase depends on it.

**Independent Test**: run the contract checker; every cited file exists, every cited name is declared, every product
exists, and every non-available row has a gap entry.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the checker runs, **Then** it passes with 0 problems.
2. **Given** a cited name that does not exist, **When** the checker runs, **Then** it fails naming it.
3. **Given** the six brainstorm capabilities and the six version 0.1 features, **When** the traceability is read,
   **Then** each maps to at least one matrix row.

---

### User Story 2 - The reference stays proven (Priority: P1)

The owner sees that the ProjectM reference regression passes before any Effects Composer work, and the starting commit
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

The engineer knows the one app builds for testing and its experience checks pass with Effects Composer absent. Phase
01 then starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Effects Composer is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Effects Composer can proceed, what is missing upstream, and which module
will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** drawing a full-screen pass that samples a texture into an offscreen target in the
   host's context were missing and could not be built over the existing renderer, **Then** the decision is "stop"
   and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example passes exist but no chain compiler): marked "requires adaptation"
  with the missing part named.
- **A capability exists only inside another experience** (for example another experience's graph compiler or image
  export): not counted as available; reuse needs it in VisualCore first, or it stays app-local by decision.
- **Colour-space mistakes** (the manual's risk 1): the audit records which textures and targets are linear or sRGB,
  and where pass colour boundaries are owned.
- **An image larger than the texture limit** (risk 2): the audit records where the limit is read and where the cap or
  scaling rule is owned.
- **Intermediate targets growing without bound** (risk 3): the audit records the target pool, budget and lifetime
  owner.
- **A preset file that is damaged, newer or holds non-finite numbers:** the audit records the versioned envelope and
  refusal support and where the preset format's policy is owned.
- **A denied or cancelled image pick:** the audit records that the built-in test image remains usable.
- **A context loss or resize during editing or export:** the audit records that targets are rebuilt from CPU state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A25-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (programs, full-screen passes with sampler inputs, render targets and their budget,
  read-back, texture upload, the GLSL library), the frame clock, diagnostics, the experience host, the build and
  release steps, source ownership and the reference regression steps, each with real paths.
- **FR-A25-002**: The contract MUST hold a capability matrix covering the six brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A25-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - the effect definition, node, chain, parameter and output-settings models, versioned and validated, with caps;
  - five built-in effects with bounded parameters;
  - compiling a linear chain into an ordered pass plan with intermediate-target lifetimes and a pass never sampling the
    target it writes;
  - a bounded pool of intermediate targets;
  - shader compile and link diagnostics visible to the experience;
  - reorder, enable and disable with an immediate preview;
  - a before and after compare that keeps the untouched source;
  - preset storage with versioned files, and refusal of damaged or newer files;
  - image import through the system picker with scoped access, and decoding to a texture within the texture limit;
  - colour-space boundaries (linear and sRGB);
  - still export at a validated size and format, rendered offscreen and encoded;
  - resize, orientation and context-loss handling.
- **FR-A25-004**: The ProjectM reference regression results for the phase-start tree MUST be recorded in two chunks
  with 7 of 7 steps passing. A baseline document MUST record the phase-start commit, the reference pin and the results.
- **FR-A25-005**: The one app MUST build for testing with Effects Composer absent. The experience package check MUST
  pass. Effects Composer MUST stay unregistered and unavailable; its targets come with A25-P01's first rules.
- **FR-A25-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking or upload, no private
    API, no user-written code, no video editing, no import without the person's pick, no claim of professional colour
    accuracy or preset compatibility with another editor, and no purchased, generated or photographic bundled images;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: colour-space
    mistakes, images above the texture limit, and unbounded intermediate targets;
  - a stop/go decision with reasons.
- **FR-A25-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A25-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A25-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (6) and version 0.1
  features (6) trace to matrix rows.
- **SC-A25-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A25-003**: The reference regression passes 7 of 7 steps in two chunks for the phase-start tree.
- **SC-A25-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (24 registered experiences, none of them A25).
- **SC-A25-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A25-006**: The contract checker finishes in under 10 seconds; each build or check runs in under 10 minutes
  (one foreground command each).

## Assumptions

- VisualCore provides the pieces earlier experiences used (the render host, field passes with sampler inputs, render
  targets, read-back, texture upload, the GLSL library, experience storage, versioned envelopes): the audit confirms
  each from the code and records what is missing.
- The effect definitions, the chain compiler's rules, copy and interface are app-local; generic pieces (for example an
  image decoder into a texture within the limit, or an image encoder for read-back) are assessed for VisualCore
  ownership.
- Later phases (A25-P01 to A25-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A25-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A25-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A25-005, US3 |
| Review gate: written stop/go decision | FR-A25-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A25-008 |
| Brainstorm capabilities (render graph, framebuffer pipelines, shader library, effect parameters, preset serialization, offscreen rendering and export) | FR-A25-002 |
| Manual non-goals and risks 1–3 | FR-A25-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network; no private API; no permission and no usage string yet; no effect implemented.
