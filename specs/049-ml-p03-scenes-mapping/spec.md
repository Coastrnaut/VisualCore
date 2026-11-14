# Feature Specification: VisualCore Music Lab — Phase 03 Three visual scenes and mapping editor

**Feature Branch**: `049-ml-p03-scenes-mapping` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A06-P03 (legacy ledger) · ID namespace FR-A06-3##, SC-A06-3##, T-A06-3##

**Input**: User description: archived manual `apps/06-visualcore-music-lab.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — three visually different scenes: bars, waveform rings and 3D-ish responsive
  geometry; regression fixture — the audio callback never performs dynamic allocations on the hot path; the graphics
  context stays solely with the audited VisualCore host.
- **Gap built here in VisualCore** (docs, public-API baseline, tests; reference regression at X-A06), from
  `docs/apps/visualcore-music-lab/visualcore-contract.json`: G-AUDIOMAP (audio-to-parameter mapping: feature, gain,
  attack, release, clamp into a parameter range; versioned and validated). G-SIGNALTEXTURE (spectrum as a shader
  texture) is not needed by this slice — every scene is drawn with the host's primitive and mesh renderers — and moves
  to Phase 05 (visual polish), recorded in the contract.
- **Experience:** `Packages/ExperiencesCreative/VisualCoreMusicLab` gains the scene choice and the mapping editor; its
  state grows (snapshot schema 2 with migration of schema 1).
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: the
demo and file sources write their blocks from a main-run-loop timer (`DemoAudioSource.renderBlock`,
`FileAudioSource.writeChunk`/`mixDown`), only the microphone runs on the real-time audio thread (the tap block of
`MicrophoneAudioSource`, which already uses preallocated scratch); error branches build strings
(`AudioSourceError.undecodable(name)`); `ProcessMemory.footprint()` reads the process footprint; experiences receive
`reduceMotion` in their `make` factory from the registry; `ExperienceControl.maxValues` is 24; meshes are Lambert-lit with
back-face culling (`MeshRenderer`) and several can be drawn with depth through `DepthMeshPass`.

- Q: How is each feature normalised to 0…1? → A: Level and peak by dBFS over −60…0; each frequency region by the dB of
  the summed energy of its four bands over −80…0; beat energy as is (already 0…1). Values below the window read 0,
  above read 1.
- Q: How does a mapping turn the normalised feature into a parameter value, and what is the rest value? → A: x =
  clamp(gain · n, clampLow, clampHigh); s = smoother(attack, release) over x with the elapsed time; value = minimum + s ·
  (maximum − minimum). The rest value is the value for silence (s = 0), i.e. the range minimum.
- Q: What does the mapping editor change, and through which actions? → A: Per parameter only the feature and the gain
  (attack/release and clamp stay at the scene's defaults in this phase). Actions: `scene.select [0…2]`, `mapping.set
  [scene 0…2, slot 0…2, feature 0…6, gain 0…4]`, `mapping.reset [scene 0…2]`; features are indexed level, peak, beat,
  low, low-mid, high-mid, high.
- Q: How is the hot path marked and checked? → A: Each audio-side block handler is enclosed in `// vc:hot-path begin` /
  `// vc:hot-path end`; a repository script refuses allocating constructs inside (array/dictionary/string creation or
  literals, `append`, `map`/`filter`/`reduce`, string interpolation, class instantiation, closures, `print`); a line that
  only runs on failure carries `// vc:cold` and is exempt. The microphone tap is the real-time handler; the demo and
  file handlers are marked too because they feed the same buffer.
- Q: How is "no growth" measured in-process? → A: The process footprint before and after 1,000 blocks through the
  demo source's block handler and the microphone tap block (fed one preallocated buffer), after one warm-up block;
  growth ≤ 64 KiB.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose one of three scenes (Priority: P1) 🎯

A person switches between three scenes that look clearly different and all react to the sound: **Bars** (the spectrum as
bars with the level and beat meters), **Rings** (the waveform wrapped into concentric rings that swell with the level)
and **Geometry** (a lit, rotating sphere in a ring of blocks whose heights follow the spectrum and which pulses on the
beat).

