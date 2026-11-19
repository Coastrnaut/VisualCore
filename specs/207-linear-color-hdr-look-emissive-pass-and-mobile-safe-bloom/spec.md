# Feature Specification: R02-F07 — Linear-colour HDR-look emissive pass and mobile-safe bloom

**Feature Branch**: `207-linear-color-hdr-look-emissive-pass-and-mobile-safe-bloom` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: R02-F07 (migration ledger, shared round feature) · ID namespace FR-R02F07-###, SC-R02F07-###, T-R02F07-###

**Input**: User description: the archived R02-F07 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"linear scene values; half resolution blur; tone mapping; pre-multiplied alpha; flash reduction", with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/207-linear-color-hdr-look-emissive-pass-and-mobile-safe-bloom`;
  FR-R02F07-###, SC-R02F07-###, T-R02F07-###.
- **Section 13 disposition: extend.** The framework already has a data-described effect graph (`EffectRenderer` with
  copy, colour matrix, blur, bloom, distort, composite, feedback and flash-limit passes), a flash limiter that bounds
  how fast the picture's brightness may change (`FlashLimiterModel`, applied last by `EffectScene` when flashing is
  reduced), half-float render targets where the device draws into them (`FloatRenderSupport`), pooled targets and the
  sRGB transfer functions (`vc/color.glsl`). Its bloom works on display-encoded values at full size and clamps every
  value to 1, and no pass tone-maps or composites premultiplied colour. This feature adds one new pass type that the 75
  games use for glowing, emissive looks: linear-light bright extraction, a half- or quarter-resolution blur, exposure
  and tone mapping, and a premultiplied composite; and a premultiplied blend preset for drawing emissive layers. The
  existing passes, graphs and the two experiences that use bloom keep their output.
- **Who the users are:** the engineer of one of the 75 games, who wants neon edges, stars and sparks that glow without
  washing out or banding and without costing a full-size blur every frame; the player, who sees a glow that is never
  harsh or flashing; a person who asks the app to reduce flashing, for whom the glow never flashes either.
- **Prerequisites:** R02-F06 (safe shader compilation) and UA-F02 are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** frame cost and thermal behaviour of the glow on D1–D3 are device
  campaign items. **Owner-only items:** none.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A glow that behaves like light (Priority: P1) 🎯

A game engineer adds the emissive pass to a scene's effect graph. Bright parts glow; the glow adds light rather than
grey; very bright parts roll off smoothly instead of clipping to flat white; parts below the threshold are untouched.

**Why this priority**: the glowing look is shared by every game; doing it in encoded values produces muddy halos and
clipped highlights.

**Independent Test**: run the pass on generated pictures and compare pixels with a CPU reference of the same formulas.

**Acceptance Scenarios**:

1. **Given** a picture with no value above the threshold, **When** the pass runs with tone mapping off and exposure 0,
   **Then** the output equals the input within one code value.
2. **Given** a bright point on black, **When** the pass runs, **Then** the glow around it falls off smoothly with
   distance and matches the CPU reference within the stated tolerance.
3. **Given** values far above 1 (on a high-precision path), **When** tone mapping is on, **Then** the result stays
   below 1, increases with the input and matches the chosen operator's CPU reference.

---

### User Story 2 - Cheap enough for phones (Priority: P1)

The blur runs at half (or quarter) resolution and the result is scaled back up, so the glow costs a fraction of a
full-size blur; on a device without high-precision targets the pass still works, with a stated reduced range.

**Independent Test**: inspect the sizes of the targets the pass uses and the output on both precision paths.

**Acceptance Scenarios**:

1. **Given** a 512 × 512 scene, **When** the pass runs at half quality, **Then** its blur targets are 256 × 256 (128 ×
   128 at quarter quality) and the output is 512 × 512.
2. **Given** high precision is unavailable (forced in tests), **When** the pass runs, **Then** it uses standard
   precision, produces a valid output and reports the reduced range once.
3. **Given** repeated frames, **When** the pass runs 100 times, **Then** the pooled target count stays constant.

---

### User Story 3 - Layers that blend correctly (Priority: P2)

An engineer draws emissive sprites or a glow layer with premultiplied colour and composites it over the scene; edges
have no dark or bright fringes.

**Independent Test**: composite a premultiplied layer with soft edges and compare with the premultiplied "over"
formula.

**Acceptance Scenarios**:

1. **Given** a premultiplied layer with alpha falling from 1 to 0, **When** composited over a scene, **Then** every
   pixel equals `layer + scene × (1 − layer alpha)` within one code value.
2. **Given** the premultiplied blend preset, **When** a premultiplied sprite is drawn, **Then** the framebuffer holds
   the same result.

---

### User Story 4 - The glow never flashes (Priority: P1)

With "reduce flashing" on, a glow that pulses or strobes is still bounded by the flash limiter; with it off, the glow
follows the scene.

**Independent Test**: strobe the input of a graph containing the pass and measure the brightness change per second of
the output.

**Acceptance Scenarios**:

1. **Given** a 30 Hz strobe of bright and dark frames through the emissive pass, **When** flashing is reduced, **Then**
   the mean brightness of the output changes by no more than the limiter's rate per second.
2. **Given** the same strobe, **When** flashing is not reduced, **Then** the output follows the input.

### Edge Cases

- **A threshold of 0:** everything glows; the result stays finite.
- **Radius at its maximum on a tiny target:** the blur clamps at the edges; no sampling outside the picture.
- **Non-finite or out-of-range parameters:** refused by the graph validator before any target is made.
- **A context rebuild:** the pass's targets and programs are made again; the next output equals the one before.
- **The existing bloom pass:** unchanged, byte for byte, on its existing fixtures.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F07-001**: A new effect pass type MUST decode its input from sRGB to linear light, extract light above a
  threshold (in linear units, soft knee), blur it at half or quarter resolution, add it back scaled by an intensity,
  apply an exposure, tone-map with a selectable operator (none, Reinhard, a fitted filmic curve) and encode back to
  sRGB, keeping the input's alpha.
- **FR-R02F07-002**: Intermediate targets of the pass MUST be high precision where the device can draw into it and
  standard precision otherwise, with the reduced range reported once; the blur targets MUST be half or quarter of the
  output size; targets come from the pool and are returned every frame.
- **FR-R02F07-003**: The pass's parameters MUST be declared in the graph schema with ranges and defaults and validated
  before any target is made; its memory estimate MUST count every target it uses.
- **FR-R02F07-004**: A premultiplied composite mode and a premultiplied blend preset MUST exist and follow
  `src + dst × (1 − src alpha)`.
- **FR-R02F07-005**: When flashing is reduced, the output of a graph containing the pass MUST stay within the flash
  limiter's rate; the limiter MUST measure brightness in linear light for graphs that contain the new pass.
- **FR-R02F07-006**: A CPU reference of the pass's formulas (decode, bright extraction, the tone-mapping operators,
  encode) MUST exist in the pure package and the GPU output MUST match it within stated tolerances.
- **FR-R02F07-007**: The existing passes, graphs, fixtures and the experiences that use them MUST produce unchanged
  output; every new public name carries documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Emissive pass parameters**: threshold, knee, intensity, radius, quality (half or quarter), exposure, tone-mapping
  operator.
- **Tone-mapping operator**: none, Reinhard, filmic.
- **Premultiplied composite and blend preset.**

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F07-001**: Below the threshold the output equals the input within 1/255 at every pixel; around a bright
  point the glow matches the CPU reference within 2/255 on the high-precision path and 4/255 on the standard path.
- **SC-R02F07-002**: Tone-mapped results are below 1 and increasing for inputs from 0 to 64 and match each operator's
  CPU reference within 2/255.
- **SC-R02F07-003**: Blur targets are exactly half (or quarter) of the output size; 100 frames leave the pooled target
  count unchanged.
- **SC-R02F07-004**: Premultiplied composites equal the formula within 1/255 at every pixel.
- **SC-R02F07-005**: With flashing reduced, a 30 Hz strobe through the pass changes the output's mean brightness by no
  more than the limiter's rate per second.
- **SC-R02F07-006**: Existing bloom, composite and limiter fixtures and the experiences' tests pass unchanged; the
  reference regression passes 7 of 7; each unit test finishes in under 10 seconds.

## Assumptions

- The scene is drawn into an 8-bit sRGB-encoded target as today; making whole scenes high precision is outside this
  slice (games that need it draw their emissive layer premultiplied and use the pass).
- The fitted filmic curve is the published Narkowicz approximation of the ACES film curve, written in code.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Linear scene values | FR-R02F07-001, 006 |
| Half resolution blur | FR-R02F07-002, 003 |
| Tone mapping | FR-R02F07-001, 006 |
| Pre-multiplied alpha | FR-R02F07-004 |
| Flash reduction | FR-R02F07-005 |
| No Stage One breakage | FR-R02F07-007 |

## Negative Requirements / Excluded scope

- No second renderer or context; no full-scene HDR target in this slice; no image assets or lookup-table files; no
  change to the existing bloom pass's output; no device run before ImplementationLock-100.
