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
  documented tolerance, and its brightness MUST stay within the declared range.
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
- Brightness bounds and tolerances are numbers decided in clarification and recorded in the data model.

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
