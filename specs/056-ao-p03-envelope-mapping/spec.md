# Feature Specification: Audio Odyssey — Phase 03 Audio envelope mapping

**Feature Branch**: `056-ao-p03-envelope-mapping` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A07-P03 (legacy ledger) · ID namespace FR-A07-3##, SC-A07-3##, T-A07-3##

**Input**: User description: archived manual `apps/07-audio-odyssey.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — manual flight speed, camera easing and a reduced-motion setting;
  regression fixture — source switching does not reset the graphics context; context ownership stays solely in the
  VisualCore host.
- **No VisualCore change expected:** the envelope is built from the analysis A06 built and smoothed with the existing
  mapper; the slice is experience domain, state and interface. If an addition to VisualCore proves necessary, it follows
  Principle II (docs, baseline, tests, regression at X-A07).
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`AudioFeatures` has `bandEnergies` (16 bands from `FeatureExtractor`), `flux` and `onset`; `AudioMapper` smooths one
`AudioMapping` (feature, gain, attack, release) into a range; `JourneyState` (schema 2) holds `speedChoice`
(slow/medium/fast = 2/4/7 units/s) and the presenter's `TunnelResponse` drives tunnel breathing and ambient.

- Q: How is the envelope built from the analysis? → A: `AudioEnvelope` (Core, pure): low = mean of bands 0–3, mid =
  mean of bands 4–9, high = mean of bands 10–15, each normalised by a running peak with slow decay (0.5 s) into 0…1;
  transient = flux normalised the same way, raised to at least 0.8 on an onset frame; all smoothed per channel with
  attack 0.03 s / release 0.3 s; timestamp = the analysis time. Built in Core from plain arrays (no audio import), so
  it is host-testable.
- Q: How does continuous speed relate to the three speed choices? → A: `speedChoice` is replaced by a continuous
  `speed target` 0.5…7 units/s (slider in 0.5 steps); schema 3; schema 1/2 states map slow/medium/fast to 2/4/7. The
  action `speed.select [0…2]` stays (presets the slider) and `speed.set [0.5…7]` is added.
- Q: What does easing change? → A: `easing` gentle/standard/brisk multiplies the active acceleration limit by
  0.33/0.66/1.0 (never above the comfort maximum); gentle therefore settles in ≥ 3× the brisk time (≥ 2× required).
- Q: What are the per-world responses and their bounds? → A: Generalise `TunnelResponse` to `WorldResponse` with two
  outputs per world — primary (tunnel: breathing amount; landscape: height swell 0…0.6 of the base relief, applied as a
  vertical scale of the strip; star corridor: sparkle 0…1 applied as star scale 1…1.6) and light (ambient as in
  A07-P02) — same rest/bound/step-limit pattern, Reduce Motion halves the primary range, Reduce Flashing halves the
  light range and step. Mapping per world: primary ← channel (default tunnel low, landscape mid, star transient),
  light ← channel (default level-like = mean of low/mid/high), sensitivity low/medium/high = gain 0.6/1.0/1.6.
- Q: Where does calm motion live and is it persisted? → A: `calmMotion` (Bool) in the journey state (schema 3,
  persisted, in the digest); effective calm = calmMotion || system Reduce Motion (mirrored, not persisted); action
  `comfort.calm [0…1]`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fly at my own pace, gently (Priority: P1) 🎯

A person sets the flight speed anywhere from very slow to fast with a slider, chooses how gently the camera eases into
a new speed, and can turn on a calm-motion setting in the experience itself (even if the system's Reduce Motion is
off), which slows the flight and removes sway.

**Why this priority**: the phase MVP and journey 3 ("adjust speed/sensitivity, pause scene and switch to low-motion
mode").

**Independent Test**: set speeds across the range, change the easing, toggle calm motion; the flight reaches the chosen
speed only through the easing, never above the comfort limits; calm motion caps speed and removes sway.

**Acceptance Scenarios**:

1. **Given** any chosen speed between the minimum and maximum, **When** flying, **Then** the speed settles at that value
   (capped by the active limits) and never changes faster than the active acceleration allows.
2. **Given** a slower easing, **When** the speed changes, **Then** it takes proportionally longer to settle and never
   overshoots.
3. **Given** calm motion on (in-app or from the system), **When** flying, **Then** the speed is at most the calm cap and
   the camera neither sways nor tilts.

---

### User Story 2 - Choose what the music moves (Priority: P1)

A person decides, per world, which part of the sound drives what: for example the tunnel's width from the bass and its
light from the overall level, the landscape's height from the mids, the star corridor's sparkle from the beats. Changes
apply at once and smoothly.

**Why this priority**: the phase's deliverable ("audio envelope mapping") and v0.1 feature 02.

**Independent Test**: set mappings in each world and feed known envelopes; each response follows its chosen channel
within bounds and step limits; the other worlds keep their own mapping.

**Acceptance Scenarios**:

1. **Given** a world and a mapping (response ← channel, sensitivity), **When** that channel rises, **Then** only the
   responses mapped to it rise, smoothly and within bounds.
2. **Given** a mapping changed in the tunnel, **When** the person switches to the landscape, **Then** the landscape keeps
   its own mapping, and switching back restores the tunnel's.
3. **Given** "reset mappings", **When** chosen, **Then** every world returns to its default mapping.

---

### User Story 3 - The sound source can change without a hiccup (Priority: P2)

Switching between the demo, a file and the microphone never restarts the drawing or the flight (the phase fixture).

**Independent Test**: switch sources repeatedly while flying; the host context, distance and speed continue unchanged.

**Acceptance Scenarios**:

1. **Given** a flight, **When** the source changes five times, **Then** the same drawing context is in use before and
   after and the journey continues.

### Edge Cases

- Silence: every response rests; nothing flashes.
- The slider at its ends; speeds below the minimum or above the maximum are clamped.
- A mapping to the transient channel: responses rise briefly on beats and decay; no single-frame jump exceeds the step
  limit.
- Calm motion and Reduce Flashing together: both caps apply.
- A restored older session: mapping and speed take their defaults; world, distance and source are kept.

## Requirements *(mandatory)*

### Functional Requirements

**Comfort controls (story 1)**
- **FR-A07-301**: The flight speed MUST be continuous between a minimum and a maximum, clamped by the active comfort
  limits.
- **FR-A07-302**: The camera easing MUST be adjustable in steps (gentle, standard, brisk), scaling the acceleration
  limit downward only (never above the comfort maximum).
- **FR-A07-303**: An in-app calm-motion setting MUST apply the reduced-motion limits (lower speed, no sway, no roll) in
  addition to the system Reduce Motion; either one turns calm motion on.

**Envelope and mapping (story 2)**
- **FR-A07-310**: The experience MUST build an audio envelope (low, mid, high, transient, each 0…1, with its timestamp)
  from the analysed sound each frame.
- **FR-A07-311**: Each world MUST have two responses (tunnel: width, light; landscape: height, light; star corridor:
  sparkle, light), each mapped to one envelope channel with a sensitivity; responses stay within bounds and change at
  most a step per frame.
- **FR-A07-312**: Mappings MUST be editable in the controls, kept per world, resettable, and part of the saved state.

**Context continuity (story 3)**
- **FR-A07-320**: Source switching MUST keep the host context and the journey (distance, speed) unchanged.

**Experience**
- **FR-A07-330**: The saved state gains speed, easing, calm motion and the per-world mappings (schema 3); older states
  migrate with defaults. The canvas description names the speed and calm motion.
- **FR-A07-331**: The manifest keeps nine standard and five fixture scenarios; fixture 2 covers continuous speed and
  easing, fixture 3 source switching.

**Common**
- **FR-A07-340**: No networking; audio never moves the camera; no claims about sound measurement, relaxation or health.

### Key Entities

- **Audio envelope**: low, mid, high, transient (0…1), timestamp.
- **World mapping**: per world, two responses each with a channel and a sensitivity.
- **Comfort settings**: speed (continuous), easing (gentle, standard, brisk), calm motion (on/off).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A07-301**: For 200 seeded sequences of speed and easing changes, speed and acceleration never exceed the active
  limits and the speed settles at the chosen value (within 1%) when it is within the limits.
- **SC-A07-302**: Gentle easing takes at least twice as long as brisk to settle from slow to fast.
- **SC-A07-303**: With calm motion on, speed never exceeds the calm cap and sway is exactly zero.
- **SC-A07-304**: For each world, a pulse on one envelope channel raises only the responses mapped to it; responses stay
  within bounds and step limits; mappings are kept per world and reset restores the defaults.
- **SC-A07-305**: Five source switches keep the host context and the journey (fixture 3).
- **SC-A07-306**: Schema 1 and 2 states migrate; the scenarios pass on iOS 27; every new test finishes in under
  10 seconds.

## Assumptions

- The low/mid/high channels come from the band energies already analysed (grouped into three ranges) and the transient
  from the onset strength; no new analysis is needed.
- Sensitivities are three levels (low, medium, high) to keep the control simple.

## Out of Scope

- Saving named presets (A07-P04); long-session performance and accessibility verification (A07-P05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 03 (manual speed, camera easing, reduced motion) | FR-A07-301–303; SC-A07-301–303 |
| v0.1 feature 02 (audio mapped to geometry/lighting) | FR-A07-310–312; SC-A07-304 |
| Manual §6 domain type AudioReactiveEnvelope(low, mid, high, transient, timestamp) | FR-A07-310 |
| Manual §9 Phase 03 fixture (source switching keeps the context) | FR-A07-320; SC-A07-305 |
| Journey 3 (adjust speed/sensitivity, pause, low-motion) | User stories 1, 2 |

## Negative Requirements

- No audio-driven camera motion or hard cuts; no networking; no claims about sound measurement or health.
- No second renderer or context.
