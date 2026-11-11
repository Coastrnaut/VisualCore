# Feature Specification: Phase 4 — Reusable Effects and Render Pipelines

**Feature Branch**: `005-effects-graph` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F04 · ID namespace FR-F4##, SC-F4##, T-F4##

**Input**: User description: archived `sources/README.md` §10.6 Phase 4 prompt (verbatim in the
invocation), plus the canonical override: pure graph validation lives in `VisualCoreEffectsGraph`
and GPU passes in `VisualCoreEffects`. Device performance measurement is deferred to campaign II;
this phase records simulator functional evidence only.

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2), recommended option chosen.

- Q: Apply the `/speckit-analyze` remediation (E1 clamp/unknown-key tests; C1 device task deferred)? → A: Yes, applied 2026-11-10 (no critical findings).
- Q: Where does the Reduce-Flashing limiter run? → A: As a built-in `flashLimit` pass type that graphs can include, and automatically as the final step of `EffectScene` when its `reduceFlashing` flag is on. Apps set the flag from their own setting, which defaults to on when the system Reduce Motion setting is on (there is no public Dim Flashing Lights API to read).
- Q: How is "mean luminance" measured? → A: Rec. 709 luma of the sRGB-encoded output, averaged over a 16×16 downsampled grid. The GPU limiter keeps an adapted value and scales the frame toward it, so the displayed mean moves at most `limit × Δt` per frame.
- Q: How are feedback histories stored? → A: One history target per feedback pass, at that pass's output size. It is cleared (to the current input) on first use, resize and context recreation.
- Q: How are pass parameters encoded? → A: `params: [String: [Double]]` (scalars are 1-element arrays), JSON-codable. Each pass type documents its keys, defaults and clamping ranges; unknown keys are ignored with a warning.
- Q: What happens downstream of a failed pass? → A: The failed pass outputs a copy of its first input, so downstream passes keep their inputs and the graph always produces a final image (SC-F404).

## User Scenarios & Testing *(mandatory)*

Users: developers of effect-heavy apps (Effects Composer, Visual Programming Lab, Shader Studio,
Aurora, Fluid Art, the Showcase) who chain post-processing passes.

### User Story 1 - Describe a multi-pass effect safely (Priority: P1) 🎯

