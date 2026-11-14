# Feature Specification: VisualCore Music Lab — Phase 02 FFT/feature analysis with fixtures

**Feature Branch**: `048-ml-p02-feature-analysis` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A06-P02 (legacy ledger) · ID namespace FR-A06-2##, SC-A06-2##, T-A06-2##

**Input**: User description: archived manual `apps/06-visualcore-music-lab.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — RMS, peak, FFT spectrum and smoothed beat-energy signals; regression
  fixture — silence yields zero/near-zero features and a stable display.
- **Gap built here in VisualCore** (docs, public-API baseline, tests; reference regression at X-A06 per the owner ruling
  of 2026-11-14), from `docs/apps/visualcore-music-lab/visualcore-contract.json`: G-AUDIODSP (level, spectrum bands,
  spectral flux, onsets and a smoother with attack and release). Mapping features to visual parameters (G-AUDIOMAP) is
  Phase 03; analysis budgets per quality level (G-AUDIOBUDGET) are Phase 05.
- **Experience:** `Packages/ExperiencesCreative/VisualCoreMusicLab` (from A06-P01) gains the analysis: the canvas shows
  the live spectrum and level/beat meters next to the waveform; the source choice stays the only state.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the sound's level, spectrum and beat (Priority: P1) 🎯

A person playing the demo, a file or the microphone sees, besides the waveform, the sound's spectrum as bars from low to
high frequencies, a level meter (loudness and peak) and a beat meter that jumps on each beat and falls back smoothly.

**Why this priority**: the phase MVP ("RMS, peak, FFT spectrum and smoothed beat-energy signals") and the brainstorm's
primary capability ("authorized audio input, FFT and visual mapping").

**Independent Test**: open the experience with the demo tone at 1 kHz; the tallest spectrum bar is the band that holds
1 kHz; the level meter shows the tone's level; the canvas description names the level in words.

**Acceptance Scenarios**:

1. **Given** the demo 1 kHz tone, **When** a frame is drawn, **Then** the highest spectrum bar is the band containing
   1 kHz and the level meter reads the tone's level (RMS of a sine of amplitude 0.5 ≈ −9 dBFS) within 1 dB.
2. **Given** the demo note sequence (one note every half second), **When** frames are drawn over two seconds, **Then**
   the beat meter rises at each note start and decays between notes.
3. **Given** any source, **When** the person uses VoiceOver, **Then** the canvas description states the source, the level
   in words and whether a beat is present.

---

### User Story 2 - Silence is calm (Priority: P1)

When the source is silent (the demo silence mode, a silent file, a quiet room), every meter and bar rests at zero and the
display does not flicker.

**Why this priority**: the phase regression fixture.

**Independent Test**: choose the demo silence mode; after the analysis settles, all features are zero or near zero and
consecutive frames are identical.

**Acceptance Scenarios**:

1. **Given** digital silence, **When** analysed, **Then** RMS and peak are 0, every band energy is at the floor, flux is 0
   and no onset is reported.
2. **Given** silence after loud sound, **When** frames are drawn, **Then** the smoothed beat energy decays to below 1% of
   its peak within the release time and stays there; two consecutive frames of silence draw identical pixels.

---

### User Story 3 - Analysis you can trust (Priority: P2)

The level, band, flux, onset and smoothing calculations are correct on known signals, so later scenes can rely on them.

**Why this priority**: G-AUDIODSP's fixture tests; later phases map these features to visuals.

**Independent Test**: host tests with synthetic sine, square, clicks and silence.

**Acceptance Scenarios**:

1. **Given** a sine and a square of amplitude A, **When** measured, **Then** RMS is A/√2 and A, and peak is A, within
   1e-6 (relative).
2. **Given** a frame's spectrum, **When** grouped into bands, **Then** the band energies sum to the total energy of the
   bins they cover (within 1e-4 relative).
3. **Given** a click train (one click every 0.5 s in silence), **When** analysed hop by hop, **Then** an onset is
   reported within one hop of each click and nowhere else.
4. **Given** a step input, **When** smoothed, **Then** the output reaches 1 − 1/e of the step after the attack time and
   decays to 1/e after the release time (each within one frame).

### Edge Cases

- Fewer samples than one analysis window are available (just after a source starts): features are those of the
  available samples padded with silence; nothing fails.
- Sample rate other than 48 kHz (file or microphone): band edges are computed from the source's rate.
- Clipping input (samples at ±1 or beyond): peak is clamped at 1 for display; RMS stays finite.
- Non-finite samples (corrupt decoder output): treated as 0 for analysis.
- Switching source: smoothing restarts from zero so the previous source's beat does not linger.
- A frame-rate drop: smoothing uses the actual frame interval, so decay time stays the same in seconds.

## Requirements *(mandatory)*

### Functional Requirements

**Analysis in VisualCore (story 3)**
- **FR-A06-201**: VisualCore MUST compute, for one window of mono samples, RMS and peak (absolute maximum) levels, also
  expressed in dBFS with a floor of −120 dBFS for silence.
- **FR-A06-202**: VisualCore MUST group a spectrum into a fixed number of frequency bands (default 16, logarithmically
  spaced from 40 Hz to the lesser of 16 kHz and half the sample rate) and report each band's energy, in linear and dB
  form, such that band energies sum to the energy of the covered bins.
- **FR-A06-203**: VisualCore MUST compute spectral flux (sum of positive increases in band energy since the previous
  window) and report an onset when the flux exceeds an adaptive threshold (a multiple of its recent mean plus a minimum),
  at most one onset per minimum interval (100 ms).
- **FR-A06-204**: VisualCore MUST provide a feature smoother with separate attack and release time constants in
  seconds that uses the actual elapsed time per update and is reset to zero on demand.
- **FR-A06-205**: VisualCore MUST provide one feature extractor that takes the latest samples and returns a feature set
  (timestamp, RMS, peak, band energies, flux, onset, smoothed beat energy) with no allocation per call after setup.
- **FR-A06-206**: Silence (all zero samples) MUST yield RMS 0, peak 0, bands at the floor, flux 0 and no onset;
  non-finite samples are treated as 0.

**Experience (stories 1, 2)**
- **FR-A06-210**: VisualCore Music Lab MUST analyse the newest samples of the selected source once per drawn frame and
  draw, through the host, the spectrum bands as bars, a level meter (RMS with a peak mark) and a beat meter (smoothed beat
  energy) beside the waveform.
- **FR-A06-211**: The smoothed beat energy MUST be reset when the source changes and MUST decay with the release time in
  seconds independent of frame rate.
- **FR-A06-212**: The canvas description MUST state the source, the level in words (quiet, soft, medium, loud) and
  "beat" while the beat meter is above half scale.
- **FR-A06-213**: Features are not state: they are in neither the digest nor the snapshot; the scenario manifest and its
  digests are unchanged by this phase.

**Common**
- **FR-A06-220**: No networking, accounts or analytics; no recording; no ProjectM/MilkDrop code; no claims about hearing,
  health or musical accuracy.

### Key Entities

- **Audio features**: timestamp, RMS, peak, band energies, spectral flux, onset flag, smoothed beat energy.
- **Band layout**: band count, lowest and highest frequency, sample rate, transform size → bin ranges per band.
- **Smoother**: attack and release in seconds, current value.
- **Onset detector**: recent flux history, threshold multiple, minimum value, minimum interval.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A06-201**: RMS and peak of sine, square and silence match their closed forms within 1e-6 relative (silence
  exactly 0) in 100% of runs.
- **SC-A06-202**: For tones at 100 Hz, 1 kHz and 5 kHz, the band holding the tone has the highest energy, and band
  energies sum to the covered bins' energy within 1e-4 relative.
- **SC-A06-203**: On a 4-second click train with clicks every 0.5 s, 100% of clicks produce an onset within one hop and
  no onset occurs between clicks; on silence and a steady tone, no onset occurs.
- **SC-A06-204**: A step reaches 63% ± one frame interval after the attack time and decays to 37% ± one frame interval
  after the release time, at both 30 and 120 updates per second.
- **SC-A06-205**: In the experience, demo silence gives all meters at zero and two consecutive frames with identical
  pixels; the 1 kHz demo tone gives the tallest bar in the 1 kHz band.
- **SC-A06-206**: The nine scenarios and the fixture scenarios pass on iOS 27 with unchanged digests; the public-API
  baseline lists the new types, documented; every new test finishes in under 10 seconds.

## Assumptions

- The demo source of A06-P01 (tone 440 Hz, tone 1 kHz, silence, note sequence) is the test signal for the experience;
  click trains and squares are generated in host tests; no audio files are bundled.
- Analysis runs on the render side once per frame from the ring buffer (never in the audio callback), 1,024-point window.
- Mapping features to visual parameters, gain calibration and scenes are Phase 03; analysis quality levels Phase 05.

## Out of Scope

- Tempo (BPM) estimation, pitch detection, key detection.
- Scenes other than the waveform with spectrum and meters (Phase 03); presets (Phase 05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 02 (RMS, peak, FFT spectrum and smoothed beat-energy signals) | FR-A06-201–205, FR-A06-210 |
| Manual §9 Phase 02 fixture (silence → zero/near-zero features, stable display) | FR-A06-206, FR-A06-211, SC-A06-205 |
| Manual §6 data model `AudioFeatures(timestamp, rms, peak, bandEnergies, spectralFlux)` | FR-A06-205 |
| Manual §6 rule "compute FFT outside the realtime callback; smooth at frame boundary" | FR-A06-205, FR-A06-210, FR-A06-211 |
| Contract gap G-AUDIODSP | FR-A06-201–206 |
| Accessibility "text metrics" (v0.1 feature list) | FR-A06-212 |

## Negative Requirements

- No analysis in the audio callback; no allocation per analysis call after setup.
- No recording, upload or retention of audio; no hearing, health or accuracy claims.
- No second renderer or context; no ProjectM/MilkDrop code or preset format.