**Why this priority**: the phase MVP and journey 2 of the brainstorm ("switch waveform, spectrum and reactive geometric
scene").

**Independent Test**: with the demo signal, open each scene; each draws a picture that differs from the other two and
changes when the sound changes.

**Acceptance Scenarios**:

1. **Given** the demo 1 kHz tone, **When** each scene is selected in turn, **Then** each draws a non-blank picture and
   every pair of scenes differs in at least 10% of the probe pixels.
2. **Given** a scene, **When** the source goes from silence to the tone, **Then** the picture changes (the mapped values
   rise above their rest values).
3. **Given** a chosen scene, **When** the session is saved and restored, **Then** the same scene is shown.

---

### User Story 2 - Decide what drives what (Priority: P1)

Each scene has a few visual parameters (for example the bars' height, the rings' radius, the geometry's pulse and spin).
In the mapping editor the person picks, for each parameter, which sound feature drives it (level, peak, beat or one of
four frequency regions), how strongly (gain), and the editor shows the live value. A reset button restores the scene's
default mapping.

**Why this priority**: the second half of the phase ("mapping editor") and journey 3 in part (calibrate gain).

**Independent Test**: change one parameter's feature and gain; the parameter's value follows the new feature, scaled by
the gain and kept inside the parameter's range; the change survives save and restore.

**Acceptance Scenarios**:

1. **Given** the Geometry scene, **When** the pulse parameter is set to "level" with gain 2, **Then** its value follows the
   level, doubled, and never leaves the parameter's range.
2. **Given** an edited mapping, **When** "Reset mapping" is chosen, **Then** the scene's defaults return.
3. **Given** a mapping with an unknown feature or a non-finite gain in a restored payload, **When** it is opened, **Then**
   it is refused and nothing changes.

---

### User Story 3 - Sound handling stays real-time safe (Priority: P2)

The code that runs on the audio side for every block of sound never asks for new memory, so sound handling cannot stall
or glitch because of memory management.

**Why this priority**: the phase regression fixture.

**Independent Test**: every audio-side block handler of the three sources is marked and an automated check refuses any
memory-allocating construct inside the marked code; the handlers are exercised with many blocks without growth in use.

**Acceptance Scenarios**:

1. **Given** the marked audio-side handlers of the demo, file and microphone sources, **When** the hot-path check runs,
   **Then** it finds no allocating construct and fails when one is introduced in a test copy.
2. **Given** the demo and microphone handlers, **When** each processes 1,000 blocks, **Then** the process memory in use
   does not grow.

### Edge Cases

- A mapping whose gain drives a value past the range: the value is clamped to the parameter's range.
- A frequency-region feature on a source with a lower sample rate: regions are fixed by frequency and computed from the
  bands the source's rate provides; missing regions read 0.
- Switching scene while sound plays: the new scene draws from the next frame; mapping smoothing restarts from rest so
  no jump from the previous scene's values.
- Schema-1 payloads (Phase 01/02): restored with the Bars scene and default mappings.
- Silence: every mapped value rests at its parameter's rest value; the picture is stable.
- Reduce Motion on: the geometry's spin is not driven by sound (rest speed only); pulses remain.

## Requirements *(mandatory)*

### Functional Requirements

**Mapping in VisualCore (story 2)**
- **FR-A06-301**: VisualCore MUST provide an audio mapping that names a feature (level, peak, beat, or one of four
  frequency regions: low, low-mid, high-mid, high), a gain, an attack and release in seconds, and a clamp range within
  0…1, and maps a feature set to a value inside a given parameter range.
- **FR-A06-302**: The mapping MUST normalise each feature to 0…1 (levels and regions by a fixed dB window, beat as is),
  apply gain then clamp, smooth with its attack/release using the elapsed time, and map into the parameter range.
- **FR-A06-303**: Mappings MUST be versioned and validated on decoding: unknown features, non-finite or out-of-range
  numbers, or an unsupported version are refused.

**Experience (stories 1, 2)**
- **FR-A06-310**: VisualCore Music Lab MUST offer three scenes — Bars, Rings, Geometry — selectable at any time; the
  choice is part of the state (digest, snapshot).
- **FR-A06-311**: Each scene MUST declare two or three parameters with ranges and rest values, each driven by one
  mapping; all scene drawing goes through the host's renderers (no context of its own).
- **FR-A06-312**: The mapping editor MUST let the person choose the feature and gain (0…4) per parameter, show the live
  value, and reset the scene's mappings; every control has an accessible label and identifier.
- **FR-A06-313**: The state (scene, mappings per scene) MUST persist in snapshot schema 2; schema-1 payloads are migrated
  with the Bars scene and default mappings.
- **FR-A06-314**: With Reduce Motion on, sound-driven rotation is disabled (rest speed); other mappings stay active.
- **FR-A06-315**: The canvas description MUST name the scene in addition to the source, level and beat.

**Hot path (story 3)**
- **FR-A06-320**: Every audio-side block handler (demo, file, microphone) MUST be marked as hot path and contain no
  memory-allocating construct; an automated repository check MUST enforce this.

**Common**
- **FR-A06-330**: No networking, accounts or analytics; no recording; no ProjectM/MilkDrop code or preset format; no
  claims about hearing, health or musical accuracy.

### Key Entities

- **Audio mapping**: feature, gain, attack, release, clamp low/high, schema version.
- **Mapper**: one mapping plus its smoothing state; produces a value in a parameter range.
- **Scene**: identity (bars, rings, geometry), parameters (name, range; rest value = range minimum), default mappings.
- **Music Lab state (schema 2)**: source, demo seed, demo mode, scene, mappings per scene.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A06-301**: For each feature, a mapping with gain 1 maps the feature's minimum and maximum to the range ends and
  midpoints linearly (within 1e-6); gain 2 doubles before the clamp; the value never leaves the range in 1,000 random
  feature sets.
- **SC-A06-302**: Decoding refuses 100% of payloads with an unknown feature, a non-finite number, a gain outside 0…4 or
  an unsupported version; valid payloads round-trip exactly.
- **SC-A06-303**: In the experience, the three scenes' probe pictures differ pairwise in ≥ 10% of probe pixels for the
  1 kHz demo tone; each scene's picture differs between silence and the tone.
- **SC-A06-304**: Schema-1 payloads restore with the Bars scene and default mappings; schema-2 payloads round-trip; the
  nine scenarios and the fixture scenarios pass on iOS 27 with the regenerated manifest.
- **SC-A06-305**: The hot-path check passes on the repository and fails on each of at least five planted allocating
  constructs; 1,000 blocks through the demo and microphone handlers leave memory in use unchanged (± 64 KiB).
- **SC-A06-306**: The public-API baseline lists the new types, documented; every new test finishes in under 10 seconds.

## Assumptions

- The four frequency regions are fixed groupings of the 16 analysis bands of A06-P02 (bands 0–3, 4–7, 8–11, 12–15).
- Scene parameters are app-local; the mapping primitive is generic and lives in VisualCore.
- Gain calibration presets, colour palettes and named scene presets are Phase 05; interruption recovery Phase 04.
- Allocation profiling with system tools on hardware is part of the device campaign; this phase proves the property by
  a repository check and a bounded in-process run.

## Out of Scope

- Shader-texture spectrum rendering (G-SIGNALTEXTURE, Phase 05), post-processing, user-made scenes, preset library.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 03 (three scenes: bars, waveform rings, 3D-ish responsive geometry) | FR-A06-310, 311, SC-A06-303 |
| Manual §9 Phase 03 fixture (no allocation on the audio hot path) | FR-A06-320, SC-A06-305 |
| Manual §9 Phase 03 gate (context only in the VisualCore host) | FR-A06-311 |
| Manual §6 `ReactiveMapping(feature, gain, attack, release, clamp, targetUniform)` | FR-A06-301–303 |
| Journey 2 (switch waveform, spectrum and reactive geometric scene) | User story 1 |
| Journey 3 (calibrate gain) | User story 2 |
| Contract gap G-AUDIOMAP (M01, M17) | FR-A06-301–303 |

## Negative Requirements

- No allocation in audio-side block handlers; no second renderer or context.
- No recording, upload or retention of audio; no hearing, health or accuracy claims.
- No ProjectM/MilkDrop code, preset format or look-alike scenes.
