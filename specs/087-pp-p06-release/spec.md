# Feature Specification: Physics Playground — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `087-pp-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A11-P06 (legacy ledger) · ID namespace FR-A11-6##, SC-A11-6##, T-A11-6##

**Input**: User description: archived manual `apps/11-physics-playground.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; every required
  automated test has attached results and every device row is listed (pending until the device campaign); unsupported
  promised features are removed from the interface and the store copy.
- **One app (ADR-0009):** the per-app store listing, pricing and release dossier are inapplicable; Physics Playground's
  store text is an input to the one app's listing. Quality, privacy, accessibility and regression gates stand.
- **Device tasks** are tagged {device} and run only after ImplementationLock-100; owner-only steps (signing, upload,
  App Store Connect) are recorded as BLOCKED_OWNER_ACTION.
- **Owner rulings:** short tests; audits in the device campaign; iOS 27 at phase gates; reference regression and iOS 26
  at X-A11; interface tests under 60 s each, serial chunk.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time, as for A10-P06. Facts
checked in code: `scripts/check_experience_release.py` reads `docs/apps/<slug>/release.json` (schema 1: `experience`,
`requiredDocs`, `checklist`, `copyCheck` with `text`, `swift`, `allow`) and accepts the statuses `verified`,
`pending-campaign-ii` and `owner-action`; `scripts/release_check.py` derives `experience-release-<code>` and
`copy-claims-<code>` from that file and runs interface chunks (serial ones listed in `SERIAL_CHUNKS`); `PlaygroundPresenter`
has the test-only `failNextDraw`; experiments live in `experiment-<slot>.json` (`ExperimentStore`) with four committed
sample files from A11-P04; Physics Playground's sources import no audio, motion or network framework; the registration
declares no permission; Neon Arcade's UI tests open a candidate with `-vcCandidates` and `-openExperience`;
`specs/086-pp-p05-stability/scan-claims.sh` already refuses accuracy and similar words in the catalog entry and README.

- Q: Which statuses does the release checklist use? → A: The checker's: `verified` (with evidence),
  `pending-campaign-ii` (device rows, naming the device-campaign row) and `owner-action` (with the owner steps).
- Q: How are refused claims checked in the store text and interface copy? → A: A Physics Playground scan over the store
  text and the experience's interface Swift refuses accurate, accuracy, precise, precision, engineering-grade, safety,
  predict, prediction, teaches, learning outcome and improves understanding (case-insensitive, whole words), alongside
  the shared copy check; the shared denylist is not changed; the interface note "Educational approximation" is allowed.
- Q: What does the source scan refuse? → A: In `Packages/ExperiencesCreative/PhysicsPlayground`: `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `ASIdentifierManager`, `AppTrackingTransparency`, `UIScreen.main.brightness` and `isIdleTimerDisabled`.
- Q: Which interface journeys run, and how? → A: A new serial chunk `s2` with `PPWorldUITests` (drop a circle; pause,
  single step and time scale; force arrows toggle) and `PPExperimentUITests` (open the pendulum preset; start and stop
  the "Controlling time" tutorial), launched as a candidate with `-vcCandidates` and `-openExperience
  a11.physics-playground` through `PPSupport`; identifiers `experience.a11.physics-playground.<name>`; each test under
  60 s.
- Q: How is crash recovery proved? → A: A test saves an experiment to slot 0 in a temporary storage, sets `failNextDraw`,
  draws a frame so the session enters its failure state, checks `experiment-0.json` is byte-identical, opens a new
  session and draws; the four committed samples are re-run (valid opens; newer, damaged and truncated refused and
  byte-identical); the schema-1…4 examples restore.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A person can trust Physics Playground: it asks for no permission, sends nothing anywhere, tracks nothing, and keeps only
its saved experiments and the session state on the device; a plain note says so and credits the content.

**Why this priority**: privacy is a release gate (constitution A11: offline-first and private).

**Independent Test**: a scan of the experience's sources finds no network, tracking, advertising, sensor, recording or
permission use; the app's privacy declarations cover what it uses; the privacy and credits note matches the code.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** they are scanned, **Then** no network, tracking, advertising, location,
   camera, microphone, recording, motion or contacts use is found.
2. **Given** the app's privacy declarations, **When** they are checked, **Then** every required-reason use is covered
   and no tracking is declared.
3. **Given** the privacy and credits note, **When** it is read, **Then** it lists the saved experiment files and the
   session state, states that nothing is sent and no personal data is kept, explains how to delete them, and credits
   every bundled material, preset and tutorial with its license.

---

### User Story 2 - Damaged data never breaks the playground (Priority: P1)

Saved experiment files written by this version, by a newer version, damaged ones and half-written ones are each handled
as specified, older saved states of every schema restore, and a drawing failure recovers without touching any saved
file.

**Why this priority**: the manual's "local data migration" and "crash recovery".

**Acceptance Scenarios**:

1. **Given** committed sample experiment files (valid, newer version, damaged, truncated), **When** each is opened,
   **Then** the valid one opens, the others are refused, and none is changed.
2. **Given** a forced drawing failure, **When** it happens, **Then** the session shows its failure state, the saved
   experiment files are byte-identical, and reopening draws the world.
3. **Given** saved states of every earlier schema (1–4), **When** they are restored, **Then** each migrates.

---

### User Story 3 - Honest store copy and a complete checklist (Priority: P1)

