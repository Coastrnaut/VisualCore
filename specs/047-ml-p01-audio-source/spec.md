# Feature Specification: VisualCore Music Lab — Phase 01 Audio source and permission shell

**Feature Branch**: `047-ml-p01-audio-source` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A06-P01 (legacy ledger) · ID namespace FR-A06-1##, SC-A06-1##, T-A06-1##

**Input**: User description: archived manual `apps/06-visualcore-music-lab.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — microphone permission-gated live input and local file audio the app can
  legally decode; regression fixture — a synthetic sine wave produces its peak at the expected spectrum bin within
  tolerance; graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here in VisualCore** (docs, public-API baseline, tests; reference regression at X-A06 per the owner ruling
  of 2026-11-14), from `docs/apps/visualcore-music-lab/visualcore-contract.json`: G-AUDIOSOURCE (one source interface),
  G-MICPERMISSION (permission state and request), G-FILESOURCE (decoding a file the person picks), G-RINGBUFFER
  (bounded sample buffer between the audio and render sides), G-DEMOSIGNAL (deterministic built-in signals), and the
  minimal spectrum transform the fixture needs (the rest of G-AUDIODSP — bands, RMS, onsets — is Phase 02).
- **Experience:** created in a new `Packages/ExperiencesAudio` package (A06-P00 decision), registered as a candidate
  with its scenario manifest; the slice draws the selected source's live waveform (no placeholder).
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: the
packages target iOS 26 (and macOS 15 for `VisualCore`), so the standard `Synchronization` module (`Atomic`) is
available for a lock-free buffer; `scripts/check_dependencies.py` allows `Accelerate` in pure modules; `VisualCoreAudioDSP`
is a target of the `VisualCore` package and `VisualCoreAudio` of `VisualCoreRendering` (depending on the DSP product);
`NSMicrophoneUsageDescription` is absent from the app.

- Q: How does the audio side hand samples to the render side without waiting or allocating? → A: A single-producer,
  single-consumer ring buffer of `Float` with power-of-two capacity, preallocated, whose write and read positions are
  `Atomic<Int>` (acquire/release ordering); the writer never blocks and overwrites the oldest samples on overflow; the
  reader copies the latest N samples into a caller-provided array. Lives in `VisualCoreAudioDSP` (pure, host-testable).
- Q: How is the spectrum computed? → A: Accelerate's vDSP real FFT on a Hann-windowed frame of N = 256…4,096 samples
  (power of two), magnitudes in dB relative to full scale; in `VisualCoreAudioDSP`. Only the transform and peak-bin
  lookup are built now (the fixture); bands, RMS and onsets are Phase 02.
- Q: How are the microphone and permission handled testably? → A: `VisualCoreAudio` wraps the system record permission
  behind a `MicrophonePermission` protocol (state: notDetermined/granted/denied/restricted; `request()`), with the
  system implementation using `AVAudioApplication` and a test double; the microphone source uses `AVAudioEngine`'s input
  node tap converting to mono `Float` into the ring buffer, started only when the state is granted. The simulator tests
  use the double; real input is checked in the device campaign.
- Q: Which file formats and how is a file chosen? → A: Any file `AVAudioFile` can read (WAV, AIFF, CAF, M4A/AAC, MP3),
  chosen with the system file importer (security-scoped access, read only, not copied); decoded in chunks of 4,096
  frames to mono `Float` and looped; tests generate original WAV, CAF and M4A tones at runtime.
- Q: What does the demo source play? → A: A seeded, deterministic mix: a tone sequence (sine notes on a pentatonic scale,
  one note per half second, seed chooses the order) at −12 dBFS plus quiet seeded noise, generated on the fly at 48 kHz;
  no file, no permission.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose a sound source and see it (Priority: P1) 🎯

A person opens VisualCore Music Lab and sees a waveform moving at once, from a built-in demo signal, with no permission
asked. They can switch to the microphone or to an audio file they pick, and the waveform follows the chosen source; a
status line says which source is playing.

**Why this priority**: the phase MVP and journey 1 of the brainstorm ("choose microphone or an app-owned audio file and
grant permission where needed").

**Independent Test**: open the experience; the demo source is active and the drawn waveform matches the demo signal;
switch to a file source with a committed test file; the drawn waveform changes accordingly; the status names the source.

**Acceptance Scenarios**:

1. **Given** a first launch, **When** the experience opens, **Then** the demo signal plays into the waveform, no
   permission is requested, and the status reads "Demo signal".
2. **Given** a file the person picks (WAV, AIFF, CAF, M4A/AAC or MP3 the system can decode), **When** it is chosen,
   **Then** its audio drives the waveform, it loops, and the status shows the file's name.
3. **Given** a file the system cannot decode, **When** it is chosen, **Then** a plain message explains it, the previous
   source keeps playing, and nothing is stored.

---

### User Story 2 - Live microphone, only with permission (Priority: P1)

A person chooses the microphone. If permission was never asked, the system asks with an honest explanation; if granted,
the live input drives the waveform; if denied or restricted, the experience says so, offers the demo and file sources,
and explains how to allow access in Settings. Audio never leaves the device and is not recorded.

**Why this priority**: the other half of the MVP; the constitution's audio-privacy rule.

**Independent Test**: with permission states simulated (not determined, granted, denied, restricted), the experience
shows the right state, requests only when not determined, and falls back without failing.

**Acceptance Scenarios**:

1. **Given** permission not determined, **When** the microphone is chosen, **Then** the system request is shown once.
2. **Given** permission denied or restricted, **When** the microphone is chosen, **Then** no request is shown, a message
   with the way to Settings appears, and the previous source keeps playing.
3. **Given** permission granted, **When** the microphone is chosen, **Then** live input drives the waveform and the status
   reads "Microphone".

---

### User Story 3 - Analysis you can trust (Priority: P2)

The spectrum transform used later by the scenes is correct: a pure tone shows its peak in the right frequency bin.

**Why this priority**: the phase's regression fixture.

**Independent Test**: feed a synthetic sine at a known frequency and sample rate; the strongest bin is the expected bin
(± 1).

**Acceptance Scenarios**:

1. **Given** sines at 440 Hz, 1 kHz and 5 kHz at 48 kHz with a 1,024-point transform, **When** analysed, **Then** the peak
   bin equals round(f × N / fs) ± 1 and its magnitude dominates every bin more than 2 bins away by at least 20 dB.
2. **Given** silence, **When** analysed, **Then** every bin is (near) zero and nothing is reported as a peak.

### Edge Cases

- The sample rate of a file or the microphone differs from 48 kHz: the source reports its rate; analysis uses it.
- A very long file: decoded in bounded chunks into the ring buffer; memory stays bounded.
- The ring buffer is full (render side slower): oldest samples are overwritten; the audio side never waits.
- The ring buffer is empty (audio side slower): the waveform shows the last samples or silence, never garbage.
- Leaving the experience stops every source and releases the microphone; returning restarts the selected source (with
  permission re-checked).
- Switching sources rapidly ends with exactly the last chosen source playing.

## Requirements *(mandatory)*

### Functional Requirements

**Sources (stories 1, 2)**
- **FR-A06-101**: VisualCore MUST offer one audio source interface with three kinds — demo signal, file, microphone —
  each delivering mono floating-point samples at a reported sample rate into a bounded buffer, with start and stop.
- **FR-A06-102**: The demo source MUST be deterministic (same seed → same samples) and need no permission.
- **FR-A06-103**: The file source MUST decode a person-picked file the system can decode, loop it, and refuse an
  undecodable file with a message while the previous source continues.
- **FR-A06-104**: The microphone source MUST start only with granted permission; the permission state (not determined,
  granted, denied, restricted) MUST be readable, and the request MUST be made only when not determined.
- **FR-A06-105**: No audio is written to disk and nothing leaves the device; the microphone is released when the
  experience leaves or the source changes.
- **FR-A06-106**: The app MUST declare a microphone usage description stating that the input drives the visuals on the
  device and is not recorded or sent.

**Buffer and analysis (story 3)**
- **FR-A06-110**: VisualCore MUST provide a fixed-capacity sample ring buffer: one writer (audio side) never waits and
  never allocates while writing; one reader takes the latest samples; overflow drops the oldest.
- **FR-A06-111**: VisualCore MUST provide a spectrum transform (windowed, power-of-two sizes 256–4,096) whose peak for a
  pure tone lies at the expected bin within ± 1 bin.

**Experience (story 1)**
- **FR-A06-120**: VisualCore Music Lab MUST be an experience of the one app in `Packages/ExperiencesAudio`, registered as
  a candidate with the nine standard scenarios and one scenario per regression fixture of the planning catalog.
- **FR-A06-121**: The experience MUST draw the selected source's waveform through the host (no context of its own) and
  show a source status; the source choice is part of its state (digest, snapshot), samples are not.
- **FR-A06-122**: Every control has an accessible label and identifier; the canvas describes the source and level in
  words.

**Common**
- **FR-A06-130**: No networking, accounts or analytics; no system-audio capture of other apps; no ProjectM/MilkDrop code.

### Key Entities

- **Audio source**: kind, sample rate, state (idle, running, failed with a reason), start/stop.
- **Permission state**: not determined, granted, denied, restricted.
- **Sample ring buffer**: capacity, write position, total written; latest-N read.
- **Spectrum**: size N, window, magnitudes per bin.
- **Music Lab state**: selected source kind, file name (for display), demo seed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A06-101**: For sines at 440 Hz, 1 kHz and 5 kHz (48 kHz, N = 1,024), the peak bin is within ± 1 of the expected
  bin and dominates distant bins by ≥ 20 dB in 100% of runs.
- **SC-A06-102**: The demo source produces identical samples for the same seed in 100% of runs; different seeds differ.
- **SC-A06-103**: In 200 seeded write/read sequences the ring buffer never exceeds capacity, returns the latest samples in
  order, and the writer never blocks.
- **SC-A06-104**: Committed test files of three formats decode to the expected sample count and rate; an invalid file is
  refused with the previous source still running.
- **SC-A06-105**: For each permission state the experience requests at most once and falls back correctly (100% of
  simulated states).
- **SC-A06-106**: The nine scenarios and the fixture scenarios pass on iOS 27; the public-API baseline lists the new
  types, documented; every new test finishes in under 10 seconds.

## Assumptions

- The microphone itself cannot be exercised in automated simulator tests (no permission prompt automation); live input
  is verified on devices in the device campaign; tests use the permission-state seam and the demo/file sources.
- Test audio files are generated by the tests themselves (original synthetic tones), so no third-party audio is bundled.
- Bands, RMS, onsets and audio-to-parameter mapping arrive in Phase 02/03.

## Out of Scope

- Streaming services, system audio of other apps, recording or exporting audio.
- Scenes other than the waveform (Phase 03); presets (Phase 05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 01 (mic permission-gated live input and local file audio) | FR-A06-101–106 |
| v0.1 feature 06 (silent demo signal for offline testing) | FR-A06-102 |
| Manual §9 Phase 01 fixture (sine → expected FFT bin) | FR-A06-111, SC-A06-101 |
| Journey 1 (choose microphone or a file, grant permission) | User stories 1, 2 |
| Contract gaps G-AUDIOSOURCE, G-MICPERMISSION, G-FILESOURCE, G-RINGBUFFER, G-DEMOSIGNAL | FR-A06-101–111 |

## Negative Requirements

- No recording, upload or retention of audio; no capture of other apps' audio; no measurement or health claims.
- No second renderer or context; no ProjectM/MilkDrop code or preset format.
