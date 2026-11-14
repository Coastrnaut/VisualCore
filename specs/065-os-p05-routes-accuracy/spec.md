# Feature Specification: Oscilloscope Studio — Phase 05 Device-route and accuracy audits

**Feature Branch**: `065-os-p05-routes-accuracy` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A08-P05 (legacy ledger) · ID namespace FR-A08-5##, SC-A08-5##, T-A08-5##

**Input**: User description: archived manual `apps/08-oscilloscope-studio.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — the demo synthetic sine, square and sweep generator for tests (built in
  A08-P01; this phase audits its readouts end to end); regression fixture — freeze captures consistent sample
  metadata; graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/oscilloscope-studio/visualcore-contract.json`): G-STEREOMIC in VisualCore
  (a two-channel microphone source with a replaceable capture, proven with a test double; real stereo routes are
  measured in the device campaign), G-ACCURACY (app-local accuracy audit) and G-MEASUREA11Y (app-local measurement
  description and paced announcements). Quality levels are added and declared by the scope's core (lesson of X-A07).
- **Owner rulings:** short tests; system accessibility audits and all device measurements wait for the device
  campaign; iOS 27 at phase gates; reference regression at X-A08; every Spec Kit step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`MicrophoneAudioSource` (VisualCoreAudio) mixes to mono and builds its capture through the internal `MicrophoneCapture`
seam (`SystemMicrophoneCapture` holds session, engine and tap; tests inject a double), listens to session events through
`AudioSessionEventMonitor` and uses `MicrophonePermission`; `AnnouncementSink` lives in VisualCoreUI; Audio Odyssey's
`JourneyAnnouncer` paces announcements at 1.5 s; the host passes a quality tier to `draw(_:tier:context:frame:)` and a
core declares its levels with `qualityTiers` (default 1, which X-A07 showed hides the levels).

- Q: How is the two-channel microphone built without disturbing the mono one? → A: A new
  `StereoMicrophoneAudioSource: StereoAudioSource` in VisualCoreAudio with its own internal seam
  `StereoMicrophoneCapture` (start into a `StereoSampleBuffer`, returning sample rate and channel count; stop);
  `SystemStereoMicrophoneCapture` uses the mono source's session category, mode and options and taps the input node,
  keeping channels 0 and 1 (or duplicating channel 0 with channel count 1); permission, interruption and route-change
  handling follow `MicrophoneAudioSource` (same states, `ResumableAudioSource`-style resume); `MicrophoneAudioSource`
  is unchanged.
- Q: Which cases does the accuracy audit cover? → A: Sine at 100 Hz, 440 Hz, 1 kHz, 5 kHz; square at 440 Hz and
  1 kHz; the sweep at 0.5 s, 1 s and 1.5 s — each through acquisition (stereo buffer from the demo generator), trigger,
  window, cursors (period within one sample), spectrum readout (one bin, 1.5 dB; square: fundamental and ±0.50 of full
  scale) and readout wording; results written as an `AccuracyReport` (case, expected, measured, tolerance, pass).
- Q: What do the quality levels change? → A: `ScopeQuality` levels 0/1/2: column share 1, ½, ¼ of the pixel columns and
  spectrum analysis every 1, 2, 4 frames (the last readout is kept in between); `ScopeCore.qualityTiers = 3`; the
  registration's `quality_tiers` become `level-0`, `level-1`, `level-2`; a forced level for tests; digests unchanged.
- Q: What is announced and when? → A: `ScopeAnnouncer` (as `JourneyAnnouncer`, 1.5 s minimum interval, only while
  VoiceOver runs): announces view changes, freeze and unfreeze, trigger lost or regained, clipping start and end, and
  the channel count after a route change; the description builder covers each view and state.
- Q: Where are route and latency limits recorded? → A: In a new `docs/apps/oscilloscope-studio/device-campaign.md`
  section list started here (stereo routes, input latency, sample rates, thermal) with result "pending", completed and
  extended in A08-P06; known limitations gain the device-only items.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Readouts that match the known signal (Priority: P1) 🎯

An educator plays the built-in sine, square and sweep and sees readouts that agree with what the generator produces:
the cursor period, the spectrum peak frequency and the level, within the tolerances the scope states.

**Why this priority**: the manual's MVP (the demo generator for tests) and the catalog's accuracy risk.

**Independent Test**: an audit runs every demo waveform through the whole path (source, acquisition, trigger, window,
spectrum, readouts) and compares each readout with the generator's defining values.

**Acceptance Scenarios**:

1. **Given** the demo sine at 100 Hz, 440 Hz, 1 kHz and 5 kHz, **When** audited, **Then** the spectrum readout is within
   one bin of the frequency and 1.5 dB of the level, and cursors one period apart read the period within one sample.
2. **Given** the demo square, **When** audited, **Then** the waveform's extremes read ±0.50 of full scale and its
   spectrum peak is the fundamental.
