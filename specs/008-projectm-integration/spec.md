# Feature Specification: Phase 7 — ProjectM Integration and Regression Hardening

**Feature Branch**: `008-projectm-integration` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F07 · ID namespace FR-F7##, SC-F7##, T-F7##

**Input**: User description: archived `sources/README.md` §10.9 Phase 7 prompt (verbatim in the invocation), plus
the canonical override: `External/projectm-ios` stays read-only (constitution II-a, ADR-0002/0003, FR-F110), so
"migration" means the `Harnesses/ProjectMReference` adapter (own `ProjectMReference.yml`, the only place rule R1
allows reference modules) drives the **unmodified** ProjectM engine through VisualCore APIs; migration-log
boundaries 2a and 2 are completed here; the reference pin is `d93edd1` (ADR-0005); device measurements are
deferred to campaign II (constitution V).

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2), best option chosen.

- Q: How is the "reference path" rendered for the baseline comparison, given the reference renderer's frame and readback methods are internal? → A: In-process A/B in lockstep: two unmodified `ProjectMEngine` instances on the same ANGLE path receive the same preset, PCM and frame sequence; path A reproduces the reference renderer's sequence (`renderFrameToFramebuffer` into an offscreen framebuffer owned by the harness, as `ANGLERenderer.renderFrame` does into its surface), path B renders through the VisualCore `RenderHost` scene. Frames are compared pairwise. The reference's own `testRendersTheUpstreamTestPreset` (ANGLERendering, passing at `d93edd1`) is the Phase 0 baseline sanity check.
- Q: Where does the adapter live and what may it link? → A: `Harnesses/ProjectMReference` with its own `ProjectMReference.yml`, linking local packages `Packages/VisualCoreRendering` (VisualCoreRendering, VisualCoreEffects) and the reference `External/projectm-ios/Packages/ProjectMBridge` (read-only); no AudioCore, PresetLibrary, CaptureKit or StoreKit. Rule R1 and the Showcase audit keep everything else ProjectM-free.
- Q: How is GL state handed between the engine and VisualCore? → A: A small app-neutral helper in VisualCoreRendering resets the GL state VisualCore relies on (vertex array, program, buffers, blend/depth/cull/scissor/stencil off, color mask, active texture unit, unpack alignment, framebuffer and viewport) after any foreign renderer draws; it belongs in VisualCore because any third-party GL engine sharing a context needs it.
- Q: What audio drives the engine in tests? → A: A deterministic synthesized stereo signal (sine sweep plus beat pulses) generated in the harness and fed in chunks no larger than the engine's per-call maximum; real audio capture stays in the reference and no audio-source compatibility is claimed.
- Q: Apply the `/speckit-analyze` remediation (C1 engine-creation failure test, C2 texture search path case)? → A: Yes, applied 2026-11-10 (no critical findings).
- Q: The engine compared with itself (two identical reference-sequence renderers in lockstep, no VisualCore) reaches only 97.4–98.9% of pixels within 8 (mean 0.23–0.35), so "≥ 99% within 8" is below the engine's own reproducibility — what is the baseline criterion? → A: Measured 2026-11-10 (`F07.t708-noise-floor`). SC-F702 becomes noise-floor relative: in the same test run, the VisualCore path vs the reference sequence must have mean absolute difference ≤ 2 (unchanged) and a within-8 fraction no lower than the engine's own A-vs-A′ minimum minus 1 percentage point, and never below 95%. The original absolute bar was set before measurement and cannot be met by any host; every measured number is recorded in the test log and the migration log.
- Q: What are the migration batches and their before/after evidence? → A: Batch 2a (GL state handoff + VisualCore effects over the engine) and batch 2 (engine on the VisualCore host). Before = reference regression and ANGLERendering preset render at `d93edd1` (ADR-0005 evidence) plus the path-A frames; after = harness tests, the A/B comparison and the reference regression rerun. Each batch gets its own migration-log row.

## User Scenarios & Testing *(mandatory)*

