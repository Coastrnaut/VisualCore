# Feature Specification: Oscilloscope Studio — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `066-os-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A08-P06 (legacy ledger) · ID namespace FR-A08-6##, SC-A08-6##, T-A08-6##

**Input**: User description: archived manual `apps/08-oscilloscope-studio.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009, Auto-Creator.md §21):** Oscilloscope Studio is experience a08 of the one VisualCore app; there is
  no own store listing, price or dossier. Its store text is an input to the one app's listing. The phase's quality,
  privacy, accessibility and regression gates stand; device tasks are tagged {device} and wait for
  ImplementationLock-100; signing, archive upload and App Store Connect are owner-only (BLOCKED_OWNER_ACTION).
- **Precedent:** the A07-P06 release phase (`specs/059-ao-p06-release`, `docs/apps/audio-odyssey/*`) — same document
  set, release configuration, copy-claim check, preset fixtures, forced drawing failure and interface chunk.
- **Gates (manual §9 Phase 06):** release checklist and artifact inventory complete; every required automated test has
  attached results and every device test is planned with its result pending the campaign; no unsupported promised
  feature in the interface or the store text; no fabricated measured performance or calibrated-accuracy claim.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: the
copy denylist (`Configs/copy-claims-denylist.json`) refuses "audio", "music" and "microphone" as words and any number
followed by Hz or ms as a measured claim; `check_copy_claims.py` keeps every pattern but skips a line marked
`copy-claims: allow`, and on the current sources it reports 5 hits, all signal units in `ScopePresenter.swift` (the
spectrum axis words "20 Hz", "100 Hz" and the "0 Hz" of number formatting); `ScopePresetStore.reload()` counts
`unreadable` and `newer` files and leaves them in place (files `scope-<uuid>.json`, format 1, built-ins
`…08A1…A3`); `ScopePresenter.failNextDraw` exists since A08-P01 (`ScopeDrawError.injected`); `ScopeControls` gives every
control an identifier from the port (`signal.waveform`, `display.select`, `gain.select`, `timebase.select`,
`freeze.toggle`, `cursors.show`, …); the Audio Odyssey chunk "o2" and `AOSupport` are the interface precedent; the app
already declares `NSMicrophoneUsageDescription` ("Listens to sound in the room to drive the visuals; audio stays on this
device and is not recorded.").

- Q: Which denylist words may Oscilloscope Studio's copy use? → A: `copyCheck.allow` = ["audio", "microphone"] (real
  inputs); "music" and every other word stay refused; every measured-claim pattern stays active.
- Q: How are the signal units (Hz, ms per division) in the interface copy kept from reading as performance claims? →
  A: Each source line whose literal names a unit of the displayed signal carries the marker comment
  `// copy-claims: allow (signal unit)`; the store text names no number with a unit at all.
- Q: Which preset fixtures are committed? → A: Five files `scope-<uuid>.json` in `ExperienceTests/Fixtures/`: format 1
  waveform settings (loads), format 1 spectrum settings (loads), format 2 (newer, kept), damaged JSON (unreadable,
  kept) and a file whose name claims the built-in id `…08A1` (unreadable, kept); ids from the synthetic range
  `00000000-0000-4000-8000-0000000008c1…c4`; the snapshot schema 1–3 examples already in the registry cover the state.
- Q: Which interface chunk proves the journeys? → A: Chunk "p2" with `OSScopeUITests` (waveform, timebase, gain, XY and
  spectrum views) and `OSPresetsUITests` (freeze, cursors, built-in preset, save) in
  `Apps/VisualCore/Tests/UI/OscilloscopeStudio/` with an `OSSupport` helper following `AOSupport` (candidate launch);
  the test signal is the source, the microphone is never chosen (no permission prompt automation).
- Q: How is the drawing failure forced? → A: The internal `failNextDraw` that `ScopePresenter` already has; the release
  phase adds the recovery test with preset files, not the seam.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sound stays on my device and access is explained (Priority: P1) 🎯

The person's microphone input is analysed only while chosen, never recorded or sent; the one permission is explained in
plain words; nothing else about them leaves the device.

**Why this priority**: privacy is a release gate of the one app and of the A08 constitution rules (audio privacy,
truthful measurement).

**Independent Test**: scan the experience's sources (no network, tracking, advertising or recording); check the one
usage string and the privacy manifest; read the privacy note.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** scanned, **Then** there is no network, tracking, advertising,
   file-writing of audio or sensor use beyond the microphone.
2. **Given** the app, **When** its usage strings are checked, **Then** exactly the existing microphone string covers
   Oscilloscope Studio and says the sound stays on the device and is not recorded.
3. **Given** the privacy note, **When** read, **Then** it states what is stored (presets and the scope settings only, in
   the experience's own folder), that no audio is stored or sent, how a picked file is read in place, and the credits
   (no third-party assets; synthetic test signals).

---

### User Story 2 - My presets survive updates and failures (Priority: P1)

Saved scope presets of every form load correctly after an update; damaged or newer files are kept and reported; a
drawing failure never corrupts saved presets.

**Why this priority**: local data migration and crash recovery are named in the deliverable.

**Independent Test**: committed preset fixtures load as specified; a forced drawing failure puts the session into its
failure state with preset files byte-identical.

**Acceptance Scenarios**:

1. **Given** committed fixtures (two current-format files, a newer format, damaged content, a file claiming a built-in
   id), **When** the preset store opens, **Then** both current-format files load with all their settings and the others
   are counted and kept byte-identical.
2. **Given** a forced drawing failure, **When** a frame is drawn, **Then** the session reports the failure, the preset
   files are unchanged, and reopening the experience draws normally.

---

### User Story 3 - The store text promises only what exists (Priority: P2)

The store text and the in-app copy promise only implemented features, with no measured performance and no calibrated,
certified, laboratory or medical accuracy.

**Why this priority**: the gate "unsupported promised features removed" and the catalog's accuracy risk.

**Independent Test**: the copy-claim check finds no measured or unimplemented claim; the release-document check finds
every required document.

**Acceptance Scenarios**:

1. **Given** the store text and the experience's interface copy, **When** the copy check runs, **Then** it finds 0
   problems; source lines whose literals name units of the displayed signal (Hz, ms per division) carry the
   `copy-claims: allow (signal unit)` marker, and the allowed words are exactly "audio" and "microphone".
2. **Given** the release configuration, **When** a required document is missing, **Then** the release-document check
   fails.
3. **Given** the store text, **When** read, **Then** it names relative-to-full-scale readouts and contains none of the
   words calibrated, certified, laboratory or medical.

---

### User Story 4 - The interface proves the main journeys (Priority: P2)

An interface test chunk walks Oscilloscope Studio's main journeys in the real app on the iOS 27 phone simulator.

**Why this priority**: the gate "required automated tests have attached results" for the interface.

**Independent Test**: the new chunk passes.

**Acceptance Scenarios**:

1. **Given** the app, **When** the chunk opens Oscilloscope Studio, **Then** it changes the waveform, the timebase and
   the gain, switches to XY and to the spectrum view, freezes and shows the cursors, applies a built-in preset and saves
   one — each step visible through its control's identifier.
2. **Given** the chunk, **When** it runs, **Then** each test finishes in under 60 seconds.

### Edge Cases

- A preset file whose name does not match its id: counted as unreadable, kept.
- Storage quota reached while saving: refused with a message (A08-P04); documented in known limitations.
- Microphone permission revoked in Settings while running: the next start is refused and offers the test signal
  (A08-P01 recovery).
- A restored session that used a file: the file is chosen again (A08-P01).
- Device-only measurements (frame time per view and level, thermal, real stereo routes, input latency, VoiceOver on
  hardware): planned in the device campaign, not claimed.

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**
- **FR-A08-601**: Oscilloscope Studio MUST use only the app's existing microphone usage string and add no other
  permission.
- **FR-A08-602**: The experience's sources MUST contain no network, tracking, advertising, audio-recording or other
  sensor use (scan).
- **FR-A08-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A08-604**: A privacy and credits note MUST state what is stored, where, that no audio is stored or sent, how the
  permission and a picked file are used, and the credits.

**Data and recovery (story 2)**
- **FR-A08-610**: Committed preset fixtures of each file form MUST load or be refused as specified, with refused files
  byte-identical.
- **FR-A08-611**: A forced drawing failure (test-only seam) MUST put the session into its failure state with preset
  files byte-identical, and a reopen MUST draw normally.

**Copy and release documents (story 3)**
- **FR-A08-620**: A release checklist with an artifact inventory, a store text input with a traceability table, the
  device-campaign plan and a release configuration MUST exist and pass the release-document check.
- **FR-A08-621**: The copy-claim check MUST find no measured or unimplemented claim in the store text and the interface
  copy; signal units shown to the person are marked as such line by line; the store text and the interface copy MUST
  NOT contain the words calibrated, certified, laboratory or medical (the store text says "relative to full scale").
- **FR-A08-622**: Known limitations MUST list Oscilloscope Studio's device-only items; the device-campaign plan names
  each measurement with its device and pass criterion, results pending.
- **FR-A08-623**: The device-campaign plan MUST include the accessibility audits (VoiceOver labels and values, Dynamic
  Type, Reduce Motion and Reduce Flashing, trace contrast), the CPU and GPU frame-time measurements per view and quality
  level, memory, persistence and lifecycle, real stereo routes and input latency, each with device and pass criterion;
  the release checklist marks them `device` until results are attached.

**Interface and builds (story 4)**
- **FR-A08-630**: An interface test chunk for Oscilloscope Studio MUST pass on the iOS 27 phone simulator, each test
  < 60 s; the microphone is never chosen in interface tests.
- **FR-A08-631**: The release build checks (release build, symbols, privacy manifest) MUST pass.
- **FR-A08-632**: Every Oscilloscope Studio suite MUST pass on iOS 27; every new package test MUST finish in under 10
  seconds.

**Common**
- **FR-A08-640**: No new permission, no network, no VisualCore change unless proven needed; build and archive
  instructions name the owner-only steps as BLOCKED_OWNER_ACTION with exact steps.

### Key Entities

- **Release configuration**: required documents, checklist, copy-check sources and allowed words.
- **Release checklist**: items with area, status (verified/pending/blocked-owner/device) and evidence.
- **Preset fixtures**: one file per form with its expected outcome.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A08-601**: 1 usage string (the existing microphone string), 0 network uses, 0 tracking domains added; the
  privacy manifest check passes.
- **SC-A08-602**: 5 of 5 preset fixtures load or are refused as specified; refused files byte-identical.
- **SC-A08-603**: The forced drawing failure reaches the failure state in 1 of 1 run with preset files byte-identical;
  the reopen draws.
- **SC-A08-604**: The release-document check passes; removing a required document makes it fail.
- **SC-A08-605**: The copy check finds 0 problems.
- **SC-A08-606**: The interface chunk passes (each test < 60 s); the release build checks pass; all suites pass on
  iOS 27; every new package test < 10 s.

## Assumptions

- The release scripts used for A07 (`check_experience_release.py`, `check_copy_claims.py`, `release_check.py` steps
  derived from `release.json`) apply unchanged.
- Device measurements, accessibility audits and real routes and interruptions run in the device campaign (owner
  rulings).

## Out of Scope

- Own store listing, price, screenshots and per-app dossier (one app); signing and uploads (owner-only); calibration to
  volts or sound pressure.

## Traceability

| Source | Requirement |
|---|---|
| Manual §9 Phase 06 deliverable: privacy/permission strings, accessibility, App Store asset/credit review | FR-A08-601–604, 623 |
| Deliverable: local data migration, crash recovery | FR-A08-610, 611 |
| Deliverable: CPU/GPU/device tests | FR-A08-623, 631, 632 |
| Gate: checklist and artifact inventory; no unsupported promised features | FR-A08-620–622 |
| Gate: required automated and device tests with results | FR-A08-630–632, device campaign |
| Deliverable: build/archive instructions | FR-A08-620 (docs/release/build-and-archive.md), FR-A08-640 |
| Catalog validity risks (units, calibration, latency, routing) | FR-A08-621, 623 |

## Negative Requirements

- No fabricated measurements; no calibrated, certified, laboratory or medical accuracy claim; no latency figure; no
  ProjectM/MilkDrop naming.
- No recording, upload or retention of audio; no new permission; no network.
