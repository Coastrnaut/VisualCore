# Feature Specification: Oscilloscope Studio — Phase 03 Spectrum and XY modes

**Feature Branch**: `063-os-p03-spectrum` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A08-P03 (legacy ledger) · ID namespace FR-A08-3##, SC-A08-3##, T-A08-3##

**Input**: User description: archived manual `apps/08-oscilloscope-studio.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — an FFT spectrum view with dB-style annotation where it is valid;
  regression fixture — the stereo XY view is disabled or clearly marked for mono sources (the behaviour exists since
  A08-P02; this phase adds its scenario fixture); graphics-context ownership stays solely in the VisualCore host.
- **Gap built here:** G-SPECTRUMLABELS (app-local) from `docs/apps/oscilloscope-studio/visualcore-contract.json`. The
  XY view (G-XYMODE) was closed in A08-P02 because the manual's Phase 02 gate asked for it.
- **No VisualCore change expected:** the spectrum analyser, the column reduction and the multi-point line shape exist;
  if one proves missing, it is added as an upstream task with docs, tests and the API baseline.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A spectrum with honest annotation (Priority: P1) 🎯

A musician switches the scope to the spectrum view and sees the frequency content of the signal on a logarithmic
frequency axis with decade marks, a level axis in decibels relative to full scale, and a readout of the strongest
component ("peak 1,000 Hz at −6 dBFS, relative to full scale"). The readout appears only when it is valid.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: for known sines the readout names the expected frequency (within one bin) and level (within the
analysis window's ripple), and for silence, clipping or a frame still filling it names why no value is shown.

**Acceptance Scenarios**:

1. **Given** the 1 kHz test sine at amplitude 0.5, **When** the spectrum view is shown, **Then** the peak readout says
   about 1,000 Hz (within one bin, 11.7 Hz at 48 kHz) and about −6 dBFS (within 1.5 dB).
2. **Given** silence or a signal whose strongest bin is below −100 dBFS, **When** the spectrum is shown, **Then** no
   peak value appears and the readout says "no signal".
3. **Given** a window that clips at full scale, **When** the spectrum is shown, **Then** the readout says the level
   is not valid while clipping.
4. **Given** the sweep, **When** frames pass, **Then** the peak readout follows the sweep's frequency.
5. **Given** a two-channel source, **When** the spectrum view is shown, **Then** the left channel is analysed and the
   readout says so; mono sources are analysed as their one channel.

---

### User Story 2 - The spectrum is drawn within bounds (Priority: P1)

The spectrum curve is drawn with no more points than the screen has pixel columns, keeps every peak, and fits the
level axis from 0 to −100 dBFS.

**Independent Test**: the drawn curve has at most two points per pixel column and its highest point is the strongest
bin's level.

**Acceptance Scenarios**:

1. **Given** a 4,096-point analysis (2,048 bins), **When** it is drawn into N pixel columns, **Then** each column shows
   the strongest bin of its frequency range and the curve has at most 2 N points.
2. **Given** levels below −100 dBFS, **When** drawn, **Then** they sit on the bottom of the level axis.

---

### User Story 3 - The mono XY fixture (Priority: P2)

The owner can rely on a fixed check that the XY view never plots a mono source and marks it instead.

**Independent Test**: a scenario fixture with a mono source and the XY view chosen ends with the waveform shown and
the mark "XY needs two channels".

**Acceptance Scenarios**:

1. **Given** the microphone (mono) and the XY view, **When** frames are drawn, **Then** the XY figure is not drawn and
   the mark is shown and spoken.

### Edge Cases

- **Frame still filling** (fewer than 4,096 frames written): the spectrum is drawn from the frames available and the
  readout says "filling"; no peak value is shown.
- **Peak in bin 0 (DC) or at Nyquist:** ignored for the readout; the readout names the strongest bin in between.
- **Sample rates other than 48 kHz:** axis marks and readouts use the window's own rate (for example 44.1 kHz).
- **Gain:** the spectrum shows the signal as acquired, not scaled by the display gain; the readout says the level is
  relative to full scale.
- **Reduce Motion / Reduce Flashing:** no animated decay or flashing peak marks are used.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A08-301**: The scope MUST offer a spectrum view that analyses the newest 4,096 frames of the left (or only)
  channel and draws magnitude against a logarithmic frequency axis from 20 Hz to half the sample rate, levels from
  0 to −100 dBFS.
- **FR-A08-302**: The spectrum curve MUST be reduced to the canvas's pixel columns, keeping the strongest bin of each
  column, with at most two points per column.
- **FR-A08-303**: The annotation MUST show decade frequency marks (100 Hz, 1 kHz, 10 kHz where in range) and level
  marks every 20 dB, and a peak readout (frequency to the nearest bin, level in dBFS relative to full scale) only when
  valid: not when the strongest bin is below −100 dBFS ("no signal"), not while the window clips ("clipping, level not
  valid"), not while the frame is filling ("filling").
- **FR-A08-304**: The display choice MUST include the spectrum view (waveform, XY, spectrum) and be saved with the
  scope state; states saved before this phase restore unchanged.
- **FR-A08-305**: The canvas description MUST name the spectrum view and read the peak readout or the reason it is
  absent.
- **FR-A08-310**: The scenario manifest MUST add fixtures for the spectrum view and for the mono source in XY.
- **FR-A08-320**: No calibrated sound-pressure, volt or certified-accuracy claims; levels are always "dBFS, relative to
  full scale"; no networking, recording or storage of audio.

### Key Entities

- **Spectrum frame**: sample rate, size 4,096, magnitudes in dBFS per bin, filling flag.
- **Spectrum annotation**: decade marks, level marks, peak readout (frequency, level) or the reason it is absent.
- **Scope state**: display ∈ {waveform, XY, spectrum}.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A08-301**: For sines of 100 Hz, 440 Hz, 1 kHz and 5 kHz at amplitudes 0.5 and 0.1 (48 kHz and 44.1 kHz), the
  readout frequency is within one bin of the true frequency and the level within 1.5 dB of 20·log10(amplitude).
- **SC-A08-302**: Silence, a clipping window and a filling frame never show a peak value; each names its reason.
- **SC-A08-303**: The drawn spectrum has at most 2 points per pixel column and its highest point equals the strongest
  bin's level (clamped to the axis).
- **SC-A08-304**: The mono-XY fixture and the spectrum fixture pass on iOS 27; saved states from A08-P02 restore.
- **SC-A08-305**: Each package test finishes in under 10 seconds.

## Assumptions

- The Hann window's ripple bounds the level error at about 1.4 dB for a sine between bins (hence 1.5 dB).
- The spectrum uses the same acquisition buffer as the waveform; no extra audio processing runs on the audio thread.

## Out of Scope

- Selectable FFT size and window function, cursors, freeze and presets (A08-P04); accuracy and route audits (A08-P05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 03 (FFT spectrum mode with calibrated dB-style annotation where valid) | FR-A08-301–305; story 1 |
| Catalog decision "windowed FFT with bin-frequency mapping and log-domain zero guards" | FR-A08-301, 303 |
| Catalog decision "separate real measured levels from relative/un-calibrated display values" | FR-A08-303, 320 |
| Manual §9 Phase 03 fixture (XY disabled or marked for mono sources) | FR-A08-310; story 3 |
| Catalog fixture "Known sine frequency maps to … spectrum bin" | SC-A08-301 |
| Contract gap G-SPECTRUMLABELS | FR-A08-303 |

## Negative Requirements

- No SPL, volt or certified-accuracy wording; no second renderer or context; no ProjectM code; no networking; no audio
  stored, recorded or sent.
