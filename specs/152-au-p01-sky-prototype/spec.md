# Feature Specification: Aurora — Phase 01 Noise and ribbon sky prototype

**Feature Branch**: `152-au-p01-sky-prototype` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A21-P01 (legacy ledger) · ID namespace FR-A21-1##, SC-A21-1##, T-A21-1##

**Input**: User description: archived manual `apps/21-aurora.md` §9 Phase 01 `/speckit-specify` prompt (verbatim in
the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: three procedural sky presets with aurora ribbons, stars and cloud layers (here as data, a reference computed
    without the GPU and the sky drawn off screen by the core's tests; the experience's presenter comes in A21-P02);
  - regression fixture: a reduced-motion scene produces a stable frame;
  - graphics context ownership stays solely in the audited VisualCore host (the core issues no GL call).
- **Gaps built here:** G-SCENE, G-SKY and G-CLOCK of `docs/apps/aurora/visualcore-contract.json`, as a pending core in
  `Packages/ExperiencesCreative/Aurora/Core` until A21-P02 adds the experience.
- **No VisualCore or ProjectM change.** Follow `specs/145-zg-p01-document-strokes`.

## Clarifications

### Session 2026-11-17

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `SceneClock` (VisualCoreSimulation) advances by `min(max(delta, 0), 0.25) × speed`, wraps at `duration`, clamps
  speed to 0…4, and under `reducedMotion` multiplies the step by 0.5; it does not stop.
- `FullScreenShaderScene` binds `u_time` (or `fixedTime`), `u_resolution`, `u_seed`, up to 8 linear-light palette stops
  (`u_palette`, `u_paletteCount`) and one float `u_<name>` per parameter; a compile failure sets `errorMessage` naming
  the file and line. Its tests draw off screen with `RenderHost(scene:)` and `readPixels()`, and Living Wallpapers'
  core tests already depend on VisualCoreRendering to draw.
- The `vc/` hashes are integer PCG hashes of the float bit patterns (`vc_pcg`, `vc_hash21`, `vc_hash22`), and
  `vc_gradientNoise` and `vc_fbm` are polynomial, so a Swift port reproduces them in `Float`.
- A pending core is `<Name>Core` and `<Name>CoreTests` in `Packages/ExperiencesCreative/Package.swift` with no
  experience target (`scripts/check_experience_packages.py`, the pending-core allowance).

- Q: What does a sky scene hold, with which bounds, and what happens to a bad value? → A: Scene schema 1, kind
  `a21.sky-scene`, at most 4,096 bytes: `preset` (one of the catalog ids), `palette` (2…4 opaque sRGB colours),
  `ribbons` 1…4 (integer), `turbulence` 0…1, `cloudiness` 0…1, `stars` 0…400 (integer), `speed` 0…2. Decoding refuses
  a damaged, newer, oversized, non-finite or out-of-range file with a code (`damaged`, `newer-version`, `too-large`,
  `not-finite`, `out-of-range`, `unknown-preset`, `palette-size`). A value set through the scene's setters is clamped
  to its bound; a non-finite one is ignored. Three presets: `polar-night` (deep blue sky, green ribbons, many stars),
  `violet-veil` (violet and rose ribbons, light clouds) and `dawn-haze` (warm haze, fewer stars, more clouds), each
  with version 1 and the attribution "written for VisualCore".
- Q: How is the sky drawn, and how is it checked without the GPU? → A: One fragment shader, `aurora-sky.frag`, kept by
  the core as source text with `#include "vc/noise.glsl"`, composites three layers in order: hashed stars with a
  bounded twinkle, fbm clouds, and up to four ribbons as slowly advected fbm colour bands mixed with additive light.
  Level 0 uses 5 octaves and level 1 uses 3. `SkyReference` in the core evaluates the same formulas per pixel in
  `Float` with a Swift port of the `vc/` hash and noise. The core tests draw each preset off screen at 64 × 48 through
  `FullScreenShaderScene` and compare with the reference.
- Q: What tolerance and brightness range does the drawing meet? → A: Against the reference, the mean absolute channel
  difference is at most 2/255 and the largest at most 8/255 (8-bit read-back). Brightness: every pixel's Rec. 709
  luminance of the sRGB-decoded colour is at most 0.75, and the mean is at least 0.02, so the picture is never empty
  and never glaring; the luminance cap of A21-P02 comes on top.
- Q: How does time advance, and how is Reduce Motion still? → A: `SkyClock` wraps a `SceneClock` with a period of 600 s
  and the scene's speed. Each drawn frame advances it by the frame delta (at most 0.25 s per step). The shader takes
  the phase `time / 600` and moves the noise along a circle in noise space, so the wrap is seamless. Under Reduce
  Motion, or at speed 0, the clock holds its time, so consecutive frames are identical; `SceneClock`'s half-speed
  factor is not used for that.
- Q: Which targets and dependencies does the pending core have? → A: `AuroraCore` (path `Aurora/Core`, dependencies
  `VisualCoreMath`, `VisualCoreSimulation` and `VisualCoreExperience`) and `AuroraCoreTests` (path `Aurora/CoreTests`,
  dependencies `AuroraCore` and `VisualCoreRendering`, which draws the shader off screen). The core issues no GL call
  and reads no clock; the shader text is data.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A sky is a small, bounded scene (Priority: P1) 🎯

A sky (its preset, palette, ribbon count, turbulence, cloudiness, star count and animation speed) is a compact scene
with sensible bounds. Three presets start the experience. A damaged, newer or out-of-range scene is refused or clamped,
with a reason, and the sky stays as it was.

**Why this priority**: every later phase draws, controls and stores the sky from this scene.

**Independent Test**: round-trip each preset; open one sample of each refusal; set each value beyond its bound.

**Acceptance Scenarios**:

1. **Given** each of the three presets, **When** it is encoded and decoded, **Then** it is identical.
2. **Given** a damaged, newer, non-finite or out-of-range scene, **When** it is opened, **Then** it is refused with its
   reason, or the value is clamped to its declared bound, and nothing else changes.

---

### User Story 2 - The sky draws as layered light that stays within bounds (Priority: P1)

The sky is drawn as layers: a starfield, cloud layers and aurora ribbons from slowly moving noise, composited into one
picture. Each preset's drawing matches its reference computed without the GPU within a tolerance, and its brightness
stays within the declared range. A lower quality level draws less detail.

**Why this priority**: the manual's noise and ribbon prototype, and risk 1 (cheap 2D layers, not volumetrics).

**Independent Test**: draw each preset off screen; compare with the reference; measure brightness; compare levels.

**Acceptance Scenarios**:

1. **Given** each preset at a fixed time, **When** it is drawn off screen, **Then** the picture matches the reference
   within tolerance, is not empty, and its brightness lies within the declared range.
2. **Given** the two quality levels, **Then** the lower level uses fewer noise octaves and still matches its own
   reference.

---

### User Story 3 - Time never jumps, and reduced motion is still (Priority: P1)

The sky's time advances only by drawn frames, each step bounded, so returning after a long time in the background
never jumps. With Reduce Motion on, consecutive frames are identical.

**Why this priority**: the manual's regression fixture and its algorithm rule on wall-clock versus animation time.

**Independent Test**: advance the clock across a long gap; draw twice under reduced motion.

**Acceptance Scenarios**:

1. **Given** a gap of an hour between frames, **When** the clock advances, **Then** the sky's time moves by at most one
   bounded step.
2. **Given** Reduce Motion on, **When** the sky is drawn at two frame times, **Then** the two pictures are identical.

### Edge Cases

- **A scene value that is NaN or infinite:** refused, never drawn.
- **A star or ribbon count above its cap:** clamped to the cap.
- **A shader that fails to compile:** the failure is reported with the shader's name; nothing is drawn from it.
- **A very bright palette:** the reference and the drawing stay within the declared brightness range.
- **Speed zero:** the sky is still, like Reduce Motion.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A21-101**: A sky scene MUST hold a preset id, a palette, a ribbon count, turbulence, cloudiness, a star count
  and an animation speed, each with documented bounds, and MUST round-trip exactly.
- **FR-A21-102**: Three presets MUST exist, each with a palette, attribution and version, and MUST be valid scenes.
- **FR-A21-103**: A damaged, newer-version or non-finite scene MUST be refused with a reason; an out-of-range value
  MUST be clamped to its bound or refused, as documented.
- **FR-A21-104**: The sky MUST be drawn as layered passes (stars, clouds, ribbons) from shader sources the core
  provides as data; each preset's off-screen picture MUST match its reference computed without the GPU within a
  documented tolerance, and its brightness MUST stay within the declared range; after a context loss and after a resize the drawing MUST
  match its reference again.
- **FR-A21-105**: Two quality levels MUST exist; the lower level MUST draw fewer noise octaves.
- **FR-A21-106**: The sky's time MUST advance only by drawn-frame deltas with each step bounded; with Reduce Motion
  on or speed zero, consecutive frames MUST be identical.
- **FR-A21-107**: The core MUST be pure: no GL call, clock read, network or UI framework.

### Key Entities

- **Sky scene**: preset, palette, ribbon count, turbulence, cloudiness, stars, animation speed; version.
- **Preset catalog**: id, version, attribution, scene.
- **Sky clock**: rendered time, speed, reduced-motion flag.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A21-101**: 100% of presets round-trip exactly; 100% of refusal samples are refused with their reason.
- **SC-A21-102**: Each preset's drawing matches its reference within the documented tolerance at both quality levels.
- **SC-A21-103**: After a one-hour gap the sky's time moves by at most one bounded step; under Reduce Motion two frames
  are identical in 100% of samples.
- **SC-A21-104**: Each test finishes in under 10 seconds.

## Assumptions

- The experience's presenter, controls and registration come in A21-P02; this phase adds only the pending core.
- Brightness bounds and tolerances are those of clarifications Q2–Q3.

## Traceability

| Source | Requirement |
|---|---|
| MVP: three sky presets with ribbons, stars and clouds | FR-A21-101, 102, 104 |
| Regression fixture: reduced-motion stable frame | FR-A21-106, SC-A21-103 |
| Algorithm rules 1–3 (layered noise, comfort bounds, wall-clock versus animation time) | FR-A21-104, 106 |
| Brainstorm: procedural shaders, noise functions, animation | FR-A21-104–106 |
| Contract G-SCENE, G-SKY, G-CLOCK | FR-A21-101–107 |

## Negative Requirements

- No GL call in the core; no image or recording; no claim of a real aurora; no registration or interface in this
  phase; no VisualCore change.