Users: the VisualCore maintainers and the owner, who need proof that the shared framework can host the existing
ProjectM visualizer without changing it, and a regression net that keeps both working as VisualCore evolves.

### User Story 1 - Run the unmodified ProjectM engine on the VisualCore host (Priority: P1) 🎯

A developer launches the reference harness and sees a ProjectM preset rendering through VisualCore's render host
(context, surface, frame pacing, resize, recreation) instead of the reference app's own renderer.

**Independent Test**: Harness simulator tests create the engine through the VisualCore host, load an upstream test
preset with deterministic audio, and read back non-trivial, changing frames.

**Acceptance Scenarios**:

1. **Given** the harness with the upstream test preset `100-square.milk` and a deterministic tone, **When** 30 frames render, **Then** the frames are not uniform and differ over time.
2. **Given** a running engine, **When** the view is resized or rotated, **Then** the engine's viewport follows and rendering continues.
3. **Given** a running engine, **When** the GL context is recreated, **Then** the engine is released with its old context current, recreated on the new one, and rendering resumes with no leaked VisualCore resources.
4. **Given** a preset that fails to load, **When** it is requested, **Then** the previous preset keeps rendering and the failure is reported (reference behavior FR-045 preserved).

---

### User Story 2 - Matches the Phase 0 baseline (Priority: P1)

The owner sees that the engine looks the same through VisualCore as through the reference's own renderer.

**Independent Test**: Render the same preset, audio and frame count through the reference renderer path and the
VisualCore path, compare images with a tolerance, and keep the comparison as before/after evidence.

**Acceptance Scenarios**:

1. **Given** identical preset, viewport, audio and frame sequence, **When** both paths render, **Then** the images agree within the documented tolerance.
2. **Given** each migration batch, **When** it lands, **Then** its before (reference path) and after (VisualCore path) evidence is recorded in the migration log.

---

### User Story 3 - VisualCore features on top of ProjectM output (Priority: P2)

A developer applies a VisualCore effect graph (including the Reduce Flashing limiter) and VisualCore-managed
resources to the engine's output in the same GL context, without disturbing the engine.

**Independent Test**: Simulator test runs the engine inside an effect scene and checks the effect is applied, the
engine keeps rendering, and GL state handed between the two does not corrupt either.

**Acceptance Scenarios**:

1. **Given** the engine wrapped in an effect scene with a color-swap pass, **When** frames render, **Then** the output shows the swapped colors of the engine image.
2. **Given** the engine changes GL state (program, blending, bound buffers), **When** VisualCore draws next, **Then** VisualCore's output is correct, and vice versa.

---

### User Story 4 - Lifecycle and cleanup regression (Priority: P2)

The owner trusts that repeated background/foreground cycles, rotations and resizes never leak or crash.

**Acceptance Scenarios**:

1. **Given** the harness, **When** it goes through 20 suspend/resume cycles and 10 resizes, **Then** it keeps rendering, VisualCore reports zero leaked resources and the engine is created exactly once per context generation.
2. **Given** the harness closes, **When** the host is destroyed, **Then** the engine is released before its context and no resources leak.

---

### User Story 5 - Documented boundaries (Priority: P2)

A maintainer can see, per boundary, what moved to VisualCore, why, the before/after evidence, and what stays
ProjectM-specific and why.

**Acceptance Scenarios**:

1. **Given** the migration log, **When** read after this phase, **Then** boundaries 2a and 2 have dates, VisualCore implementation, regression evidence and behavior notes, and a "retained in ProjectM" section lists the deliberately unextracted parts with reasons.

### Edge Cases

