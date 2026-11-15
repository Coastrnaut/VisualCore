# Feature Specification: Neon Arcade — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `080-na-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A10-P06 (legacy ledger) · ID namespace FR-A10-6##, SC-A10-6##, T-A10-6##

**Input**: User description: archived manual `apps/10-neon-arcade.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; every required
  automated test has attached results and every device row is listed (pending until the device campaign); unsupported
  promised features are removed from the interface and the store copy.
- **One app (ADR-0009):** the per-app store listing, pricing and release dossier are inapplicable; Neon Arcade's store
  text is an input to the one app's listing. Quality, privacy, accessibility and regression gates stand.
- **Device tasks** are tagged {device} and run only after ImplementationLock-100; owner-only steps (signing, upload,
  App Store Connect) are recorded as BLOCKED_OWNER_ACTION.
- **Owner rulings:** short tests; audits in the device campaign; iOS 27 at phase gates; reference regression and iOS 26
  at X-A10; interface tests under 60 s each, serial chunk.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time, as for A09-P06. Facts
checked in code: `scripts/check_experience_release.py` reads `docs/apps/<slug>/release.json` (schema 1: `experience`,
`requiredDocs`, `checklist`, `copyCheck` with `text`, `swift`, `allow`) and accepts the statuses `verified`,
`pending-campaign-ii` and `owner-action`; `scripts/release_check.py` derives `experience-release-<code>` and
`copy-claims-<code>` from that file; `Configs/copy-claims-denylist.json` is shared; `ArcadePresenter` has the
test-only `failNextDraw`; the high-score table lives in `high-scores.json` (`HighScoreStore`); Neon Arcade's sources
import no audio framework directly (sounds go through VisualCore's `SoundEffectPlayer`, ambient, no input); the
registration declares no permission; `specs/079-na-p05-balance/scan-claims.sh` already refuses benefit words in the
catalog entry and the README.

- Q: Which statuses does the release checklist use? → A: The checker's: `verified` (with evidence),
  `pending-campaign-ii` (device rows, naming the device-campaign row) and `owner-action` (with the owner steps).
- Q: How are skill and ranking claims refused without changing the shared denylist? → A: A Neon Arcade scan over the
  store text and the experience's interface Swift refuses skill, reflex, reaction time, cognitive, brain, health,
  therapy, improve your, train your, leaderboard, rank among, compete with and world record (case-insensitive, whole
  words), alongside the shared copy check; the shared denylist is not changed.
- Q: What does the source scan refuse? → A: In `Packages/ExperiencesCreative/NeonArcade`: `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `MicrophoneAudioSource`,
  `CMMotion`, `CNContact`, `ASIdentifierManager`, `AppTrackingTransparency`, `UIScreen.main.brightness` and
  `isIdleTimerDisabled`.
- Q: Which sample high-score files are committed? → A: Four files under the experience tests' `Fixtures`: a valid
  table (board version 1, three entries), a newer one (board version 2), a damaged one (not JSON) and a truncated one
  (the valid table cut in half); each is copied into a temporary storage as `high-scores.json`: the valid one is shown,
  the others are reported, and all stay byte-identical until a finished run writes a valid table (and after a reload).
- Q: Which interface journeys run, and how? → A: The serial chunk `r2` gains `NASettingsUITests` (sound and haptics
  toggles change their values; the sensitivity stepper's value changes) beside `NAArcadeUITests` (start and steer, pause
  and resume, sensitivity, best score on the title); launched as a candidate with `-vcCandidates` and
  `-openExperience a10.neon-arcade`; each test under 60 s.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A person can trust Neon Arcade: it asks for no permission, sends nothing anywhere, tracks nothing, and keeps only its
high-score table and the session state on the device; a plain note says so and credits the content.

**Why this priority**: privacy is a release gate (constitution A10: offline-first and private).

**Independent Test**: a scan of the experience's sources finds no network, tracking, advertising, sensor, recording or
permission use; the app's privacy declarations cover what it uses; the privacy and credits note matches the code.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** they are scanned, **Then** no network, tracking, advertising, location,
   camera, microphone, recording, motion or contacts use is found.
2. **Given** the app's privacy declarations, **When** they are checked, **Then** every required-reason use is covered
   and no tracking is declared.
3. **Given** the privacy and credits note, **When** it is read, **Then** it lists the stored high-score file and the
   session state, states that nothing is sent and no personal data is kept, explains how to delete them, and credits
   every bundled item and pattern with its license.

---

### User Story 2 - Damaged data never breaks the game (Priority: P1)

High-score files written by this version, by a newer version, damaged ones and half-written ones are each handled as
specified, and a drawing failure recovers without touching any saved file.

**Why this priority**: the manual's "local data migration" and "crash recovery".

**Acceptance Scenarios**:

1. **Given** committed sample high-score files (valid, newer version, damaged, truncated), **When** the game opens with
   each, **Then** the valid one is shown, the others are reported, and none is changed until a run writes a valid
   table.
2. **Given** a forced drawing failure, **When** it happens, **Then** the session shows its failure state, the high-score
   file is byte-identical, and reopening draws the game.
3. **Given** saved states of every earlier schema (1–3), **When** they are restored, **Then** each migrates.

---

### User Story 3 - Honest store copy and a complete checklist (Priority: P1)

Whoever prepares the release finds a store text that promises only what Neon Arcade does (every claim traced to a
test), no measured performance claims and no skill, reflex, cognitive or health claims, a release checklist with an
artifact inventory, a release configuration, the device-campaign plan and the known limitations.

