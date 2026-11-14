# Feature Specification: Oscilloscope Studio — Phase 01 Audio fixture and acquisition interface

**Feature Branch**: `061-os-p01-acquisition` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A08-P01 (legacy ledger) · ID namespace FR-A08-1##, SC-A08-1##, T-A08-1##

**Input**: User description: archived manual `apps/08-oscilloscope-studio.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — a time-domain waveform with adjustable gain and timebase and a
  selectable trigger; regression fixture — a known sine frequency maps to the expected number of display periods and
  to the expected spectrum bin; graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here in VisualCore** (docs, public-API baseline, tests; reference regression at X-A08 per the owner
  ruling of 2026-11-14), from `docs/apps/oscilloscope-studio/visualcore-contract.json`: G-DEMOWAVES (a deterministic
  sine, square and sweep test signal), G-STEREO for the test-signal and file paths (two channels kept apart), and
  G-TRIGGER (trigger detection with a timebase window), which moves from A08-P02 into this phase because the manual's
  Phase 01 gate asks for a selectable trigger. G-DECIMATION and G-TRACESTRIP stay for A08-P02; this slice draws at
  most one line segment per displayed sample over a bounded window.
- **Experience:** created in `Packages/ExperiencesCreative/OscilloscopeStudio`, registered as a candidate with its
  scenario manifest; the slice acquires real samples from the test signal, an app-owned file or the microphone and
  draws a real triggered trace (no placeholder). XY and spectrum modes arrive in A08-P03.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`SampleRingBuffer` (VisualCoreAudioDSP) is a lock-free single-writer buffer whose only read is
`latest(_:into:)` (the most recent samples) with `totalWritten`; `DemoSignal.Mode` has `sequence`, `tone440`,
`tone1k`, `silence` and A06 and A07 digests and fixtures depend on it; `DemoAudioSource` renders 1,024-frame blocks at
real-time pace from a main-run-loop timer; `FileAudioSource.init(url:)` decodes in 4,096-frame chunks and mixes to
mono; `MicrophoneAudioSource.start(into:)` writes mono; `SpectrumAnalyzer.expectedBin(frequency:sampleRate:size:)`
gives the nearest bin.

- Q: Do the new signals and the two-channel buffer change the existing demo and ring buffer? → A: No. New types live
  beside them in `VisualCoreAudioDSP`: `TestSignal` (sine, square, logarithmic sweep; amplitude, frequency, optional
  second channel with frequency ratio and phase) and `StereoSampleBuffer` (interleaved frames in a lock-free buffer
  with a frame counter and a read by absolute frame position). `DemoSignal`, `SampleRingBuffer` and every A06/A07
  digest stay byte-identical.
- Q: How do two-channel sources plug into the existing source family? → A: A new protocol `StereoAudioSource` in
  `VisualCoreAudio` (sample rate, state, channel count 1 or 2, start into a `StereoSampleBuffer`, stop) with
  `TestSignalAudioSource` (real-time pace like `DemoAudioSource`) and `StereoFileAudioSource` (keeps a stereo file's two
  channels, a mono file stays one channel). The microphone keeps the existing mono `MicrophoneAudioSource` and its
  permission flow; the experience reads it as a one-channel window.
- Q: Exactly how does the trigger find its position? → A: On the chosen channel, a rising crossing is the first sample
  at or above the level after a sample at or below level − hysteresis (falling: mirror image); the hysteresis is 2 % of
  full scale by default. The search looks for the most recent crossing whose full window (the timebase span) is
  already written, so the window ends at or before the newest frame. Auto mode shows the newest span untriggered when
  no crossing exists in the searched range (one window length of lookback); normal mode keeps the last triggered
  window and reports "waiting". Positions are whole samples.
- Q: Which timebases and gains are offered, and how is the window bounded? → A: Ten divisions; timebases 0.1, 0.2, 0.5,
  1, 2 and 5 ms per division; gains ×0.5, ×1, ×2, ×5 and ×10. The window holds round(timebase × 10 × sample rate)
  samples, capped at 4,096 per channel; a capped window (above 81.9 kHz at 5 ms/div) is marked as a shortened span.
  The buffer keeps 16,384 frames, so a window plus one window of lookback is always inside it.
- Q: What does the experience register and save in this phase? → A: A candidate registration with one quality level
  (`level-0`; levels arrive with the performance phase and must then be declared by the core), snapshot schema 1 with
  the scope state, actions `source.select`, `signal.waveform`, `signal.frequency`, `gain.select`, `timebase.select`,
  `trigger.level`, `trigger.slope`, `trigger.mode`; the nine standard scenarios plus fixtures for the 1 kHz period
  count, the spectrum bin and the flat-line no-trigger case, and (found at implementation: the planning catalog asks
  five fixtures) clipping beyond full scale and the sweep on a falling trigger.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A steady, triggered waveform (Priority: P1) 🎯

A musician opens Oscilloscope Studio and sees the built-in test signal as a steady waveform: each repetition starts at
the same place on the screen because the trace is triggered on a chosen level and slope. They change the gain and the
timebase and the trace grows, shrinks and widens predictably.

**Why this priority**: the manual's MVP for this phase; every later mode builds on acquired, triggered windows.

**Independent Test**: with the 1 kHz sine at a 1 ms/div timebase and 10 divisions, the displayed window holds 10
periods and the trace starts at the trigger level on the chosen slope in every frame.

**Acceptance Scenarios**:

1. **Given** the test signal (sine, 1 kHz, 48 kHz sample rate) and timebase 1 ms/div, **When** a window is acquired,
   **Then** it spans 10 ms (480 samples) and contains 10 ± 0.1 periods.
2. **Given** a rising-slope trigger at level 0, **When** consecutive windows are acquired, **Then** each starts within
   one sample of an upward zero crossing, so the displayed trace does not drift.
3. **Given** a falling slope or a different level within the signal's range, **When** windows are acquired, **Then**
   each starts at a crossing of that level in that direction.
4. **Given** gain ×2, **When** the trace is drawn, **Then** its vertical extent doubles and values beyond full scale
   are clipped at the screen edge and the clipping is reported.

---

### User Story 2 - Known test signals and sources (Priority: P1)

A maker chooses between a sine, a square and a frequency sweep, or plays an audio file they opened, or the
microphone after the permission prompt, and the scope shows each one; the person always knows which source is
active and whether it carries one or two channels.

**Why this priority**: the manual's acquisition interface and the catalog's demo generator; simulator and CI tests
depend on the synthetic signals.

**Independent Test**: the generator's sine, square and sweep produce the expected values at given times; a two-channel
test signal keeps left and right apart; a stereo file stays two channels; the microphone path reports one channel.

**Acceptance Scenarios**:

1. **Given** the square wave at 1 kHz, **When** a window is acquired, **Then** its samples take only the high and low
   levels (± the amplitude) and change sign once per half period.
2. **Given** the sweep from 100 Hz to 10 kHz over 2 s, **When** its spectrum is analysed at the start and after 1 s,
   **Then** the peak bin moves from near 100 Hz to near 1 kHz (logarithmic sweep).
3. **Given** a stereo test signal whose right channel runs at a different frequency, **When** a window is acquired,
   **Then** the left and right channels hold their own frequencies.
4. **Given** the microphone is chosen and the permission is denied, **When** the scope is shown, **Then** it says so,
   keeps the previous source and offers the test signal.

---

### User Story 3 - The regression fixture (Priority: P2)

The owner can rely on a fixed check: a known sine frequency gives the expected display periods and the expected
spectrum bin, so later phases can prove the acquisition did not drift.

**Independent Test**: for 440 Hz and 1 kHz sines at 48 kHz, the window period count and the spectrum peak bin match
the computed values.

**Acceptance Scenarios**:

1. **Given** a 440 Hz sine and timebase 5 ms/div, **When** a window is acquired, **Then** it holds 22 ± 0.1 periods.
2. **Given** a 1 kHz sine and a 4,096-point spectrum at 48 kHz, **When** it is analysed, **Then** the peak is the bin
   nearest 1 kHz (bin 85).

### Edge Cases

- **Flat line or silence:** no crossing exists; the trigger falls back to a free-running window (auto mode) and the
  scope says "no trigger" instead of freezing; in normal mode the last triggered trace stays and is marked as waiting.
- **Missing crossing** because the level lies outside the signal's range: same as a flat line.
- **Noise near the level:** a hysteresis band prevents re-triggering on noise; a crossing counts only after the signal
  left the band on the other side.
- **Too few samples buffered** (just started, or a short file): the window is shorter and marked partial; nothing
  outside the buffer is invented.
- **A file cannot be decoded or was moved:** the scope says so, keeps the previous source and offers the test signal;
  a file is chosen with the system file picker ("Choose file…", as Audio Odyssey does) and read only while chosen.
- **Mono sources:** the microphone and mono files deliver one channel; the window says so; nothing duplicates a channel
  silently.
- **Sample-rate changes** between sources: windows carry their own sample rate; the timebase stays in time units.
- **Interruptions and app background:** acquisition stops and resumes with the existing source lifecycle; a resumed
  window never mixes samples from before and after the gap.

## Requirements *(mandatory)*

### Functional Requirements

**VisualCore (gaps)**

- **FR-A08-101**: VisualCore MUST offer a deterministic test signal with sine, square and logarithmic sweep waveforms,
  amplitude and frequency settings and an optional second channel with its own frequency ratio and phase, producing
  identical samples for identical settings (G-DEMOWAVES).
- **FR-A08-102**: VisualCore MUST offer a two-channel sample buffer and two-channel sources for the test signal and for
  app-owned files, keeping the channels apart and reporting the real channel count (G-STEREO, test-signal and file
  paths); mono sources stay one channel.
- **FR-A08-103**: VisualCore MUST offer trigger detection on a channel with level, slope (rising or falling),
  hysteresis and mode (auto or normal), and a timebase window that turns time per division and a division count into
  a sample count and start index (G-TRIGGER).
- **FR-A08-104**: The same samples and settings MUST give the same trigger position and window; windows never read
  samples that were not written.

**Experience**

- **FR-A08-110**: Oscilloscope Studio MUST acquire windows from the chosen source (test signal, app-owned file or
  microphone) and show the triggered waveform with adjustable gain and timebase; clipping beyond full scale is shown.
- **FR-A08-111**: The scope state (source, test waveform and frequency, gain, timebase, trigger level, slope and mode)
  MUST be versioned, saved with the session and restored; its digest is deterministic.
- **FR-A08-120**: Oscilloscope Studio MUST be an experience of the one app in
  `Packages/ExperiencesCreative/OscilloscopeStudio`, registered as a candidate with its scenario manifest (the nine
  standard scenarios and the fixture scenarios).
- **FR-A08-121**: The experience MUST draw the grid and trace through the host (no context of its own) with at most
  one line segment per displayed sample and a window of at most 4,096 samples per channel.
- **FR-A08-122**: Every control has an accessible label and identifier; the canvas describes the source, channel count,
  timebase, gain, trigger state and whether the signal clips.
- **FR-A08-130**: No networking, accounts or analytics; no recording or storage of audio; no microphone monitoring to
  the speaker; levels shown relative to full scale only (no calibrated volts or sound-pressure claims).

### Key Entities

- **Test signal**: waveform, frequency, amplitude, sample rate, second-channel ratio and phase.
- **Signal window**: sample rate, channel count, sample count, start position in the stream, samples per channel,
  partial flag.
- **Trigger settings**: channel, level, slope, hysteresis, mode; result: crossing position or none.
- **Scope state** (schema 1): source, test waveform and frequency, gain, timebase, trigger settings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A08-101**: For sine frequencies 100 Hz, 440 Hz, 1 kHz and 5 kHz at 48 kHz and every offered timebase, the window
  holds the computed number of periods within ±0.1.
- **SC-A08-102**: For the same sines, the spectrum peak bin equals the computed nearest bin.
- **SC-A08-103**: Over 100 consecutive triggered windows of a sine with noise at −40 dBFS, every window starts within
  one sample of the true crossing on the chosen slope; a flat line and an out-of-range level never trigger.
- **SC-A08-104**: Square, sweep and two-channel test signals match their defining values at sampled times within 1e-6.
- **SC-A08-105**: The nine scenarios and the fixture scenarios pass on iOS 27; rendered frames of the sine and the
  square differ; each package test finishes in under 10 seconds.

## Assumptions

- The microphone path stays mono in this phase (the shared microphone source mixes down); route-dependent stereo
  microphone capture is assessed in the device-route audit (A08-P05).
- Decimation and thick trace strips (G-DECIMATION, G-TRACESTRIP) are A08-P02; the bounded window of this slice keeps
  the segment count at most 4,096 per channel.

## Out of Scope

- XY and spectrum display modes (A08-P03); freeze, cursors and presets (A08-P04); device-route and accuracy audits
  (A08-P05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 01 (time-domain waveform with gain, timebase and trigger) | FR-A08-103, 110; story 1 |
| v0.1 feature 05 (demo sine, square and sweep generator) | FR-A08-101; story 2 |
| v0.1 feature 06 (permission-aware audio input, safe microphone policy) | FR-A08-110, 130; story 2 |
| Manual §9 Phase 01 fixture (known sine → display periods and spectrum bin) | SC-A08-101, 102; story 3 |
| Catalog fixtures (flatline and missing crossing; mono marked; no false precision) | Edge cases, FR-A08-102, 130 |
| Journeys 1 and 2 | Stories 1, 2 |
| Contract gaps G-DEMOWAVES, G-STEREO, G-TRIGGER | FR-A08-101–104 |

## Negative Requirements

- No second renderer or context; no ProjectM code; no networking; no audio stored, recorded or sent; no calibrated
  measurement claims.
