# Feature Specification: Oscilloscope Studio — Phase 04 Cursors, freeze and presets

**Feature Branch**: `064-os-p04-cursors-presets` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A08-P04 (legacy ledger) · ID namespace FR-A08-4##, SC-A08-4##, T-A08-4##

**Input**: User description: archived manual `apps/08-oscilloscope-studio.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — freeze/capture, cursors and touch zoom; regression fixture — no
  clipping or false precision in displayed units; graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here (app-local):** G-SCOPEINTERACT (freeze, cursors, zoom) from
  `docs/apps/oscilloscope-studio/visualcore-contract.json`, and scope presets as versioned documents in the
  experience's own storage (matrix row M21, built on the existing persistence used by Audio Odyssey's journeys).
- **No VisualCore change expected.**
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`PinchRecognizer` (VisualCoreScenes) recognises a two-pointer pinch from `PointerEvent`s and reports a scale; the
experience presenter receives canvas touches through `handlePointer(_:viewSize:)` (the scope's presenter does not use
it yet); Audio Odyssey's `JourneyPresetStore` keeps one file `journey-<uuid>.json` per user preset in the experience's
`ExperienceStorage`, with built-ins in code, format checks (`.newer`, damaged) and counts of unreadable and newer files;
`ScopeState` is schema 2.

- Q: How are freeze and cursors saved? → A: `ScopeState` schema 3 adds `frozen` (Bool), `cursorsShown` (Bool),
  `cursorA`, `cursorB` (0…1 of the window, A ≤ B not required), `levelCursor` (−1…1 of full scale) and
  `frequencyCursor` (0…1 of the spectrum width); the migration from schema 2 adds frozen false, cursors hidden at
  0.25 / 0.75 / 0.5 / 0.5. Actions `freeze.set [0…1]`, `cursors.show [0…1]`, `cursor.a`, `cursor.b`, `cursor.level`,
  `cursor.frequency`. The held window itself is presenter state (not saved): a restored frozen state freezes the next
  acquired window.
- Q: How does pinch zoom map to the timebase? → A: The presenter feeds canvas pointers to a `PinchRecognizer`; each
  time the accumulated scale crosses a doubling (≥ 2 or ≤ 0.5 of the scale at the last step) it sends `timebase.select`
  one index down (pinch out, zoom in) or up (pinch in), clamped at 0 and 5; one-finger drags move the nearest cursor
  when cursors are shown. In the spectrum view pinch does nothing.
- Q: How are readouts formatted so they never claim false precision? → A: A `ScopeReadout` formatter in the core:
  time Δt = |B − A| × span, rounded to the sample period, shown with three significant digits in ms (or µs below
  0.1 ms) and with "1 sample" wording at one-sample spacing; 1/Δt in whole hertz, marked "(limited by the sample
  period)" when Δt is under 10 samples; level as a fraction of full scale with two decimals and its dBFS to 0.1 dB;
  |level| ≥ 1 reads "at or beyond full scale"; spectrum cursor frequency rounded to the bin width and marked
  "± <bin width> Hz".
- Q: What is a scope preset and where does it live? → A: `ScopePreset` (format 1): id, name (1…40 characters after
  trimming), saved time and the settings of `ScopeState` except the source, freeze and cursor positions; one file
  `scope-<uuid>.json` per user preset in the experience's storage; three built-ins with fixed synthetic ids ("Audio
  overview": sine 1 kHz, 1 ms/div, waveform; "Bass detail": 5 ms/div, ×2, waveform; "Spectrum check": spectrum view);
  `ScopePresetStore` mirrors `JourneyPresetStore` (list built-ins first, save, rename, delete, damaged and newer files
  kept and counted). Action `preset.apply [index]` applies an entry of the list.
- Q: What does the person see while frozen? → A: The trace stays as captured; the status says "frozen" with the frozen
  window's sample rate and channel count; gain changes rescale the frozen samples, a timebase change shows the frozen
  span cut or marked "frozen window shorter than the span"; a source change unfreezes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Freeze a moment and measure it (Priority: P1) 🎯

A musician freezes the scope: the shown trace stops with its sample rate, channel count and start position kept, while
the input keeps running behind it. They place two time cursors on two peaks and read the time between them and the
matching frequency; a level cursor reads the height relative to full scale.

**Why this priority**: the manual's MVP (freeze/capture and cursors).

**Independent Test**: freeze the 1 kHz test sine; place the cursors one period apart; the readouts say 1.00 ms and
1,000 Hz; the frozen window keeps its metadata while the buffer advances.

**Acceptance Scenarios**:

1. **Given** a running trace, **When** the person freezes it, **Then** the shown window and its sample rate, channel
   count, start position and settings stay unchanged on later frames although new samples keep arriving.
2. **Given** a frozen 1 kHz sine at 1 ms/div, **When** cursor A and cursor B are placed one period apart, **Then** the
   readout says Δt 1.00 ms and 1/Δt 1,000 Hz.
3. **Given** the level cursor at 0.5 of full scale, **When** read, **Then** it says "0.50 of full scale (−6.0 dBFS)".
4. **Given** the spectrum view, **When** the frequency cursor is placed, **Then** it reads that column's frequency and
   level in dBFS relative to full scale.
5. **Given** a frozen trace, **When** the person unfreezes, **Then** live drawing resumes from the newest samples.

---

### User Story 2 - Zoom by touch (Priority: P1)

A maker pinches the trace to zoom in or out in time; the timebase steps through the offered values and never beyond
them.

**Independent Test**: pinch-out steps the timebase down one value per doubling of the pinch scale; pinch-in steps it up;
the ends are clamped; each step is an action like the timebase control.

**Acceptance Scenarios**:

1. **Given** 1 ms/div, **When** the person pinches out by a factor of 2, **Then** the timebase becomes 0.5 ms/div.
2. **Given** 0.1 ms/div, **When** they pinch out further, **Then** it stays 0.1 ms/div.
3. **Given** a frozen trace, **When** they pinch, **Then** the frozen window is shown at the new timebase only from the
   frozen samples it holds (no invented samples); a wider span than the frozen window shows the frozen part and says
   so.

---

### User Story 3 - Save and reuse scope settings (Priority: P2)

A teacher saves the current settings as a named preset, renames or deletes it, and applies built-in presets for common
tasks; presets survive closing the app.

**Independent Test**: save, list, rename, apply, delete and reload presets from the experience's storage; damaged or
newer files are kept untouched and counted.

**Acceptance Scenarios**:

1. **Given** current settings, **When** saved as "Bass check", **Then** a preset with those settings appears, survives
   a new session and applies them exactly.
2. **Given** three built-in presets, **When** listed, **Then** they come first and cannot be renamed or deleted.
3. **Given** a damaged or newer preset file, **When** the list loads, **Then** the file is kept unchanged and counted,
   and the rest load.

---

### User Story 4 - The precision fixture (Priority: P2)

The owner can rely on a fixed check that no readout shows more precision than the data supports and no clipped value
is shown as a number beyond full scale.

**Independent Test**: readouts of time are never finer than one sample period, frequencies never finer than the
resolution they come from, levels at most 0.1 dB or two decimals of full scale, and clipped values read "at or beyond
full scale".

**Acceptance Scenarios**:

1. **Given** cursors one sample apart at 48 kHz, **When** read, **Then** Δt reads one sample period, shown as
   "1 sample, 20.8 µs" (µs below 0.1 ms, three significant digits), and the frequency is marked as limited by the sample period.
2. **Given** a cursor on a clipped sample, **When** read, **Then** it says "at or beyond full scale", not a number above
   1.

### Edge Cases

- **Cursors on top of each other:** Δt 0 shows no frequency ("cursors coincide").
- **Cursors outside the window:** positions are clamped to the window.
- **Freeze with no samples yet:** freezing an empty window is refused with a message.
- **Source change while frozen:** the freeze is released and the new source shows live.
- **Preset names:** 1…40 characters after trimming; duplicates allowed (presets are told apart by id).
- **Storage full or unwritable:** the save fails with a message and nothing is half-written.
- **Zoom in the spectrum view:** pinch does nothing there in this phase (the frequency span is fixed), and says so in
  the hint.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A08-401**: The scope MUST freeze and unfreeze the shown window; a frozen window keeps its samples and metadata
  (sample rate, channel count, start position, settings at freeze time) while the input keeps running.
- **FR-A08-402**: The scope MUST offer two time cursors (A, B) and a level cursor in the waveform view, with readouts
  Δt, 1/Δt and level as a fraction of full scale with its dBFS value, and a frequency cursor in the spectrum view.
- **FR-A08-403**: Pinch zoom MUST step the timebase through the offered values (one step per doubling), clamped at the
  ends, through the same action as the timebase control.
- **FR-A08-404**: Readouts MUST NOT show more precision than the data supports: time to three significant digits and
  never finer than one sample period; frequency to whole hertz and marked when limited by the sample period or bin
  width; levels to 0.1 dB and two decimals of full scale; values at or beyond full scale read "at or beyond full
  scale".
- **FR-A08-410**: Scope presets MUST be saved, listed, renamed, applied and deleted as versioned documents in the
  experience's own storage; built-in presets come first and are read-only; damaged and newer files are kept unchanged
  and counted.
- **FR-A08-411**: Freeze, cursor positions and the cursors' visibility MUST be part of the scope state (schema 3, saved
  with the session, migrated from schema 2); a restored frozen state freezes the next acquired window.
- **FR-A08-412**: Every new control has an accessible label and identifier; the description reads the frozen state and
  the cursor readouts.
- **FR-A08-420**: The scenario manifest MUST add fixtures for freeze with cursors, for zoom steps and for a preset
  applied.
- **FR-A08-430**: No networking, recording or storage of audio (presets hold settings only); no calibrated claims.

### Key Entities

- **Freeze**: frozen flag; the held window with its metadata.
- **Cursors**: A and B positions (0…1 of the window), level (−1…1 of full scale), frequency position (0…1 of the
  spectrum width), visibility.
- **Scope preset**: id, name, format version, settings (source excluded), saved time; built-ins with fixed ids.
- **Readout formatting**: time, frequency, level rules of FR-A08-404.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A08-401**: A frozen window stays identical over 60 frames while at least 1,024 new frames arrive.
- **SC-A08-402**: Cursors one period apart on sines of 100 Hz, 440 Hz and 1 kHz read the period within one sample and
  the frequency within the resolution shown.
- **SC-A08-403**: Pinch factors 0.25, 0.5, 2 and 4 from every timebase give the expected clamped steps.
- **SC-A08-404**: Save, rename, apply, delete and reload of presets work in 5 of 5 cases; damaged and newer files stay
  byte-identical.
- **SC-A08-405**: No readout in the tests shows a finer step than its rule allows; no clipped value reads above full
  scale; the fixtures pass on iOS 27; each package test finishes in under 10 seconds.

## Assumptions

- "Capture" in the manual's MVP is the frozen capture of the window with its sample metadata (the catalog's fixture
  "Freeze captures consistent sample metadata"); saving a still image of the screen is not part of version 0.1's
  slice and stays a later idea.
- Cursors are placed by sliders in the controls and by dragging on the canvas.

## Out of Scope

- Image or data export, measurement statistics, FFT size choice (later ideas); device-route and accuracy audits
  (A08-P05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 04 (freeze/capture, cursors and touch zoom) | FR-A08-401–403; stories 1, 2 |
| Catalog fixture "No clipping or false precision in displayed units" | FR-A08-404; story 4 |
| Catalog fixture "Freeze captures consistent sample metadata" | FR-A08-401; story 1 AC1 |
| Matrix row M21 (settings presets in per-experience storage) | FR-A08-410; story 3 |
| Contract gap G-SCOPEINTERACT | FR-A08-401–403 |

## Negative Requirements

- No audio stored, recorded or sent; presets hold settings only; no calibrated claims; no second renderer or context;
  no networking.