3. **Given** the sweep, **When** audited at 0.5 s, 1 s and 1.5 s, **Then** the spectrum peak rises from one point to the
   next and lies within the frequency range the analysed 4,096-sample frame spans (the generator's frequencies at the
   frame's first and last sample), widened by one bin on each side.
4. **Given** any readout, **When** its words are examined, **Then** they say "relative to full scale" and never claim
   calibrated, certified, laboratory or medical accuracy.

---

### User Story 2 - Two-channel microphones where the route has them (Priority: P1)

A maker with a two-channel input uses the microphone in the XY view; the scope reports the channel count the route
delivers and keeps left and right apart; on a one-channel route it falls back to mono and says so.

**Independent Test**: a two-channel input double drives the microphone source; the channel count, separate channels and
the mono fallback are observed; permission and interruption behave as the mono source does.

**Acceptance Scenarios**:

1. **Given** a two-channel route (double), **When** the microphone runs, **Then** the source reports two channels and
   left and right samples stay separate.
2. **Given** a one-channel route, **When** the microphone runs, **Then** it reports one channel and the XY view keeps the
   "XY needs two channels" mark.
3. **Given** a denied permission or an interruption, **When** the microphone is chosen, **Then** the behaviour equals
   the existing mono microphone source (refusal message; stopped on interruption; resumable).

---

### User Story 3 - A scope that speaks and stays responsive (Priority: P2)

A VoiceOver user hears what the scope shows: mode, source, channel count, timebase or spectrum readout, frozen state
and clipping; changes are announced at most once per interval. Under heat or low power the scope lowers its work.

**Independent Test**: the description for each mode and state names the expected parts; announcements through a
recording sink are spaced by the interval; the three quality levels lower the drawn points and the analysis rate.

**Acceptance Scenarios**:

1. **Given** each view (waveform, XY, spectrum) and state (no signal, clipping, frozen, demo, mono), **When** described,
   **Then** the description names them in words.
2. **Given** rapid changes, **When** announced, **Then** at most one announcement per 1.5 s is made and only while
   VoiceOver runs.
3. **Given** quality level 1 or 2, **When** a frame is drawn, **Then** the trace has at most half or a quarter of the
   level-0 columns and the spectrum is analysed every second or fourth frame; the digest never changes with the level.

---

### User Story 4 - The freeze metadata fixture (Priority: P2)

The owner can rely on a fixed check that a frozen capture keeps consistent sample metadata.

**Acceptance Scenarios**:

1. **Given** a frozen window, **When** later frames arrive and the level or gain changes, **Then** its sample rate,
   channel count, start position, sample count and samples stay identical.

### Edge Cases

- **Route changes while running** (headset plugged or unplugged): the microphone rebuilds the capture with the new
  channel count and the scope says so; a frozen window keeps its own channel count.
- **Sample rates other than 48 kHz** (44.1 kHz routes): readouts use the delivered rate.
- **Latency:** the scope never claims a latency figure; route and latency limits are recorded for device measurement.
- **Quality level change while frozen:** the frozen samples are unchanged.

## Requirements *(mandatory)*

### Functional Requirements

**VisualCore (gap)**

- **FR-A08-501**: VisualCore MUST offer a two-channel microphone source that reports the route's channel count (1 or 2),
  keeps the first two channels apart, falls back to one channel on a one-channel route, uses the existing microphone
  permission, session and interruption behaviour, and has a replaceable capture for tests (G-STEREOMIC).

**Experience**

- **FR-A08-510**: An accuracy audit MUST compare readouts from the full path with the demo generator's defining values
  for every waveform and the listed frequencies, within one bin, one sample and 1.5 dB (G-ACCURACY).
- **FR-A08-511**: The microphone in the scope MUST use the two-channel source, so XY works with two-channel routes.
- **FR-A08-520**: The description MUST name view, source, channels, timebase or readout, frozen and clipping states;
  changes MUST be announced at most once per 1.5 s and only while VoiceOver runs (G-MEASUREA11Y).
- **FR-A08-521**: Three quality levels MUST lower the drawn columns (1, ½, ¼) and the spectrum analysis rate (every 1,
  2, 4 frames) without changing the digest, and the core MUST declare the three levels.
- **FR-A08-530**: Route, latency and calibration limits MUST be recorded for the device campaign; no claims without a
  device measurement.
- **FR-A08-531**: The scenario manifest MUST add a fixture for the frozen capture's metadata.

### Key Entities

- **Accuracy case**: waveform, frequency, expected and measured readouts, tolerance, pass.
- **Quality level**: column share and analysis interval.
- **Announcement**: text, time; minimum interval 1.5 s.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A08-501**: 100 % of accuracy cases pass within their tolerances.
- **SC-A08-502**: With the two-channel double the source reports 2 channels and separate samples; with a one-channel
  route it reports 1; permission and interruption cases match the mono source.
- **SC-A08-503**: Every view and state description names its parts; announcements are never closer than 1.5 s.
- **SC-A08-504**: At levels 1 and 2 the drawn points and analyses drop to ½ and ¼ (±1); digests are identical across
  levels; the core declares three levels.
- **SC-A08-505**: The frozen-metadata fixture passes on iOS 27; each package test finishes in under 10 seconds.

## Assumptions

- Device measurements (real stereo routes, latency, thermal behaviour) belong to the device campaign after
  ImplementationLock-100; this phase records what to measure.
- The quality governor of the host selects the level, as for other experiences.

## Out of Scope

- Calibration to volts or sound pressure; system audio capture; release documents (A08-P06).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 05 (demo sine/square/sweep generator for tests) | FR-A08-510; story 1 |
| v0.1 feature 06 (permission-aware audio input) and validity risk "routing" | FR-A08-501, 511; story 2 |
| Catalog fixture "Freeze captures consistent sample metadata" | FR-A08-531; story 4 |
| Catalog profiling ("separate acquisition sample rate from rendered frame rate") | FR-A08-521 |
| Contract gaps G-STEREOMIC, G-ACCURACY, G-MEASUREA11Y | FR-A08-501, 510, 520 |
| Lesson of X-A07 (core declares quality tiers) | FR-A08-521 |

## Negative Requirements

- No recording, storing or sending audio; no calibrated, certified, laboratory or medical claims; no latency figures
  without device measurement; no second renderer or context; no networking.
