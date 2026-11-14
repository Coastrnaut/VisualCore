# Feature Specification: VisualCore Music Lab — Phase 05 Audio/render performance and accessibility

**Feature Branch**: `051-ml-p05-performance-accessibility` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A06-P05 (legacy ledger) · ID namespace FR-A06-5##, SC-A06-5##, T-A06-5##

**Input**: User description: archived manual `apps/06-visualcore-music-lab.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — parameter presets, local persistence and accessibility text metrics;
  regression fixture — interruption and route-change transitions do not leave the audio engine or the graphics state
  stuck; the graphics context stays solely with the audited VisualCore host.
- **Gaps** (`docs/apps/visualcore-music-lab/visualcore-contract.json`): G-AUDIOBUDGET (VisualCore: analysis
  configuration per quality level with a measured per-window bound), G-A11YMETRICS (app-local: text metrics and
  rate-limited announcements). G-SIGNALTEXTURE (signal data in a shader texture) is closed as adapted: the scenes carry
  per-frame audio values into geometry through the host's primitive and mesh renderers and the mapping primitive
  (A06-P03), so no texture path is needed; row M18 becomes available with that evidence.
- **Presets** (from A06-P04): colour palettes join the preset (format 2; format-1 files read with the first palette) and
  the state (schema 3 with migration).
- **Owner rulings:** short tests (measure a short run, bound the rest by arithmetic; wall-clock bounds asserted locally
  only); audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: the
host calls `draw(_:tier:context:frame:)` with the quality tier each frame; the a06 registration in
`Catalog/registrations.json` declares `quality_tiers` (validated by `scripts/build_catalog.py`, up to 8 names); the host's
`ExperienceFeedback` already pairs an `AnnouncementSink` (`SystemAnnouncementSink` posts `UIAccessibility` announcements)
with a `voiceOverRunning` closure; `preset.apply` carries 7 values today and `ExperienceControl` allows 24.

- Q: How does the host's tier reach the analysis? → A: Tier 0, 1, 2 (clamped) selects the analysis level of FR-A06-501;
  the registration's `quality_tiers` become ["level-0", "level-1", "level-2"]; a tier change rebuilds the extractor for the
  new size and band count on the next frame.
- Q: What exactly does the metric text say? → A: "Level −9 dB" (RMS dBFS rounded to the nearest integer, minus sign
  "−") or "Level silent" when RMS ≤ −90 dBFS; "strongest low | low-mid | high-mid | high" (the region with the largest
  summed energy) or "strongest none" when silent; "beat" while the beat meter is above 0.5, else "no beat"; joined with
  ", ". Non-finite values read as silent.
- Q: How are announcements made testable and rate-limited? → A: The presenter takes an injectable announcement sink and
  a VoiceOver-running check (defaults: the system's); on a frame where the text differs from the last announced text and
  ≥ 2 s (frame time) have passed since the last announcement, it announces once.
- Q: How do palettes enter state, presets and actions? → A: Palettes 0 Aurora (today's colours), 1 Ember (warm), 2 Mono
  (greys), each with colours for bars, waves, level, beat and geometry; state schema 3 adds `palette` (migration from 2
  → 0); `palette.select [0…2]`; preset format 2 adds `"palette"` (format 1 → 0); `preset.apply` grows to 8 values with the
  palette last.
- Q: How is the per-window cost measured without wall-clock asserts on CI? → A: A host test times 500 calls of
  `analyze(_:time:elapsed:into:)` at level 0 after a warm-up and records the mean; it asserts < 0.5 ms only when the
  environment variable `CI` is not set, and always prints the value.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Hear the numbers (Priority: P1) 🎯

A person using VoiceOver, or who prefers not to rely on motion or colour, reads the sound as text: the level in dBFS
(rounded), the strongest frequency region, and whether a beat is present. Changes are announced at most once every two
seconds and only when the text changes.

**Why this priority**: the phase MVP ("accessibility text metrics") and the v0.1 feature list.

**Independent Test**: for known features the metric text matches exactly; announcements are rate-limited; the text is
exposed as an accessibility value in the controls with no animation.

**Acceptance Scenarios**:

1. **Given** the demo 1 kHz tone, **When** the metrics are read, **Then** they say "Level −9 dB, strongest high-mid, no
   beat" (1 kHz lies in band 8 of the 16-band layout, i.e. the high-mid region; values from the actual analysis).
2. **Given** a beat every half second, **When** metrics change quickly, **Then** at most one announcement is made per two
   seconds and none when the text is unchanged.
3. **Given** silence, **When** read, **Then** "Level silent, strongest none, no beat".

---

### User Story 2 - Presets remember colours too (Priority: P1)

The person chooses one of three colour palettes for the visuals; the palette is saved in the session and in presets, and
applying a preset restores scene, mappings and palette.

**Why this priority**: the phase MVP ("parameter presets, local persistence") completing A06-P04's presets.

**Independent Test**: select a palette, save a preset, change everything, apply the preset; palette, scene and mappings
return; a format-1 preset applies with the first palette.

**Acceptance Scenarios**:

1. **Given** palette "Ember", **When** a preset is saved and later applied, **Then** the palette is "Ember" again.
2. **Given** a preset file of format 1, **When** applied, **Then** it uses the first palette and nothing fails.
3. **Given** a session of schema 2, **When** restored, **Then** the first palette is selected.

---

### User Story 3 - Smooth on every device class (Priority: P2)

The analysis adapts to the device's quality level: lower levels analyse fewer samples and bands, so the frame budget
holds; the cost per analysis window stays within a stated bound.

**Why this priority**: the phase title ("audio/render performance") and gap G-AUDIOBUDGET.

**Independent Test**: each quality level maps to a valid analysis configuration; a short measured run stays within the
per-window bound locally (extrapolated on CI).

**Acceptance Scenarios**:

1. **Given** quality levels 0, 1, 2, **When** configured, **Then** windows are 1,024 / 512 / 256 samples with 16 / 16 / 8
   bands, all valid.
2. **Given** a measured run of 500 windows at level 0, **When** timed locally, **Then** the mean cost per window is below
   0.5 ms (asserted only on a local run; on CI the measurement is reported, not asserted).

---

### User Story 4 - Interruptions never wedge the experience (Priority: P1)

Interruptions, route changes and background/foreground transitions, in any order, leave the sound handling and the
drawing working: frames keep rendering, the source ends live or clearly paused, and closing the experience releases
everything.

**Why this priority**: the phase regression fixture.

**Independent Test**: a scripted sequence of source events and app transitions while rendering; every frame renders,
the final state is consistent, closing leaves no live host and no running capture.

**Acceptance Scenarios**:

1. **Given** the microphone (double) running, **When** began, route lost, ended (resume), background, foreground,
   media reset happen in sequence with frames between, **Then** every frame renders and the source ends live.
2. **Given** that sequence, **When** the experience closes, **Then** no render host and no capture remain.

### Edge Cases

- Quality level changes while running: the next frame uses the new configuration; the analysis restarts (no mixed
  windows).
- Metrics with a non-finite feature: treated as silence in the text.
- Announcements while VoiceOver is off: nothing is posted.
- Palette index out of range in a payload or preset file: refused like other invalid values.

## Requirements *(mandatory)*

### Functional Requirements

**VisualCore (story 3)**
- **FR-A06-501**: VisualCore MUST map an analysis quality level to a configuration (window size, band count) — level 0:
  1,024/16, level 1: 512/16, level 2: 256/8 — and clamp levels outside 0…2 to the nearest level.

**Experience (stories 1, 2, 4)**
- **FR-A06-510**: Music Lab MUST produce metric text "Level <n> dB | silent, strongest <region> | none, <beat | no beat>"
  from the latest features and expose it as an accessibility value in a controls section titled "Sound metrics (approximate)" and in the
  canvas description.
- **FR-A06-511**: Announcements of the metric text MUST be rate-limited to at most one per 2 s and only when the text
  changed, and only while VoiceOver is running.
- **FR-A06-512**: Three palettes (Aurora, Ember, Mono) MUST colour every scene; the palette is part of the state (schema 3,
  migrated from 2 with palette 0) and of presets (format 2; format 1 read with palette 0); `palette.select [0…2]` and
  `preset.apply` with a palette value.
- **FR-A06-513**: The analysis MUST follow the host's quality level per frame (tier → level) and restart cleanly when it
  changes.
- **FR-A06-514**: Any sequence of interruption, route change, media reset and background/foreground transitions MUST
  leave rendering working and the source live, paused or stopped with a message; closing releases host and capture.

**Common**
- **FR-A06-520**: No networking; no recording; no ProjectM/MilkDrop names or formats; no claims about hearing or health;
  metrics are labelled as approximate visual aids, not measurements.

### Key Entities

- **Analysis configuration**: level, window size, band count.
- **Metric text**: level dB (rounded) or silent, strongest region or none, beat flag; last announced text and time.
- **Palette**: index 0…2, name, colours for bars, waves, meters, geometry.
- **Music Lab state (schema 3)**: + palette.
- **Music preset (format 2)**: + palette.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A06-501**: Each quality level maps to its configuration; out-of-range levels clamp; each configuration builds a
  valid extractor (100%).
- **SC-A06-502**: The mean analysis cost per window at level 0 over 500 windows is below 0.5 ms on the local machine;
  CI reports the value without asserting it.
- **SC-A06-503**: Metric text matches the expected string for silence, a 1 kHz tone and a beat (exact); announcements
  ≤ 1 per 2 s and none for unchanged text (100% of a scripted 10 s timeline).
- **SC-A06-504**: Palette survives session and preset round trips; schema-2 payloads and format-1 presets restore with
  palette 0; invalid palette values are refused.
- **SC-A06-505**: In the scripted transition sequence every frame renders, the final source state is live, and after
  closing no host and no capture remain.
- **SC-A06-506**: The nine scenarios and the fixture scenarios pass on iOS 27 with the regenerated manifest; the public-API
  baseline lists the new types, documented; every new test finishes in under 10 seconds.

## Assumptions

- The host's quality tier (0 best) maps directly to the analysis level; Music Lab's registration declares tiers 0…2.
- VoiceOver announcements are observable in tests through an injectable announcement sink (the host's existing
  accessibility players pattern).
- Real-device frame timing and allocation profiling are part of the device campaign.

## Out of Scope

- User-made palettes, shader-texture rendering (G-SIGNALTEXTURE adapted), haptics.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 05 (parameter presets, local persistence, accessibility text metrics) | FR-A06-510–512 |
| Manual §9 Phase 05 fixture (transitions never leave engine or graphics stuck) | FR-A06-514, SC-A06-505 |
| Manual §6 `MusicPreset(sceneID, paletteID, mappings, schemaVersion)` | FR-A06-512 |
| Contract gaps G-AUDIOBUDGET (M27), G-A11YMETRICS (M23), G-SIGNALTEXTURE (M18, adapted) | FR-A06-501, 510, 511 |
| Journey 3 (adjust colours and save a scene preset) | User story 2 |

## Negative Requirements

- No announcement storms (rate limit); no colour-only or motion-only information.
- No recording; no network; no hearing or health claims.
