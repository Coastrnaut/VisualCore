# Feature Specification: Tiny Worlds — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `094-tw-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A12-P06 (legacy ledger) · ID namespace FR-A12-6##, SC-A12-6##, T-A12-6##

**Input**: User description: archived manual `apps/12-tiny-worlds.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; every required
  automated test has attached results and every device row is listed (pending until the device campaign); unsupported
  promised features are removed from the interface and the store copy.
- **One app (ADR-0009):** the per-app store listing, pricing and release dossier are inapplicable; Tiny Worlds' store
  text is an input to the one app's listing. Quality, privacy, accessibility and regression gates stand.
- **Device tasks** are tagged {device} and run only after ImplementationLock-100; owner-only steps (signing, upload,
  App Store Connect) are recorded as BLOCKED_OWNER_ACTION.
- **Owner rulings:** short tests; audits in the device campaign; iOS 27 at phase gates; reference regression and iOS 26
  at X-A12; interface tests under 60 s each.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time, as for A11-P06. Facts
checked in code: `scripts/check_experience_release.py` reads `docs/apps/<slug>/release.json` (schema 1: `experience`,
`requiredDocs`, `checklist`, `copyCheck` with `text`, `swift`, `allow`) and accepts the statuses `verified`,
`pending-campaign-ii` and `owner-action`; `scripts/release_check.py` derives `experience-release-<code>` and
`copy-claims-<code>` from that file and runs interface chunks (serial ones in `SERIAL_CHUNKS`; `s2` is Physics
Playground's, so Tiny Worlds takes `t2`); `WorldStore` refuses `empty-slot`, `invalid-slot`, `damaged`,
`newer-version`, `too-large` and storage errors and writes `world-<slot>.json` and `world-<slot>.png` atomically;
`WorldsPresenter` has no test-only failure seam yet (Physics Playground's `failNextDraw` is the model); there are no
committed sample world files yet; Tiny Worlds' sources import only Foundation, SwiftUI, UIKit and VisualCore modules;
the a12 registration declares no permission; the controls carry identifiers `experience.a12.tiny-worlds.<name>`
(`open-pack`, `zoom-in`, `turn-left`, `place`, `light-azimuth`, `slot-<n>-save`, …); A12-P05's
`specs/093-tw-p05-qa/scan-claims.sh` covers the catalog entry and README.

- Q: Which statuses does the release checklist use? → A: The checker's: `verified` (with evidence),
  `pending-campaign-ii` (device rows, naming the device-campaign row) and `owner-action` (with the owner steps).
- Q: How are refused claims checked in the store text and interface copy? → A: A Tiny Worlds scan over the store text
  and the experience's interface Swift (controls and presenter) refuses the A12-P05 words (accurate, accuracy, precise,
  precision, scientific, realistic, real-world, geographic, fps, frames per second, battery, a millisecond figure;
  whole words, case-insensitive), alongside the shared copy check; the shared denylist is not changed; every test named
  in the store claim table must exist.
- Q: What does the source scan refuse? → A: In `Packages/ExperiencesCreative/TinyWorlds`: `URLSession`,
  `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`, `CNContact`,
  `ASIdentifierManager`, `AppTrackingTransparency`, `UIScreen.main.brightness` and `isIdleTimerDisabled`.
- Q: Which interface journeys run, and how? → A: A new serial chunk `t2` with `TWWorldUITests` (open the asteroid
  garden pack; turn and zoom by buttons; reset the view) and `TWEditUITests` (place a prop; move the light azimuth
  slider; save to slot 0 and see its picture), launched as a candidate with `-vcCandidates` and `-openExperience
  a12.tiny-worlds` through `TWSupport` (modelled on `PPSupport`); identifiers `experience.a12.tiny-worlds.<name>`;
  each test under 60 s.
- Q: How are crash recovery and sample files proved? → A: A test-only `failNextDraw` seam is added to the presenter
  (as Physics Playground's); a test saves a world to slot 0 in a temporary storage, sets `failNextDraw`, draws a frame so
  the session enters its failure state, checks `world-0.json` and `world-0.png` are byte-identical, opens a new session
  and draws. Four committed sample files (`valid`, `newer`, `damaged`, `truncated` world JSON) under the experience's
  test resources: the valid one opens with its digest, the others are refused (`newer-version`, `damaged`, `damaged`)
  and stay byte-identical; the schema-1 example restores.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A person can trust Tiny Worlds: it asks for no permission, sends nothing anywhere, tracks nothing, and keeps only its
saved worlds, their pictures and the session state on the device; a plain note says so and credits the content.

**Why this priority**: privacy is a release gate (constitution A12: offline-first and private).

**Independent Test**: a scan of the experience's sources finds no network, tracking, advertising, sensor, recording or
permission use; the app's privacy declarations cover what it uses; the privacy and credits note matches the code.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** they are scanned, **Then** no network, tracking, advertising, location,
   camera, microphone, recording, motion or contacts use is found.
2. **Given** the app's privacy declarations, **When** they are checked, **Then** every required-reason use is covered
   and no tracking is declared.
3. **Given** the privacy and credits note, **When** it is read, **Then** it lists the saved world files and their
   pictures and the session state, states that nothing is sent and no personal data is kept, explains how to delete
   them, and credits every bundled preset, palette, prop and pack with its license.

---

### User Story 2 - Damaged data never breaks a world (Priority: P1)

Saved world files written by this version, by a newer version, damaged ones and half-written ones are each handled as
specified, older saved states restore, and a drawing failure recovers without touching any saved file.

**Why this priority**: the manual's "local data migration" and "crash recovery".

**Acceptance Scenarios**:

1. **Given** committed sample world files (valid, newer version, damaged, truncated), **When** each is opened, **Then**
   the valid one opens, the others are refused with their reason, and none is changed.
2. **Given** a forced drawing failure, **When** it happens, **Then** the session shows its failure state, the saved
   world files and pictures are byte-identical, and reopening draws the world.
3. **Given** saved states of the earlier schema (1), **When** restored, **Then** they migrate.

---

### User Story 3 - Honest store copy and a complete checklist (Priority: P1)

Whoever prepares the release finds a store text that promises only what Tiny Worlds does (every claim traced to a
test), no measured performance claims and no accuracy, scientific, geographic or realism claims, a release checklist
with an artifact inventory, a release configuration, the device-campaign plan and the known limitations.

**Acceptance Scenarios**:

1. **Given** the store text, **When** it is checked, **Then** every claim has a proving test and no measured or refused
   claim appears.
2. **Given** the release checklist, **When** it is read, **Then** every item has a status and evidence or owner steps.
3. **Given** a missing release document, **When** the check runs, **Then** it fails and names the document.

---

### User Story 4 - The worlds work in the real app (Priority: P2)

Tiny Worlds' main journeys work through the app's interface on the iOS 27 phone simulator — opening a pack, orbiting
and zooming with the buttons, placing a prop, changing the light and saving a world — and the release build and its
checks pass.

**Acceptance Scenarios**:

1. **Given** the app with Tiny Worlds, **When** the interface tests run, **Then** those journeys work by their
   controls, each test under 60 s.
2. **Given** a release build, **When** its checks run, **Then** the build, symbols, privacy manifest, no-tracking,
   licenses and usage descriptions checks pass.

### Edge Cases

- **A device row without results:** stays pending; no measured value is claimed.
- **An owner step not done:** recorded as BLOCKED_OWNER_ACTION with the exact steps; work continues.
- **A store claim without a test:** the copy check fails.
- **A world file from a future version:** refused and never rewritten until the person saves over it.
- **A picture without its world file, or a world file without its picture:** the slot reads as the world file says
  (empty, or "no picture"); nothing crashes.
- **Gestures in interface tests:** canvas gestures are covered by the presenter's gesture tests; the interface tests use
  the native controls (every gesture has one).

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**

- **FR-A12-601**: Tiny Worlds MUST request no permission and add no usage string.
- **FR-A12-602**: The experience's sources MUST contain none of the scanned network, tracking, sensor, recording,
  brightness or idle-timer uses.
- **FR-A12-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A12-604**: A privacy and credits note MUST state what is stored and where, that nothing is sent, how to delete
  it, and credit every bundled preset, palette, prop and pack with author and license.

**Data and recovery (story 2)**

- **FR-A12-610**: Committed sample world files of each form MUST open or be refused as specified, with refused files
  byte-identical; a picture without its world file MUST leave the slot empty and a world file without its picture MUST
  read as "no picture".
- **FR-A12-611**: A forced drawing failure (test-only seam) MUST put the session into its failure state with the saved
  files byte-identical, and a reopen MUST draw normally.
- **FR-A12-612**: Saved states of schema 1 MUST restore (stored example), re-run here.

**Copy and release documents (story 3)**

- **FR-A12-620**: A release checklist with an artifact inventory, a store text input with a claim → test table, the
  device-campaign plan and a release configuration MUST exist and pass the release-document check.
- **FR-A12-621**: The shared copy-claim check MUST pass on the store text and the interface copy, and Tiny Worlds' own
  scan MUST refuse accuracy, scientific, geographic, realism and measured-performance words.
- **FR-A12-622**: Known limitations MUST list the device-only items (frame pacing, thermals, memory high-water mark,
  touch latency, accessibility audits) and that the worlds are stylised dioramas, not maps.
- **FR-A12-623**: The checklist MUST list the accessibility facts proved so far (labels and values, native alternatives
  to every gesture, spoken view and pick descriptions, Reduce Motion) and the audits pending for the device campaign.

**Interface and build (story 4)**

- **FR-A12-630**: Interface tests on iOS 27 MUST cover opening a pack, orbit and zoom by buttons, placing a prop,
  changing the light and saving a world, each under 60 s, in their own chunk.
- **FR-A12-631**: The release build checks MUST pass.
- **FR-A12-632**: The experience's package tests MUST pass on iOS 27.

**Owner and device**

- **FR-A12-640**: Signing, upload and App Store Connect entry of the store text MUST be recorded as owner actions.
- **FR-A12-641**: The device campaign's measurements and audits MUST be listed as {device} tasks.

### Key Entities

- **Release configuration**: experience id, required documents, checklist, copy-check sources.
- **Release checklist row**: item, area, status, evidence.
- **Sample world file**: form (valid, newer, damaged, truncated), expected outcome.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A12-601**: The source scan finds 0 forbidden uses; the release checks report 0 tracking declarations.
- **SC-A12-602**: 100 % of sample files behave as specified and 100 % of refused files stay byte-identical.
- **SC-A12-603**: The release-document, copy-claim and Tiny Worlds scans pass with 0 problems; every store claim names
  an existing test.
- **SC-A12-604**: The interface chunk passes with every test under 60 s.
- **SC-A12-605**: The package tests and the runner's nine scenarios pass on iOS 27.

## Assumptions

- The device campaign, owner steps and the reference regression (X-A12) are outside this phase's automated evidence.
- The saved-world store, its refusals and the schema-1 example exist from A12-P03; the claims scan of A12-P05 covers the
  catalog entry and the README.

## Out of Scope

- Pricing, screenshots, a per-app listing, TestFlight, submission.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06 deliverable (privacy, accessibility, credits, migration, tests, crash recovery, build instructions) | FR-A12-601–641 |
| Phase 06 gate "unsupported promised features removed" | FR-A12-621 |
| Constitution A12 offline-first, private, truthful claims, licenses | FR-A12-601–604, 621 |
| Manual §13 obligations (licenses, privacy) | FR-A12-604 |

## Negative Requirements

- No network, accounts, analytics, advertising or tracking; no permission; no personal data; no accuracy, scientific,
  geographic or realism claims; no measured numbers without device evidence; no submission or signing by the agent.
