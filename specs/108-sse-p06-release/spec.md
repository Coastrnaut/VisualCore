# Feature Specification: Solar System Explorer — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `108-sse-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A14-P06 (legacy ledger) · ID namespace FR-A14-6##, SC-A14-6##, T-A14-6##

**Input**: User description: archived manual `apps/14-solar-system-explorer.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; every required
  automated test has attached results and every device row is listed (pending until the device campaign); unsupported
  promised features are removed from the interface and the store copy.
- **One app (ADR-0009):** the per-app store listing, pricing and release dossier are inapplicable; Solar System
  Explorer's store text is an input to the one app's listing. Quality, privacy, accessibility and regression gates
  stand.
- **Device tasks** are tagged {device} and run only after ImplementationLock-100; owner-only steps (signing, upload,
  App Store Connect) are recorded as BLOCKED_OWNER_ACTION.
- **Owner rulings:** short tests; audits in the device campaign; iOS 27 at phase gates; reference regression and iOS 26
  at X-A14; interface tests under 60 s each.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time, as for A13-P06. Facts checked
in code: `check_experience_release.py` reads `docs/apps/<slug>/release.json` (schema 1: `experience`, `requiredDocs`,
`checklist`, `copyCheck` with `text`, `swift`, `allow`) and accepts the statuses `verified`, `pending-campaign-ii` and
`owner-action`; `release_check.py` derives `experience-release-<code>` and `copy-claims-<code>` from that file and runs
interface chunks by name (`u2` is Light Maze's, serial; `v2` is free); `ViewStore` answers `missing`, `refused(…)`
(damaged, newer-version, out-of-range, oversized) and `unreadable` and never writes on load; the presenter has no
failure seam yet (Light Maze's `failNextDraw` is the model); the registry passes stored schema examples to
`ExperienceRegistration(examples:)` for migration checks (`MazeCore.schemaOneExample()`), and `SolarCore` has none yet;
the experience's sources import only Foundation, SwiftUI, UIKit and VisualCore modules; the a14 registration declares no
permission; control identifiers are `experience.a14.solar-system-explorer.<name>` (`body`, `previous-body`, `next-body`,
`date`, `play-pause`, `rate`, `now`, `tour`, `tour-next`, `tour-pause`, `tour-stop`, `scale`, `save-view`,
`restore-view`, `view-message`, `about-model`, `status`, `message`, …).

- Q: Which statuses does the release checklist use? → A: The checker's: `verified` (with evidence),
  `pending-campaign-ii` (device rows, naming the device-campaign row) and `owner-action` (with the owner's steps).
- Q: Which words are refused in the store text and interface copy? → A: An experience scan over the store text and the
  interface Swift (controls and presenter) refuses ephemeris (except in "not an ephemeris"), real-time, live sky,
  telescope, precise, precision, accurate, accuracy, exact positions, fps, frames per second, battery and a millisecond
  figure (whole words, case-insensitive), alongside the shared copy check; every test named in the store claim table
  must exist.
- Q: What does the source scan refuse? → A: In `Packages/ExperiencesCreative/SolarSystemExplorer`: `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `ASIdentifierManager`, `AppTrackingTransparency`, `UIScreen.main.brightness` and `isIdleTimerDisabled`.
- Q: Which interface journeys run, and how? → A: A new serial chunk `v2` with `SSEViewUITests` (choose Earth from the
  Body menu — the status names Earth; Later 1 year then Play and Pause — the date changes; switch Scale to True relative —
  the legend says "to one scale") and `SSETourUITests` (start the Inner planets tour — the status names the Sun and the
  overlay is present; Next stop — Mercury; Stop tour; Save view, choose Mars, Restore view — Earth again), launched
  through `SSESupport` like `LMSupport`; each test under 60 s.
- Q: How are crash recovery, sample files and old sessions proved? → A: A test-only `failNextDraw` seam in the presenter;
  a test saves a view in a temporary storage, starts a tour, sets the seam, draws so the session fails, checks
  `view.json` byte-identical, opens a new session and draws. Four committed samples (`view-valid`, `-newer`, `-damaged`,
  `-oversized`) under the experience's test fixtures answered by `ViewStore` and byte-identical afterwards. Stored
  examples `SolarCore.schemaOneExample()`, `schemaTwoExample()` and `schemaThreeExample()` (envelopes of schemas 1–3 with
  the digest their migration must give), passed to the registry's candidate registration and tested.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

The owner can show that Solar System Explorer asks for no permission, sends nothing anywhere, stores only its saved
view and session state in the app, and credits every source it uses.

**Why this priority**: privacy and licensing gates of the release.

**Independent Test**: scan the sources; read the privacy and credits note; run the privacy-manifest and no-tracking
checks.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** scanned, **Then** no network, tracking, sensor or recording use is found
   and no usage string is added.
2. **Given** the note, **Then** it states what is stored, where, how to delete it, and credits NASA, the IAU and JPL
   data with their licenses.

---

### User Story 2 - Saved data and failures are handled (Priority: P1)

A damaged, newer or oversized saved view is refused without harm; older saved sessions open; a drawing failure fails
the session safely and a reopen draws normally with the saved view untouched.