**Acceptance Scenarios**:

1. **Given** the store text, **When** it is checked, **Then** every claim has a proving test and no measured or benefit
   claim appears.
2. **Given** the release checklist, **When** it is read, **Then** every item has a status (`verified`,
   `pending-campaign-ii`, `owner-action`) and evidence or owner steps.
3. **Given** a missing release document, **When** the check runs, **Then** it fails and names the document.

---

### User Story 4 - The game works in the real app (Priority: P2)

Neon Arcade's main journeys work through the app's interface on the iOS 27 phone simulator — start, steer, pause,
settings (sound, haptics, sensitivity) and the best-score text — and the release build and its checks pass. Reaching
game over through the interface would take minutes of play, so the game-over screen and its table are proved by the
session tests (A10-P04) rather than by an interface test.

**Acceptance Scenarios**:

1. **Given** the app with Neon Arcade, **When** the interface tests run, **Then** starting, steering, pausing, the
   sound, haptics and sensitivity settings and the best-score text work by their controls.
2. **Given** a release build, **When** its checks run, **Then** the build, symbols, privacy manifest, no-tracking,
   licenses and usage descriptions checks pass.

### Edge Cases

- **A device row without results:** stays pending; no measured value is claimed.
- **An owner step not done:** recorded as BLOCKED_OWNER_ACTION with the exact steps; work continues.
- **A store claim without a test:** the copy check fails.
- **A high-score file from a future version:** reported and never rewritten until a valid run replaces it.
- **Sound playback under the silent switch:** silent (ambient), stated in the privacy note and the checklist.

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**

- **FR-A10-601**: Neon Arcade MUST request no permission and add no usage string.
- **FR-A10-602**: The experience's sources MUST contain none of the scanned network, tracking, sensor, recording,
  brightness or idle-timer uses.
- **FR-A10-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A10-604**: A privacy and credits note MUST state what is stored and where, that nothing is sent, how to delete
  it, and credit every bundled item and pattern with author and license.

**Data and recovery (story 2)**

- **FR-A10-610**: Committed sample high-score files of each form MUST load or be reported as specified, with refused
  files byte-identical.
- **FR-A10-611**: A forced drawing failure (test-only seam) MUST put the session into its failure state with the
  high-score file byte-identical, and a reopen MUST draw normally.
- **FR-A10-612**: Saved states of schemas 1–3 MUST restore (stored examples), re-run here.

**Copy and release documents (story 3)**

- **FR-A10-620**: A release checklist with an artifact inventory, a store text input with a claim → test table, the
  device-campaign plan and a release configuration MUST exist and pass the release-document check.
- **FR-A10-621**: The shared copy-claim check MUST pass on the store text and the interface copy, and Neon Arcade's own
  scan MUST refuse skill, reflex, cognitive, health and competitive-ranking words.
- **FR-A10-622**: Known limitations MUST list the device-only items (frame pacing, thermals, glow readability on a real
  screen, audio routes, VoiceOver pass).
- **FR-A10-623**: The checklist MUST list the accessibility facts proved so far (labels, Dynamic Type, announcements,
  native alternatives, Reduce Motion, reduced flashing) and the audits pending for the device campaign.

**Interface and build (story 4)**

- **FR-A10-630**: Interface tests on iOS 27 MUST cover start, steer, pause, sound, haptics and sensitivity settings and
  the best-score text, each under 60 s.
- **FR-A10-631**: The release build checks MUST pass.
- **FR-A10-632**: The experience's package tests MUST pass on iOS 27.

**Owner and device**

- **FR-A10-640**: Signing, upload and App Store Connect entry of the store text MUST be recorded as owner actions.
- **FR-A10-641**: The device campaign's measurements and audits MUST be listed as {device} tasks.

### Key Entities

- **Release configuration**: experience id, required documents, checklist, copy-check sources.
- **Release checklist row**: item, area, status, evidence.
- **Sample high-score file**: form (valid, newer, damaged, truncated).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A10-601**: The source scan finds 0 forbidden uses; the release checks report 0 tracking declarations.
- **SC-A10-602**: 100 % of sample files behave as specified and 100 % of refused files stay byte-identical.
- **SC-A10-603**: The release-document, copy-claim and Neon Arcade scans pass with 0 problems; every store claim names an
  existing test.
- **SC-A10-604**: The interface chunk passes with every test under 60 s.
- **SC-A10-605**: The package tests and the runner's nine scenarios pass on iOS 27.

## Assumptions

- The device campaign, owner steps and the reference regression (X-A10) are outside this phase's automated evidence.

## Out of Scope

- Pricing, screenshots, a per-app listing, TestFlight, submission.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06 gates (checklist, artifact inventory, attached test results, device rows) | FR-A10-620, 623, 630–632, 641 |
| Phase 06 gate "unsupported promised features removed from interface and copy" | FR-A10-621 |
| Constitution A10 offline-first and private; truthful claims | FR-A10-601–604, 621 |
| Manual §13 privacy obligations | FR-A10-601–604 |
| Manual §11 fixture 4 (high score not corrupted) re-run on samples | FR-A10-610, 611 |

## Negative Requirements

- No network, accounts, analytics, advertising or tracking; no permission; no personal data; no skill, reflex,
  cognitive or health claims; no measured numbers without device evidence; no submission or signing by the agent.
