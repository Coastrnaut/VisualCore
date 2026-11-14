# Feature Specification: VisualCore Music Lab — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `052-ml-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A06-P06 (legacy ledger) · ID namespace FR-A06-6##, SC-A06-6##, T-A06-6##

**Input**: User description: archived manual `apps/06-visualcore-music-lab.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009, Auto-Creator.md §21):** Music Lab is experience a06 of the one VisualCore app; there is no own
  store listing, price or dossier. Its store text is an input to the one app's listing. The phase's quality, privacy,
  accessibility and regression gates stand; device tasks are tagged {device} and wait for ImplementationLock-100;
  signing, archive upload and App Store Connect are owner-only (BLOCKED_OWNER_ACTION).
- **Precedent:** the A05-P06 release phase (`specs/045-ig-p06-release`, `docs/apps/infinite-geometry/*`) — same document
  set, release configuration, copy-claim check and interface chunk.
- **Gates (manual §9 Phase 06):** release checklist and artifact inventory complete; every required automated test has
  attached results and every device test is planned with its result pending the campaign; no unsupported promised
  feature in the interface or the store text; no fabricated measured performance claim.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: the
shared copy denylist (`Configs/copy-claims-denylist.json`) contains "audio", "music" and "microphone", which are real
Music Lab features, and `check_copy_claims.py --allow` removes such words per experience (A05 allowed "camera",
"share"); `release_check.py` derives `experience-release-<code>` and `copy-claims-<code>` steps from
`docs/apps/<slug>/release.json` and runs interface chunks from `UI_CHUNKS`; Infinite Geometry's `failNextDraw` seam and
its fixtures (`resources: [.copy("Fixtures")]`) are the precedent; the app already declares `NSMicrophoneUsageDescription`.

- Q: Which denylist words may Music Lab's copy use? → A: `copyCheck.allow` = ["audio", "music", "microphone"]; every
  measured-claim pattern and every other word stays refused.
- Q: Which interface chunk proves the journeys? → A: chunk "m2" with `MLScenesUITests` (scenes, palette, metrics) and
  `MLPresetsUITests` (mapping change, built-in preset, save) in `Apps/VisualCore/Tests/UI/MusicLab/` with an `MLSupport`
  helper following `IGSupport` (candidate launch); the microphone is never chosen in interface tests (no permission prompt
  automation).
- Q: Which preset fixtures are committed? → A: Five files in `ExperienceTests/Fixtures/`: format 1 (loads, Aurora),
  format 2 (loads, Ember), format 3 (newer, kept), damaged JSON (unreadable, kept), and a file whose name claims a
  built-in id (unreadable, kept); ids from the synthetic range `00000000-0000-4000-8000-0000000006b1…b5`.
- Q: How is the drawing failure forced? → A: An internal `failNextDraw` on `MusicLabPresenter` that makes the next draw
  throw `MusicLabDrawError.injected` once, as in Infinite Geometry.
- Q: How is the privacy manifest covered? → A: The release build checks' privacy-manifest step must pass; Music Lab adds
  no required-reason API beyond the file timestamps and defaults already declared for experience storage.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sound stays on my device and access is explained (Priority: P1) 🎯

The person's microphone input is used only while chosen, never recorded or sent; the one permission is explained in
plain words; nothing else about them leaves the device.

**Why this priority**: privacy is a release gate of the one app and the A06 constitution rules.

**Independent Test**: scan the experience's sources (no network, tracking, advertising or recording); check the one usage
string and the privacy manifest; read the privacy note.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** scanned, **Then** there is no network, tracking, advertising, file-writing
   of audio or sensor use beyond the microphone.
2. **Given** the app, **When** its usage strings are checked, **Then** exactly the existing microphone string covers Music
   Lab and says the sound drives the visuals on the device and is not recorded.
3. **Given** the privacy note, **When** read, **Then** it states what is stored (presets only, in the experience's own
   folder), that no audio is stored or sent, and the credits (no third-party assets; synthetic test audio).

---

### User Story 2 - My presets survive updates and failures (Priority: P1)

Saved presets of every format load correctly after an update; damaged or newer files are kept and reported; a drawing
failure never corrupts saved presets.

**Why this priority**: local data migration and crash recovery are named in the deliverable.

**Independent Test**: committed preset fixtures load as specified; a forced drawing failure puts the session into its
failure state with preset files byte-identical.

**Acceptance Scenarios**:

1. **Given** committed fixtures (format 1, format 2, newer format, damaged, a file claiming a built-in id), **When** the
   store opens, **Then** format 1 and 2 load (format 1 with the first palette), the others are counted and kept
   byte-identical.
2. **Given** a forced drawing failure, **When** a frame is drawn, **Then** the session reports the failure, the preset files
   are unchanged, and reopening the experience draws normally.

---

### User Story 3 - The store text promises only what exists (Priority: P2)

The store text and the in-app copy promise only implemented features, with no measured performance or health claims.

**Why this priority**: the gate "unsupported promised features removed".

**Independent Test**: the copy-claim check finds no measured or unimplemented claim; the release-document check finds
every required document.

**Acceptance Scenarios**:

1. **Given** the store text and the experience's interface copy, **When** the copy check runs, **Then** it finds 0
   problems.
2. **Given** the release configuration, **When** a required document is missing, **Then** the release-document check
   fails.

---

### User Story 4 - The interface proves the main journeys (Priority: P2)

An interface test chunk walks Music Lab's main journeys in the real app on the iOS 27 phone simulator.

**Why this priority**: the gate "required automated tests have attached results" for the interface.

**Independent Test**: the new chunk passes.

**Acceptance Scenarios**:

1. **Given** the app, **When** the chunk opens Music Lab, **Then** it switches scenes, changes a mapping, applies a
   built-in preset, changes the palette and reads the metrics text — each step visible through its control's identifier.
2. **Given** the chunk, **When** it runs, **Then** each test finishes in under 60 seconds.

### Edge Cases

- A preset file whose name does not match its id: counted as unreadable, kept.
- Storage quota reached while saving: refused with a message (covered in A06-P04); documented in known limitations.
- Microphone permission revoked in Settings while running: the next start fails and offers the demo (A06-P04 recovery).
- Device-only measurements (frame time, thermal, real interruptions, VoiceOver on hardware): planned in the device
  campaign, not claimed.

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**
- **FR-A06-601**: Music Lab MUST use only the app's existing microphone usage string and add no other permission.
- **FR-A06-602**: The experience's sources MUST contain no network, tracking, advertising, audio-recording or other
  sensor use (scan).
- **FR-A06-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A06-604**: A privacy and credits note MUST state what is stored, where, that no audio is stored or sent, how the
  permission is used, and the credits.

**Data and recovery (story 2)**
- **FR-A06-610**: Committed preset fixtures of each file form MUST load or be refused as specified, with refused files
  byte-identical.
- **FR-A06-611**: A forced drawing failure (test-only seam) MUST put the session into its failure state with preset
  files byte-identical, and a reopen MUST draw normally.

**Copy and release documents (story 3)**
- **FR-A06-620**: A release checklist with an artifact inventory, a store text input with a traceability table, a
  device-campaign plan and a release configuration MUST exist and pass the release-document check.
- **FR-A06-621**: The copy-claim check MUST find no measured or unimplemented claim in the store text and the interface
  copy.
- **FR-A06-622**: Known limitations MUST list Music Lab's device-only items; the device-campaign plan names each
  measurement with its device and pass criterion, results pending.

**Interface and builds (story 4)**
- **FR-A06-630**: An interface test chunk for Music Lab MUST pass on the iOS 27 phone simulator, each test < 60 s.
- **FR-A06-631**: The release build checks (release build, symbols, privacy manifest) MUST pass.
- **FR-A06-632**: Every Music Lab suite MUST pass on iOS 27; every new package test MUST finish in under 10 seconds.

**Common**
- **FR-A06-640**: No new permission, no network, no VisualCore change unless proven needed; owner-only steps are recorded
  as BLOCKED_OWNER_ACTION with exact steps.

### Key Entities

- **Release configuration**: required documents, checklist, copy-check sources and allowed words.
- **Release checklist**: items with area, status (verified/pending/blocked-owner/device) and evidence.
- **Preset fixtures**: one file per form with its expected outcome.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A06-601**: 1 usage string (the existing microphone string), 0 network uses, 0 tracking domains added; the privacy
  manifest check passes.
- **SC-A06-602**: 5 of 5 preset fixtures load or are refused as specified; refused files byte-identical.
- **SC-A06-603**: The forced drawing failure reaches the failure state in 1 of 1 run with preset files byte-identical; the
  reopen draws.
- **SC-A06-604**: The release-document check passes; removing a required document makes it fail.
- **SC-A06-605**: The copy check finds 0 problems.
- **SC-A06-606**: The interface chunk passes (each test < 60 s); the release build checks pass; all suites pass on iOS 27;
  every new package test < 10 s.

## Assumptions

- The release scripts used for A05 (`check_experience_release.py`, `check_copy_claims.py`, `release_check.py` steps
  derived from `release.json`) apply unchanged.
- Device measurements, accessibility audits and real interruptions run in the device campaign (owner rulings).

## Out of Scope

- Own store listing, price, screenshots and per-app dossier (one app); signing and uploads (owner-only).

## Traceability

| Source | Requirement |
|---|---|
| Manual §9 Phase 06 deliverable: privacy/permission strings, accessibility, credit review | FR-A06-601–604 |
| Deliverable: local data migration, crash recovery | FR-A06-610, 611 |
| Gate: checklist and artifact inventory; no unsupported promised features | FR-A06-620–622 |
| Gate: required automated and device tests with results | FR-A06-630–632, device campaign |
| Deliverable: build/archive instructions | FR-A06-620 (docs/release/build-and-archive.md), FR-A06-640 |

## Negative Requirements

- No fabricated measurements; no health, hearing or accuracy claims; no ProjectM/MilkDrop naming.
- No recording, upload or retention of audio; no new permission.