**Why this priority**: local data migration and crash recovery gates.

**Independent Test**: load committed sample files of each form; force a drawing failure; reopen.

**Acceptance Scenarios**:

1. **Given** sample saved views (valid, newer, damaged, oversized), **When** restored, **Then** each loads or is refused
   as specified and the file stays byte-identical.
2. **Given** a forced drawing failure, **Then** the session fails, the saved view file is unchanged, and a new session
   draws.
3. **Given** saved sessions of schemas 1 to 3, **Then** each opens in schema 4.

---

### User Story 3 - Truthful release documents (Priority: P1)

The owner has a release checklist with an artifact inventory, store text whose every claim names a proving test, the
device plan, known limitations and build instructions; no copy claims precision or measured performance.

**Why this priority**: the phase's release gate and the no-fabricated-claims rule.

**Independent Test**: run the release-document and copy-claim checks.

**Acceptance Scenarios**:

1. **Given** the release documents, **When** checked, **Then** the release-document check passes and every store claim
   has a test.
2. **Given** the store text and interface copy, **Then** no word implies precision, an ephemeris or measured performance.

---

### User Story 4 - The interface works end to end (Priority: P2)

Interface tests in the app open Solar System Explorer, focus a planet, step and play the date, start and stop a tour,
switch the scale and restore a saved view, each in under 60 seconds.

**Why this priority**: the release's interface regression.

**Independent Test**: run the interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** the app on iOS 27, **When** the interface tests run, **Then** each passes in under 60 seconds.

### Edge Cases

- **No saved view yet:** restoring says so and changes nothing.
- **A saved view with a date outside the range:** refused as out of range.
- **A drawing failure during a tour:** the saved view is unchanged and a reopened session draws normally.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A14-601**: Solar System Explorer MUST request no permission and add no usage string.
- **FR-A14-602**: The experience's sources MUST contain none of the scanned network, tracking, sensor, recording,
  brightness or idle-timer uses.
- **FR-A14-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A14-604**: A privacy and credits note MUST state what is stored and where, that nothing is sent, how to delete it,
  and credit every bundled data source with its license.
- **FR-A14-610**: Committed sample saved views of each form MUST load or be refused as specified, refused files staying
  byte-identical.
- **FR-A14-611**: A forced drawing failure (test-only seam) MUST fail the session with the saved view unchanged, and a
  reopen MUST draw normally.
- **FR-A14-612**: Saved sessions of schemas 1 to 3 MUST open in schema 4 (stored examples).
- **FR-A14-620**: A release checklist with an artifact inventory, store text with a claim → test table, the device plan
  and a release configuration MUST exist and pass the release-document check; the checklist's `owner-action` rows are
  the signing set-up, the archive and its upload (steps from `docs/release/build-and-archive.md`), recorded as
  BLOCKED_OWNER_ACTION and never done by the agent; its `pending-campaign-ii` rows name the device-campaign rows
  SSE-D1 to SSE-D6.
- **FR-A14-621**: The shared copy-claim check MUST pass on the store text and the interface copy, and the experience's
  own scan MUST refuse precision, ephemeris, real-time-sky and measured-performance words.
- **FR-A14-622**: Known limitations MUST list the device-only items and the model's approximation and range.
- **FR-A14-623**: The checklist MUST list the accessibility facts proved so far and the audits pending for devices.
- **FR-A14-630**: Interface tests on iOS 27 MUST cover focusing a planet, a date step and play, a tour start and stop, a
  scale switch and a saved-view restore, each under 60 s, in their own chunk.
- **FR-A14-631**: The release build checks MUST pass.
- **FR-A14-632**: The experience's package tests MUST pass on iOS 27.

### Key Entities

- **Release checklist row**: item, area, status (verified, pending device campaign, owner action), evidence or steps.
- **Store claim**: text and its proving test.
- **Sample saved view**: form (valid, newer, damaged, oversized) and its expected answer.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A14-601**: 0 permission requests and 0 scanned uses in the experience's sources.
- **SC-A14-602**: 100 % of sample files answer as specified and stay byte-identical when refused.
- **SC-A14-603**: The release-document and copy-claim checks pass; 100 % of store claims name a test.
- **SC-A14-604**: Every interface test passes in under 60 s on iOS 27; the release build checks pass.
- **SC-A14-605**: The runner's standard scenarios pass on iOS 27; every package test runs in under 10 s.

## Assumptions

- The experience, its review documents and the device plan of A14-P01 to A14-P05 exist; the release tools
  (`check_experience_release.py`, `check_copy_claims.py`, the release build checks) exist and discover the experience
  from its release configuration.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06: privacy and permission strings | FR-A14-601–604 |
| Phase 06: local data migration and crash recovery | FR-A14-610–612 |
| Phase 06: store asset and credit review, no fabricated claims | FR-A14-620–623 |
| Phase 06: CPU/GPU/device tests, build and archive | FR-A14-630–632, device-campaign.md |

## Negative Requirements

- No per-app listing or pricing; no measured performance claims; no device runs before ImplementationLock-100; no
  owner-only action taken (signing, upload, App Store Connect).
