# Feature Specification: Digital Aquarium — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `073-da-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A09-P06 (legacy ledger) · ID namespace FR-A09-6##, SC-A09-6##, T-A09-6##

**Input**: User description: archived manual `apps/09-digital-aquarium.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; every required
  automated test has attached results and every device row is listed (pending until the device campaign); unsupported
  promised features are removed from the interface and the store copy.
- **One app (ADR-0009):** the per-app store listing, pricing and release dossier are inapplicable; Digital Aquarium's
  store text is an input to the one app's listing. Quality, privacy, accessibility and regression gates stand.
- **Device tasks** are tagged {device} and run only after ImplementationLock-100; owner-only steps (signing, upload,
  App Store Connect) are recorded as BLOCKED_OWNER_ACTION.
- **Owner rulings:** short tests; audits in the device campaign; iOS 27 at phase gates; interface tests under 60 s each,
  run serially if parallel clones starve the test runner.

## Clarifications

### Session 2026-11-14

Facts checked in code: `scripts/check_experience_release.py` reads `docs/apps/<slug>/release.json` (schema 1:
`experience`, `requiredDocs`, `checklist`, `copyCheck` with `text`, `swift`, `allow`) and accepts checklist statuses
`verified`, `pending-campaign-ii` and `owner-action`; `scripts/release_check.py` derives the steps
`experience-release-<code>` and `copy-claims-<code>` from each such file; `Configs/copy-claims-denylist.json` is shared
by every experience (measured patterns, unmeasured quality words, features an experience does not have);
`AquariumPresenter` has the test-only `failNextDraw` seam; Digital Aquarium declares no permission in its registration.

- Q: Which statuses does the release checklist use? → A: The checker's: `verified` (with evidence), `pending-campaign-ii`
  (device rows, with the device-campaign row named) and `owner-action` (with the owner steps); "device" and
  "blocked-owner" in this spec mean those two.
- Q: How are realism and animal-care claims refused without changing the shared denylist? → A: A Digital Aquarium scan
  step over the store text and the experience's interface Swift refuses the words realistic, lifelike, real fish,
  pet, care for, healthy, hungry, starve, nutrition and therapy (case-insensitive, whole words), alongside the shared
  copy check; the shared denylist is not changed, so no other experience is affected.
- Q: What does the source scan refuse? → A: In `Packages/ExperiencesCreative/DigitalAquarium`: `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudio`, `CMMotion`, `CNContact`, `ASIdentifierManager`,
  `AppTrackingTransparency`, `UIScreen.main.brightness` and `isIdleTimerDisabled`.
- Q: Which sample saved files are committed? → A: Four files under the experience tests' `Fixtures`: a valid
  configuration (format 1), a newer-format file (format 2), a damaged file (not JSON) and a valid configuration whose
  file name names another id; copied into a temporary storage, the valid one is listed, the others counted (two
  unreadable, one newer), all byte-identical after a reload and a save.
- Q: Which interface journeys run, and how? → A: A serial chunk `q2` with `DAAquariumUITests` (feed by the Feed button,
  add, move right and remove a decoration, switch to Kelp, turn ambient on — checked through the canvas description and
  the controls' values) and `DALibraryUITests` (save an aquarium under a name, change the habitat, open the saved one);
  launched as a candidate with `-vcCandidates` and `-openExperience a09.digital-aquarium`; each test under 60 s.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A person can trust the aquarium: it asks for no permission, sends nothing anywhere, tracks nothing, and keeps only
their saved aquariums and the session state on the device; a plain note says so and credits the content.

**Why this priority**: privacy is a release gate.

**Independent Test**: a scan of the experience's sources finds no network, tracking, advertising, sensor or
permission use; the app's privacy declarations cover what it uses; the privacy and credits note exists and matches the
code.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** they are scanned, **Then** no network, tracking, advertising, location,
   camera, microphone, motion or contacts use is found.
2. **Given** the app's privacy declarations, **When** they are checked, **Then** every required-reason use is covered
   and no tracking is declared.
3. **Given** the privacy and credits note, **When** it is read, **Then** it lists the stored files and where they live,
   states that nothing is sent, and credits every bundled item with its license.

---

### User Story 2 - Damaged data never breaks the aquarium (Priority: P1)

Saved aquariums written by this version, files of a newer version, damaged files and files with a mismatched name are
each handled as specified, and a drawing failure recovers without touching any saved file.

**Why this priority**: the manual's "local data migration" and "crash recovery".

**Independent Test**: committed sample files of each form load or are refused as specified, refused files stay
byte-identical, and a forced drawing failure leaves every file unchanged and a reopen draws normally.

**Acceptance Scenarios**:

1. **Given** committed sample files (valid, newer format, damaged, mismatched name), **When** the library loads them,
   **Then** the valid one is listed and the others are counted, and none is changed.
2. **Given** a forced drawing failure, **When** it happens, **Then** the session shows its failure state, saved files
   are byte-identical, and reopening draws the aquarium.
3. **Given** saved states of every earlier format (Phases 01–04), **When** they are restored, **Then** each migrates.

---

### User Story 3 - Honest store copy and a complete checklist (Priority: P1)

Whoever prepares the release finds a store text that promises only what the aquarium does (every claim traced to a
test), no measured performance claims and no realism or animal-care claims, a release checklist with an artifact
inventory, a release configuration, the device-campaign plan and the known limitations.

**Why this priority**: the manual's release-checklist and copy gates.

**Independent Test**: the release-document check and the copy-claim check pass; every store claim names its proving
test; the checklist lists every artifact with a status.

**Acceptance Scenarios**:

1. **Given** the store text, **When** it is checked, **Then** every claim has a proving test and no measured, realism or
   care claim appears.
2. **Given** the release checklist, **When** it is read, **Then** every item has a status (`verified`,
   `pending-campaign-ii`, `owner-action`) and evidence or owner steps.
3. **Given** a missing release document, **When** the check runs, **Then** it fails and names the document.

---

### User Story 4 - The aquarium works in the real app (Priority: P2)

The aquarium's main journeys work through the app's interface on the iOS 27 phone simulator: feeding, decorating,
ambient mode and saved aquariums; the release build and its checks pass.

**Why this priority**: interface and build gates.

**Independent Test**: an interface test chunk passes with each test under 60 s; the release build checks pass.

**Acceptance Scenarios**:

1. **Given** the app with Digital Aquarium, **When** the interface tests run, **Then** feeding, adding, moving and
   removing decor, switching habitat, ambient mode and saving and opening an aquarium work by their controls.
2. **Given** a release build, **When** its checks run, **Then** the build, symbols, privacy manifest, no-tracking,
   licenses and usage descriptions checks pass.

### Edge Cases

- **A device row without results:** stays `pending` (never `pass`); no measured value is claimed.
- **An owner step not done:** recorded as BLOCKED_OWNER_ACTION with the exact steps; work continues.
- **A store claim without a test:** the copy check fails.
- **A file of a future version:** counted as newer and never rewritten.

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**
- **FR-A09-601**: Digital Aquarium MUST request no permission and add no usage string.
- **FR-A09-602**: The experience's sources MUST contain none of the scanned network, tracking, sensor, brightness or
  idle-timer uses (Clarifications Q3).
- **FR-A09-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A09-604**: A privacy and credits note MUST state what is stored and where, that nothing is sent, and credit every
  bundled item with author and license.

**Data and recovery (story 2)**
- **FR-A09-610**: Committed saved-aquarium sample files of each form MUST load or be counted as specified, with refused
  files byte-identical.
- **FR-A09-611**: A forced drawing failure (test-only seam) MUST put the session into its failure state with saved files
  byte-identical, and a reopen MUST draw normally.
- **FR-A09-612**: Saved states of schemas 1–3 MUST restore (stored examples), already proved per phase and re-run here.

**Copy and release documents (story 3)**
- **FR-A09-620**: A release checklist with an artifact inventory, a store text input with a traceability table, the
  device-campaign plan and a release configuration MUST exist and pass the release-document check.
- **FR-A09-621**: The shared copy-claim check MUST pass on the store text and the interface copy, and the Digital Aquarium
  scan MUST find none of the realism and animal-care words (Clarifications Q2).
- **FR-A09-622**: Known limitations MUST list Digital Aquarium's device-only items; the device-campaign plan names each
  measurement with its device and pass criterion, results pending; the release checklist marks them
  `pending-campaign-ii`.
- **FR-A09-623**: Accessibility MUST be covered in the release checklist: the automated proofs (canvas description and
  announcements, Reduce Motion halving, labelled controls for every gesture action) as `verified` with their tests, and
  the device audits (VoiceOver, Dynamic Type, Reduce Motion, contrast, system accessibility audits) as
  `pending-campaign-ii` rows naming the device-campaign rows.

**Interface and builds (story 4)**
- **FR-A09-630**: An interface test chunk for Digital Aquarium MUST pass on the iOS 27 phone simulator, each test < 60 s.
- **FR-A09-631**: The release build checks (release build, symbols, privacy manifest, no tracking, licenses, usage
  descriptions) MUST pass.
- **FR-A09-632**: Every Digital Aquarium suite MUST pass on iOS 27; every package test MUST finish in under 10 seconds.

**Owner and device**
- **FR-A09-640**: Signing, archive upload and the store entry MUST be recorded as BLOCKED_OWNER_ACTION with steps.
- **FR-A09-641**: The device campaign's measurements and audits MUST be a {device} task, run only after
  ImplementationLock-100.

### Key Entities

- **Release checklist item**: area, status (`verified`, `pending-campaign-ii`, `owner-action`), evidence or owner steps.
- **Store claim**: a sentence of the store text and the test that proves it.
- **Sample saved file**: one committed file per form (valid, newer, damaged, mismatched name).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A09-601**: 0 forbidden uses in the source scan; the privacy manifest and usage-description checks pass.
- **SC-A09-602**: 100 % of sample files behave as specified and refused files are byte-identical; the forced failure
  leaves 100 % of files unchanged.
- **SC-A09-603**: 100 % of store claims have a proving test; 0 forbidden claims; the release-document check passes and
  fails on a missing document.
- **SC-A09-604**: Every interface test passes in under 60 s; the release build checks pass.
- **SC-A09-605**: Every package test finishes in under 10 seconds.

## Assumptions

- The app's privacy manifest and usage strings are shared by all experiences; this phase only checks that Digital
  Aquarium needs nothing new.

## Out of Scope

- Per-app store listing, pricing, screenshots and a separate dossier (one app); device measurements (campaign).

## Traceability

| Source | Requirement |
|---|---|
| Manual P06 deliverable (privacy, accessibility, credits, migration, device tests, crash recovery, build) | FR-A09-601–641 |
| Manual P06 gate: checklist and artifact inventory | FR-A09-620; story 3 |
| Manual P06 gate: tests with attached results | FR-A09-622, 630–632, 641 |
| Manual P06 gate: unsupported promises removed | FR-A09-621 |

## Negative Requirements

- No measured performance claim; no realism or animal-care claim; no new permission; no network; no owner step done by
  the agent.
