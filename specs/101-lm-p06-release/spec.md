# Feature Specification: Light Maze — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `101-lm-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A13-P06 (legacy ledger) · ID namespace FR-A13-6##, SC-A13-6##, T-A13-6##

**Input**: User description: archived manual `apps/13-light-maze.md` §9 Phase 06 `/speckit-specify` prompt (verbatim
in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; every required
  automated test has attached results and every device row is listed (pending until the device campaign); unsupported
  promised features are removed from the interface and the store copy.
- **One app (ADR-0009):** the per-app store listing, pricing and release dossier are inapplicable; Light Maze's store
  text is an input to the one app's listing. Quality, privacy, accessibility and regression gates stand.
- **Device tasks** are tagged {device} and run only after ImplementationLock-100; owner-only steps (signing, upload,
  App Store Connect) are recorded as BLOCKED_OWNER_ACTION.
- **Owner rulings:** short tests; audits in the device campaign; iOS 27 at phase gates; reference regression and iOS 26
  at X-A13; interface tests under 60 s each.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A person can trust Light Maze: it asks for no permission, sends nothing anywhere, tracks nothing, and keeps only its
level progress and the session state on the device; a plain note says so and credits the levels.

**Why this priority**: privacy is a release gate (constitution A13: offline and private).

**Independent Test**: a scan of the experience's sources finds no network, tracking, sensor, recording or permission
use; the app's privacy declarations cover what it uses; the privacy and credits note matches the code.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** they are scanned, **Then** no network, tracking, advertising, location,
   camera, microphone, recording, motion or contacts use is found.
2. **Given** the app's privacy declarations, **When** they are checked, **Then** every required-reason use is covered
   and no tracking is declared.
3. **Given** the privacy and credits note, **When** it is read, **Then** it names the progress file and the session
   state, states that nothing is sent and no personal data is kept, explains how to delete them, and credits the 20
   levels and the code-made sound with their license.

---

### User Story 2 - Damaged progress never stops play (Priority: P1)

Progress files written by this version, by a newer version, damaged ones and half-written ones are each handled as
specified, older saved states restore, and a drawing failure recovers without touching the progress file.

**Why this priority**: the manual's "local data migration" and "crash recovery".

**Acceptance Scenarios**:

1. **Given** committed sample progress files (valid, newer version, damaged, truncated), **When** each is opened,
   **Then** the valid one loads, the others are refused with their reason and play starts from fresh progress, and none
   is changed.
2. **Given** a forced drawing failure, **When** it happens, **Then** the session shows its failure state, the progress
   file is byte-identical, and reopening draws the maze.
3. **Given** saved states of the earlier schema (1), **When** restored, **Then** they migrate.

---

### User Story 3 - Honest store copy and a complete checklist (Priority: P1)

Whoever prepares the release finds a store text that promises only what Light Maze does (every claim traced to a
test), no measured performance claims and no physics, optics-accuracy or scientific claims, a release checklist with
an artifact inventory, a release configuration, the device-campaign plan and the known limitations.

**Acceptance Scenarios**:

1. **Given** the store text, **When** it is checked, **Then** every claim has a proving test and no measured or refused
   claim appears.
2. **Given** the release checklist, **When** it is read, **Then** every item has a status and evidence or owner steps.
3. **Given** a missing release document, **When** the check runs, **Then** it fails and names the document.

---

### User Story 4 - The maze works in the real app (Priority: P2)

Light Maze's main journeys work through the app's interface on the iOS 27 phone simulator — choosing a level,
selecting and turning a mirror to solve level 1, undoing, asking for a hint and hearing the board — and the release build
and its checks pass.

**Acceptance Scenarios**:

1. **Given** the app with Light Maze, **When** the interface tests run, **Then** those journeys work by their controls,
   each test under 60 s.
2. **Given** a release build, **When** its checks run, **Then** the build, symbols, privacy manifest, no-tracking,
   licenses and usage descriptions checks pass.

### Edge Cases

- **A device row without results:** stays pending; no measured value is claimed.
- **An owner step not done:** recorded as BLOCKED_OWNER_ACTION with the exact steps; work continues.
- **A store claim without a test:** the copy check fails.
- **A progress file from a future version:** refused and never rewritten until the next solve replaces it.
- **Gestures in interface tests:** canvas gestures are covered by the gesture tests; the interface tests use the native
  controls (every gesture has one).

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**

- **FR-A13-601**: Light Maze MUST request no permission and add no usage string.
- **FR-A13-602**: The experience's sources MUST contain none of the scanned network, tracking, sensor, recording,
  brightness or idle-timer uses.
- **FR-A13-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A13-604**: A privacy and credits note MUST state what is stored and where, that nothing is sent, how to delete it,
  and credit the 20 levels and the sound with author and license.

**Data and recovery (story 2)**

- **FR-A13-610**: Committed sample progress files of each form MUST load or be refused as specified, with refused files
  byte-identical and play starting from fresh progress.
- **FR-A13-611**: A forced drawing failure (test-only seam) MUST put the session into its failure state with the progress
  file byte-identical, and a reopen MUST draw normally.
- **FR-A13-612**: Saved states of schema 1 MUST restore (stored example), re-run here.

**Copy and release documents (story 3)**

- **FR-A13-620**: A release checklist with an artifact inventory, a store text input with a claim → test table, the
  device-campaign plan and a release configuration MUST exist and pass the release-document check.
- **FR-A13-621**: The shared copy-claim check MUST pass on the store text and the interface copy, and Light Maze's own
  scan MUST refuse physics, accuracy, scientific and measured-performance words.
- **FR-A13-622**: Known limitations MUST list the device-only items (frame pacing, thermals, memory high-water mark,
  touch latency, haptic and sound feel, accessibility audits) and that the beams follow the game's grid rules, not
  physical optics.
- **FR-A13-623**: The checklist MUST list the accessibility facts proved so far (labels and values, native alternatives
  to every gesture, spoken board and hints, colour plus sign with contrast, Reduce Motion and Reduce Flashing) and the
  audits pending for the device campaign.

**Interface and build (story 4)**

- **FR-A13-630**: Interface tests on iOS 27 MUST cover choosing a level, solving level 1 by select and turn, undo, a hint
  and Describe, each under 60 s, in their own chunk.
- **FR-A13-631**: The release build checks MUST pass.
- **FR-A13-632**: The experience's package tests MUST pass on iOS 27.

### Key Entities

- **Release checklist row**: item, area, status (verified, pending-campaign-ii, owner-action), evidence or steps.
- **Store claim**: text and its proving test.
- **Sample progress file**: form (valid, newer, damaged, truncated) and its expected answer.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A13-601**: 0 network, tracking, sensor or permission uses in the experience's sources; release checks pass.
- **SC-A13-602**: 4 of 4 sample progress files answered as specified, refused ones byte-identical; a forced drawing
  failure leaves the progress file byte-identical and the reopen draws.
- **SC-A13-603**: 100 % of store claims have an existing proving test; 0 refused or measured claims.
- **SC-A13-604**: 100 % of checklist rows carry a status with evidence or owner steps; every device row names its
  campaign row.
- **SC-A13-605**: The interface journeys pass on iOS 27 (each under 60 s); the runner passes; every package test runs in
  under 10 s.

## Assumptions

- A13-P00–P05 built and proved the experience; the release-document and copy checks, the release build checks and the
  interface test chunks exist (A11-P06 and A12-P06 use them).

## Traceability

| Source | Requirement |
|---|---|
| Phase 06: privacy and permission strings | FR-A13-601–604 |
| Phase 06: local data migration, crash recovery | FR-A13-610–612 |
| Phase 06: App Store asset and credit review, no fabricated measured claims | FR-A13-620–622 |
| Phase 06: accessibility | FR-A13-623, 630 |
| Phase 06: CPU/GPU/device tests, build and archive instructions | FR-A13-622, 631, 632 (device rows pending) |

## Negative Requirements

- No per-app store listing, pricing or dossier; no measured performance figures; no physics or accuracy claims; no
  network, accounts or tracking; no device installs before ImplementationLock-100.