A developer (or an app's end user editing a node graph) describes passes with named inputs and
outputs. Invalid graphs (cycles, missing inputs, too many passes, too much memory) are rejected with
a specific reason before any GPU work.

**Independent Test**: Host fixtures of valid and invalid graphs; validation results compared with
expected errors and execution order.

**Acceptance Scenarios**:

1. **Given** passes A→B→C, **When** validated, **Then** the order is A, B, C (declaration order breaks ties).
2. **Given** a cycle B→C→B, **When** validated, **Then** it is rejected naming the passes in the cycle.
3. **Given** a pass reading an output nobody produces, **When** validated, **Then** it is rejected naming the pass and the input.
4. **Given** 33 passes or estimated textures above the memory quota, **When** validated, **Then** it is rejected with the count or the bytes.

---

### User Story 2 - Run built-in effects on the GPU (Priority: P1)

A developer applies color transform, blur, bloom/glow, distortion, composite and feedback passes
to a rendered scene and sees the expected pixels.

**Independent Test**: Simulator pixel tests per effect on known inputs (solid colors, a single
bright pixel, a gradient).

**Acceptance Scenarios**:

1. **Given** a red input and a matrix that swaps red and blue, **When** applied, **Then** output is blue.
2. **Given** a single bright pixel, **When** blurred with radius 4, **Then** its energy spreads to neighbors and peak brightness drops.
3. **Given** a dark image with one bright area, **When** bloom runs, **Then** pixels near the bright area brighten and dark pixels far away stay dark.
4. **Given** a feedback pass with decay 0.5, **When** two frames run over a constant input, **Then** the output converges toward the input as specified by the decay.
5. **Given** a pass whose shader fails, **When** the graph runs, **Then** that pass copies its input (pass-through) and the failure is reported once.

---

### User Story 3 - Reduce Flashing (Priority: P2)

A person with photosensitivity enables Reduce Flashing; any effect output that strobes between
dark and bright frames is limited so the displayed mean brightness changes slowly.

**Independent Test**: Host test of the luminance limiter model over a 30 Hz black/white strobe;
simulator test that the GPU limiter pass bounds the change per frame.

**Acceptance Scenarios**:

1. **Given** a 30 Hz full-screen black/white strobe and limit 0.3 per second, **When** limited for 1 s, **Then** the displayed mean luminance changes by at most 0.3 in that second.

### Edge Cases

- Duplicate pass IDs or two passes writing the same output: rejected.
- Unknown pass type: rejected with the type name.
- Graph with no reachable final output: rejected.
- View resize: intermediate targets are reallocated at the new scaled sizes; pooled targets are reused.
- Context recreation: passes recompile; graph keeps its description.
- Scale factor ≤ 0 or > 1: rejected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F401**: A graph description MUST list passes with id, type, named inputs (another pass output
  or `scene`), one output, resolution scale (0 < s ≤ 1) and parameters (`[String: [Double]]`, documented
  defaults and clamps, unknown keys warned); it MUST be versioned
  (version 1) and serializable.
- **FR-F402**: Validation MUST reject unsupported version, more than 32 passes, duplicate ids or
  outputs, unknown types, missing inputs, cycles (naming the cycle), invalid scales, missing graph
  output and memory estimates above the quota (default 256 MiB), each with a specific error.
- **FR-F403**: Valid graphs MUST produce a deterministic execution order (topological, ties by
  declaration order).
- **FR-F404**: Memory estimation MUST sum width·scale × height·scale × bytes-per-pixel per distinct
  output plus feedback history buffers.
- **FR-F412**: Each feedback pass MUST own one history target at its output size, cleared on first use,
  resize and recreation.
- **FR-F405**: Built-in passes MUST include copy, color matrix (4×4 + offset), separable Gaussian
  blur (radius 1–32), bloom/glow (threshold, intensity, radius), displacement distortion (strength,
  frequency, time), alpha composite (two inputs) and feedback (decay, previous-frame blend).
- **FR-F406**: Each pass MUST declare inputs, outputs, owned resources and configuration with
  documented ranges, clamping out-of-range parameters.
- **FR-F407**: Intermediate targets MUST come from the registry's pool and be recycled after use within a frame.
- **FR-F408**: A failing pass MUST degrade to pass-through (copy of its first input) and be reported
  once per graph build.
- **FR-F409**: A Reduce-Flashing limiter (pass type `flashLimit`, and the final step of `EffectScene` when
  `reduceFlashing` is on), measuring Rec. 709 luma over a 16×16 grid, MUST bound the change of displayed mean luminance per
  second (default 0.3) using a host-testable model and a GPU pass that applies it.
- **FR-F410**: An `EffectScene` MUST wrap any scene: render it into the `scene` target, run the
  graph, present the output, so the Showcase can use effects without ProjectM.
- **FR-F411**: Resizes and context recreations MUST rebuild targets and programs without losing the graph.

### Key Entities

- **EffectGraphDescription**: version, passes, output.
- **EffectPassDescription**: id, type, inputs (name → source), output, scale, params.
- **ValidatedGraph**: order, estimated bytes, warnings.
- **EffectGraphError**: one case per rejection.
- **FlashLimiterModel**: adapted luminance, limit per second.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F401**: 100% of the invalid-graph fixtures (cycle, missing input, duplicate, unknown type,
  33 passes, over quota, bad scale, missing output, bad version) are rejected before GPU work.
- **SC-F402**: Every built-in pass has at least one pixel test with an expected numeric outcome.
- **SC-F403**: Under a 30 Hz strobe, the limited mean luminance changes ≤ 0.3 per second (host model and GPU pass).
- **SC-F404**: A failing pass never stops the graph: the final image is still produced in 100% of fault-injection tests.
- **SC-F405**: The Showcase-ready `EffectScene` renders a scene + 3-pass graph with zero ProjectM symbols.

## Assumptions

- Simulator results are functional only (constitution V); device performance comes in campaign II.
- 8-bit sRGB-encoded targets by default (color-space policy); bloom uses rgba16f when requested.
- Graph descriptions are JSON-codable for apps that persist user graphs (Effects Composer, VPL).