Whoever prepares the release finds a store text that promises only what Physics Playground does (every claim traced to
a test), no measured performance claims and no accuracy, safety, prediction or learning-outcome claims, a release
checklist with an artifact inventory, a release configuration, the device-campaign plan and the known limitations.

**Acceptance Scenarios**:

1. **Given** the store text, **When** it is checked, **Then** every claim has a proving test and no measured or refused
   claim appears.
2. **Given** the release checklist, **When** it is read, **Then** every item has a status (`verified`,
   `pending-campaign-ii`, `owner-action`) and evidence or owner steps.
3. **Given** a missing release document, **When** the check runs, **Then** it fails and names the document.

---

### User Story 4 - The playground works in the real app (Priority: P2)

Physics Playground's main journeys work through the app's interface on the iOS 27 phone simulator — dropping a body,
pause, single step and time scale, opening a preset, turning on force arrows and starting a tutorial — and the release
build and its checks pass.

**Acceptance Scenarios**:

1. **Given** the app with Physics Playground, **When** the interface tests run, **Then** those journeys work by their
   controls, each test under 60 s.
2. **Given** a release build, **When** its checks run, **Then** the build, symbols, privacy manifest, no-tracking,
   licenses and usage descriptions checks pass.

### Edge Cases

- **A device row without results:** stays pending; no measured value is claimed.
- **An owner step not done:** recorded as BLOCKED_OWNER_ACTION with the exact steps; work continues.
- **A store claim without a test:** the copy check fails.
- **An experiment file from a future version:** refused and never rewritten until the person saves over it.
- **Gestures in interface tests:** canvas gestures are covered by the presenter's gesture tests; the interface tests use
  the native controls (every gesture has one).

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**

- **FR-A11-601**: Physics Playground MUST request no permission and add no usage string.
- **FR-A11-602**: The experience's sources MUST contain none of the scanned network, tracking, sensor, recording,
  brightness or idle-timer uses.
- **FR-A11-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A11-604**: A privacy and credits note MUST state what is stored and where, that nothing is sent, how to delete
  it, and credit every bundled material, preset and tutorial with author and license.

**Data and recovery (story 2)**

- **FR-A11-610**: Committed sample experiment files of each form MUST open or be refused as specified, with refused files
  byte-identical (re-run here).
- **FR-A11-611**: A forced drawing failure (test-only seam) MUST put the session into its failure state with the saved
  files byte-identical, and a reopen MUST draw normally.
- **FR-A11-612**: Saved states of schemas 1–4 MUST restore (stored examples), re-run here.

**Copy and release documents (story 3)**

- **FR-A11-620**: A release checklist with an artifact inventory, a store text input with a claim → test table, the
  device-campaign plan and a release configuration MUST exist and pass the release-document check.
- **FR-A11-621**: The shared copy-claim check MUST pass on the store text and the interface copy, and Physics
  Playground's own scan MUST refuse accuracy, safety, prediction and learning-outcome words.
- **FR-A11-622**: Known limitations MUST list the device-only items (frame pacing, thermals, touch latency, VoiceOver)
  and the educational-approximation nature of the numbers.
- **FR-A11-623**: The checklist MUST list the accessibility facts proved so far (labels and values, native alternatives
  to every gesture, spoken description and tutorial steps, Reduce Motion) and the audits pending for the device campaign.

**Interface and build (story 4)**

- **FR-A11-630**: Interface tests on iOS 27 MUST cover dropping a body, pause, single step, time scale, opening a preset,
  force arrows and starting a tutorial, each under 60 s, in their own serial chunk.
- **FR-A11-631**: The release build checks MUST pass.
- **FR-A11-632**: The experience's package tests MUST pass on iOS 27.

**Owner and device**

- **FR-A11-640**: Signing, upload and App Store Connect entry of the store text MUST be recorded as owner actions.
- **FR-A11-641**: The device campaign's measurements and audits MUST be listed as {device} tasks.

### Key Entities

- **Release configuration**: experience id, required documents, checklist, copy-check sources.
- **Release checklist row**: item, area, status, evidence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A11-601**: The source scan finds 0 forbidden uses; the release checks report 0 tracking declarations.
- **SC-A11-602**: 100 % of sample files behave as specified and 100 % of refused files stay byte-identical.
- **SC-A11-603**: The release-document, copy-claim and Physics Playground scans pass with 0 problems; every store claim
  names an existing test.
- **SC-A11-604**: The interface chunk passes with every test under 60 s.
- **SC-A11-605**: The package tests and the runner's nine scenarios pass on iOS 27.

## Assumptions

- The device campaign, owner steps and the reference regression (X-A11) are outside this phase's automated evidence.

## Out of Scope

- Pricing, screenshots, a per-app listing, TestFlight, submission.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06 deliverable (privacy, accessibility, credits, migration, tests, crash recovery, build instructions) | FR-A11-601–641 |
| Phase 06 gate "unsupported promised features removed" | FR-A11-621 |
| Constitution A11 offline-first, private, truthful claims, licenses | FR-A11-601–604, 621 |
| Manual §13 obligations (licenses, privacy) | FR-A11-604 |

## Negative Requirements

- No network, accounts, analytics, advertising or tracking; no permission; no personal data; no accuracy, safety,
  prediction or learning-outcome claims; no measured numbers without device evidence; no submission or signing by the
  agent.