- Engine creation fails (no context or engine error): the harness shows the error and keeps the host alive.
- Missing preset file or texture search path: reported; previous preset continues.
- Zero-size view before layout: no engine call with a zero viewport.
- Audio buffer larger than the engine's per-call maximum: split into allowed chunks (tests use a deterministic synthesized signal; no capture).
- Reduce Flashing on: the limiter bounds the engine output's mean-luminance change.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F701**: A `Harnesses/ProjectMReference` app with its own project specification MUST host the unmodified ProjectM engine (through the reference `ProjectMBridge`) in a VisualCore render scene on the existing ANGLE path; it is the only target allowed to link reference modules (rule R1).
- **FR-F702**: The engine MUST be created with the VisualCore host's GL entry-point loader, sized from the host's drawable, rendered into the host's framebuffer each frame, and released on teardown with its context current (migration-log boundary 2).
- **FR-F703**: On context recreation the engine MUST be recreated on the new context and its current preset reloaded; on resize/rotation its viewport MUST follow.
- **FR-F704**: VisualCore resources, programs and effect graphs MUST coexist with the engine in one context: GL state the engine leaves behind must not break VisualCore drawing, and vice versa (migration-log boundary 2a). The state-handoff helper (reset of vertex array, program, buffers, blend/depth/cull/scissor/stencil, color mask, active texture, unpack alignment, framebuffer and viewport) lives in VisualCoreRendering and is app-neutral.
- **FR-F705**: A baseline comparison MUST render the same preset/audio/frames in lockstep through the reference renderer's sequence (path A: engine into an offscreen framebuffer) and the VisualCore host (path B) and report the pairwise image difference against the SC-F702 tolerance.
- **FR-F706**: Each migration batch (2a: GL state handoff + effects over the engine; 2: engine on the VisualCore host) MUST record before evidence (reference regression and preset render at the pin, path-A frames) and after evidence (harness tests, A/B comparison, reference regression rerun) in `docs/architecture/migration-log.md`.
- **FR-F707**: Lifecycle regression tests MUST cover repeated suspend/resume, resize/rotation, context recreation and destruction with zero leaked VisualCore resources.
- **FR-F708**: ProjectM engine, MilkDrop/preset handling (preset library, warm-up, purchases) and app behavior MUST stay in the submodule; the harness adds no preset library, StoreKit or audio-capture code and claims no audio-source compatibility.
- **FR-F709**: The reference MUST remain unmodified (clean check before/after), its ANGLE and engine pins unchanged, and the full reference regression MUST pass at the current pin.
- **FR-F710**: The migration log MUST document retained ProjectM-specific integration and why it was not extracted.

### Key Entities

- **Migration boundary**: id, VisualCore implementation, reason it belongs in VisualCore, before/after evidence, behavior change, retained parts.
- **Baseline comparison**: preset, viewport, audio signal, frame count, per-path image, difference metric, tolerance, result.
- **Harness diagnostics**: engine generation, frames, preset name, last error, VisualCore ledger snapshot.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F701**: The harness renders the upstream test preset through VisualCore on iOS 27.2 and 26.5 simulators with changing, non-uniform frames.
- **SC-F702**: The VisualCore-path image matches the reference-path image for the same inputs: mean absolute difference ≤ 2 of 255 per channel, and a fraction of pixels within 8 no lower than the engine's own run-to-run minimum (two identical reference-sequence renderers, same run) minus 1 percentage point, and never below 95% (clarification 2026-11-10, measured noise floor 97.4–98.9%).
- **SC-F703**: 20 suspend/resume cycles, 10 resizes and 3 context recreations complete with continuous rendering and 0 leaked VisualCore resources.
- **SC-F704**: The reference stays byte-for-byte unmodified, and its full regression passes at the pin before and after this phase.
- **SC-F705**: Every migrated boundary has before/after evidence and every retained ProjectM-specific part has a written reason.

## Assumptions

- Simulator results are functional only; frame-rate and thermal impact of hosting the engine through VisualCore are campaign-II measurements (constitution V).
- The harness is a tester tool and is not distributed; LGPL linkage stays as in the reference (engine as a separate dynamic framework). Distribution would need a fresh linkage analysis.
- Upstream test presets (`Vendor/projectM/presets/tests`) are readable from the simulator, as the reference's own tests do.
- The engine animates on wall-clock time internally and the bridge exposes no frame-time control, so two renders are never bit-identical; the A/B comparison interleaves the two paths per frame (microsecond skew) and judges them by the SC-F702 tolerance. Measured differences are recorded as evidence, never tuned away.
