# Feature Specification: Aurora — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `151-au-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A21-P00 (legacy ledger) · ID namespace FR-A21-0##, SC-A21-0##, T-A21-0##

**Input**: User description: archived manual `apps/21-aurora.md` §9 Phase 00 `/speckit-specify` prompt (verbatim in
the invocation).

Canonical overrides:
- **One app (ADR-0009):** Aurora (`a21.aurora`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/Aurora` (Auto-Creator.md §16 layout). It never gets a standalone target, bundle
  identifier, in-app product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met
  by the one app itself, and nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for
  A01–A20. The contract lives in `docs/apps/aurora/`.
- **Visuals and sound are code:** aurora ribbons, stars, clouds and glow are procedural, and the optional ambient loop
  (manual feature 05, "locally bundled, licensed") is synthesised in code; no purchased, generated or photographic
  image and no bundled recording.
- **Constitution:** 2.17.0 adds the A21 experience rules (committed at the start of this gate, `d143ebd2`).
- Follow `specs/144-zg-p00-boundary-audit`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code by a read-only survey:
- **Commits:** the A21 constitution commit is `d143ebd2` and the A21-P00 specify commit is `b40fdbee`, the phase
  start for the no-change diff of `Packages` and `External`. The reference submodule is pinned at `d93edd1`.
- **Registry:** twenty experiences are registered in `Catalog/registrations.json` (A01–A20), and the candidates list
  is empty. `a21` appears in neither `Catalog/registrations.json` nor `Apps/VisualCore/App/ExperienceRegistry.swift`;
  `AppModelTests` uses it as a synthetic not-yet-integrated id. `release_check.py --list` prints 158 lines. The
  catalog lists Aurora as free, family "Ambient and lifestyle", launcher category ambient.
- **Host rule:** `RenderHost`, `RenderScene`, the presenter, the shell and the action port are main-actor; the core is
  a `Sendable` value advanced in fixed steps (`ExperienceEngine.advance(frame:)`) that never reads a clock or draws.
- **VisualCore offers** (public in a framework product and tested):
  - **procedural shaders:** `FullScreenShaderScene` (`u_time`, `u_resolution`, `u_seed`, an 8-entry palette, one
    float per parameter, `fixedTime`, `timeScale`), `ShaderBundle` with the `vc/` GLSL library (`vc_valueNoise`,
    `vc_gradientNoise`, `vc_fbm`, hashes, `vc_palette`, sRGB encode and decode, SDFs), `FieldPass`, `EffectScene`;
  - **noise:** the GLSL noise above and CPU `GradientNoise2D` and `FractalNoise2D`;
  - **particles:** `ParticleSystem` with emitters, forces and `ParticleBudget`; `ParticleRenderer` (instanced soft
    quads, normal or additive) and `ParticleLayerScene` with `brightnessCap`;
  - **animation:** `FrameInfo` (its `time` is wall-clock; `delta` is clamped to 0…0.1 s), `SceneClock` (advances
    only by frame deltas, each step capped at 0.25 s, `reducedMotionFactor` 0.5, speed, play, pause, scrub),
    `FramePacing` (floor 30 frames per second; 30 under Low Power Mode or a serious thermal state, render scale 0.75
    when critical) applied by the host's `FrameScheduler`, `maxFramesPerSecond`, `CachedScene`;
  - **blending and compositing:** `RenderState.BlendMode` (alpha, premultiplied, additive), render targets through
    `ResourceRegistry.makeRenderTarget`, `PingPongTarget`, `FloatRenderSupport`, the effect graph's bloom pass,
    `FlashLimiterModel` (limits the rate of change of mean luminance, default 0.3 per second, as
    `EffectScene.reduceFlashing`), and `brightnessCap` only on `TrailLayer` and `ParticleLayerScene`;
  - **transitions:** `CrossfadeScene` (`progress` 0…1 set by the caller, two lazy RGBA8 targets, a linear mix), used
    by Ambient Clock; easing curves in VisualCoreMath;
  - **persistence:** `ExperienceSnapshot`, `MigrationChain`, `ExperienceStorage` with `setValue(_:for:)` (64 values of
    4 KB) under `StorageQuota`;
  - **sound:** `SoundEffectPlayer` (ambient session, four one-shot voices of at most 1 s, stops on interruption and in
    the background, no player volume) over `SoundEffectSynth`;
  - **precision and power:** `RenderCapabilities.fragmentHighp` and `fragmentMantissaBits`, `DeviceConditions`,
    `QualityPolicy`, `QualityGovernor`; `FullScreenShaderScene` records a compile error and clears to dark grey;
  - **accessibility:** `AccessibilityPreferences`, `SystemAccessibilityObserver`, `ExperienceLaunch.reduceMotion` and
    `reduceFlashing`.
- **Missing everywhere:** a continuous or looping sound player with a volume; a luminance cap for an arbitrary scene;
  tone mapping; a hide-and-restore or full-screen mode for an experience's controls; a static fallback frame when a
  shader feature is unsupported; CPU value noise.

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: As for A20: the one app is the shell.
  This phase proves it builds for testing with Aurora absent, and the targets come with A21-P01's first model.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least
  one test that exercises it. An implementation that exists only inside another experience or a harness is "requires
  adaptation" at best.
- Q: How are the sky, its light and its time built from what exists? → A: The sky is app-local shaders over `vc/` in
  `FullScreenShaderScene` passes: aurora ribbons as slowly advected fbm colour bands, a hashed starfield with bounded
  twinkle, and fbm cloud layers, at two quality levels. Rendered time comes from `SceneClock` into `fixedTime`, never
  from `FrameInfo.time`, so a return from the background never jumps. An app-local final composite pass applies an
  explicit luminance cap, and transitions run through `CrossfadeScene` with the cap applied after the mix, so no
  transition exceeds it. A static fallback frame uses `RenderCapabilities` and `CachedScene`. The low-power view
  rests on the host's `FramePacing` and an app-local still view. These are app-local gaps: no VisualCore change is
  planned, and a second user of a luminance cap would justify moving it upstream later.
- Q: How is the optional ambient loop built, given that VisualCore has only one-shot tones? → A: It is synthesised in
  code (constitution 2.17.0), which replaces the manual's "locally bundled, licensed" loop; no media licence is needed,
  so risk 3 is met by construction. A continuous speaker-output player is generic, so it is an upstream gap owned by
  VisualCoreAudio: an ambient loop player on the ambient session with its own volume (0…1), stopped on interruption
  and in the background, playing a procedural buffer from VisualCoreAudioDSP. It is built in A21-P04 with tests,
  documentation, the API baseline and the reference regression; sound stays off by default and never changes the
  state.
- Q: How do the controls hide and come back in the one app? → A: In the experience: its control overlay hides on
  request and returns with a tap on the canvas or the accessibility action "Show controls"; the app's shell and the
  host are unchanged (no full-screen mode exists, and none is added). Reduce Motion gives a stable frame and Reduce
  Flashing is honoured through `ExperienceLaunch`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Aurora gets a map of what VisualCore already provides. It covers each capability the
experience needs (procedural shaders, noise functions, particle systems, animation, blending and compositing) and each
version 0.1 feature. Every entry has real files, declared names and package products, and is marked available,
requires adaptation, or upstream gap.

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

The owner sees that the ProjectM reference regression passes before any Aurora work, and the starting commit is
recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's results are recorded for an unchanged tree; the baseline document names the
commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** its two chunks are read for the phase-start tree, **Then** 7 of 7
   steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Aurora absent. Phase 01 then
starts by adding the experience's targets with real rules, and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Aurora is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Aurora can proceed, what is missing upstream, and which module will own
each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host, full-screen shader drawing or additive compositing into a render
   target were missing and could not be built over the existing renderer, **Then** the decision is "stop" and names the
   blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example one-shot tones but no continuous loop): marked "requires
  adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example another experience's crossfade or starfield):
  not counted as available; reuse needs it in VisualCore first, or it stays app-local by decision.
- **Expensive volumetric layers** (the manual's risk 1): the audit records that the sky is 2D layered shaders and
  where the quality levels and low-power view are owned.
- **Bright or flashing imagery** (the manual's risk 2): the audit records the luminance cap, the comfort bounds on
  ribbon frequency and brightness, and where Reduce Motion and Reduce Flashing reach the experience.
- **Soundtrack licensing** (the manual's risk 3): the audit records that the loop is synthesised in code, so no media
  licence is needed, and where the separate volume control is owned.
- **A long time in the background:** the audit records how rendered animation time is kept apart from wall-clock time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A21-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces (full-screen shaders, the GLSL library, render targets and blending, particles), the
  experience host, the build and release steps, source ownership and the reference regression steps, each with real
  paths.
- **FR-A21-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A21-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local)
  and the phase that will build it. At least these MUST be assessed:
  - the sky scene, presets, palettes and controls with bounds, versioned and validated;
  - aurora ribbons from layered noise, a starfield and cloud layers, drawn in bounded passes;
  - compositing with an explicit luminance cap and comfort bounds on ribbon frequency;
  - scene transitions that never exceed the cap, and saved preferences;
  - rendered animation time kept apart from wall-clock time;
  - a low-power static view, a reduced-flash mode, Reduce Motion and Reduce Flashing;
  - an optional synthesised ambient loop with its own volume, independent of the drawing lifecycle;
  - a full-screen view whose controls hide and return with a tap or an accessibility action;
  - a static fallback frame when a shader feature or precision is unsupported;
  - resize, orientation and context-loss rebuild, and release of GPU targets on theme changes.
- **FR-A21-004**: The ProjectM reference regression results for the phase-start tree MUST be recorded in two chunks
  with 7 of 7 steps passing. A baseline document MUST record the phase-start commit, the reference pin and the results.
- **FR-A21-005**: The one app MUST build for testing with Aurora absent. The experience package check MUST pass. Aurora
  MUST stay unregistered and unavailable; its targets come with A21-P01's first rules.
- **FR-A21-006**: The contract MUST record:
  - the negative rules: no EGL path of its own, no second renderer, no ProjectM, no networking, no location, no
    private API, no aurora forecast or scientific claim, no therapeutic or sleep claim, no always-on-screen promise, no
    required background audio, and no purchased, generated or photographic images or bundled recordings;
  - the manual's three risks, each with an owner, a verification method and a release-blocker condition: battery
    drain from expensive layers, bright or flashing imagery, and soundtrack licensing;
  - a stop/go decision with reasons.
- **FR-A21-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A21-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A21-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A21-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A21-003**: The reference regression passes 7 of 7 steps in two chunks for the phase-start tree.
- **SC-A21-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (20 registered experiences, none of them A21).
- **SC-A21-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A21-006**: The contract checker finishes in under 10 seconds; each build or check runs in under 10 minutes
  (one foreground command each).

## Assumptions

- VisualCore provides the pieces earlier experiences used (the GLSL noise library, full-screen shader scenes, render
  targets, particles, Ambient Clock's crossfades and cached still frame, procedural one-shot tones): the audit confirms
  each from the code and records what is missing.
- The presets, palettes, copy and interface are app-local; generic pieces are assessed for VisualCore ownership.
- Later phases (A21-P01 to A21-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A21-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A21-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A21-005, US3 |
| Review gate: written stop/go decision | FR-A21-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A21-008 |
| Brainstorm capabilities (procedural shaders, noise functions, particle systems, animation, blending and compositing) | FR-A21-002 |
| Manual non-goals and risks 1–3 | FR-A21-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork or
  recording; no network; no location; no private API; no permission and no usage string.
