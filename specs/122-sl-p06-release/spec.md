# Feature Specification: Simulation Lab — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `122-sl-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A16-P06 (legacy ledger) · ID namespace FR-A16-6##, SC-A16-6##, T-A16-6##

**Input**: User description: archived manual `apps/16-simulation-lab.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **ADR-0009:** A16 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable; the experience's release documents feed the app's release. Its quality, privacy, accessibility and
  regression gates stand.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results; device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy.
- **Gap built here:** G-RELEASE of `docs/apps/simulation-lab/visualcore-contract.json`. It covers:
  - licenses of presets, palettes, copy and shaders;
  - the educational approximation labels;
  - no accuracy, prediction or certification claims;
  - an unchanged privacy answer;
  - registration and the experience-release and copy-claims steps.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION` with the steps of
  `docs/release/build-and-archive.md`. Follow `specs/115-me-p06-release`.

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time), with the facts checked
in code:
- The release checker reads `docs/apps/<slug>/release.json` (schema 1: `requiredDocs`, `checklist`, and `copyCheck`
  with text, swift and allow). `scripts/release_check.py` builds `experience-release-<id>` and `copy-claims-<id>` from
  it, and the last interface chunk is `w2`.
- The shared denylist refuses `share` as a feature the experience lacks; A16-P04 added sharing.

- Q: Which statuses does the release checklist use? → A: The checker's:
  - `verified`, with evidence;
  - `pending-campaign-ii`, for device rows naming the device-campaign rows SL-D1 … SL-D6 of
    `docs/apps/simulation-lab/device-campaign.md`;
  - `owner-action`, with the owner's steps from `docs/release/build-and-archive.md`.
- Q: Which words does the experience's own scan refuse? → A: Over the store text and the interface Swift (controls,
  presenter, legend and the adapter's words), as whole words, case-insensitive:
  - accurate, accuracy, precise, precision, predict, prediction, forecast, certified, certification;
  - real-time, realistic, scientific-grade;
  - fps, frames per second, battery.

  "exact" stays allowed, because the automaton's states are exact and its label says so. The shared copy check runs
  with `share` allowed (the capture's share sheet). Every test named in the claims table must exist.
- Q: What does the source scan refuse? → A: In `Packages/ExperiencesCreative/SimulationLab`, the A15 list:
  `URLSession`, `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`,
  `CNContact`, `PHPhotoLibrary`, `UIImagePickerController`, `ASIdentifierManager`, `AppTrackingTransparency`,
  `UIScreen.main.brightness` and `isIdleTimerDisabled`.
- Q: Which interface journeys run, and how? → A: A new serial chunk `x2`, launched through `SLSupport` as `MESupport`
  does; each test under 60 s; no share sheet is presented (the capture is proved by the package tests).
  - `SLExploreUITests`: Pause, and the status starts "Paused"; Step, and the step count in the status rises by one;
    the bundled preset Spots, and the status names time step 1 while the approximation label names the Euler step;
    Seed, and the step count is unchanged.
  - `SLLibraryUITests`: type "My spots" in the experiment name and Save, and a "My spots" button appears; reopen the
    experience, and it is still listed.
- Q: How are crash recovery, sample files and old sessions proved? → A: Three proofs:
  - **Crash recovery.** A test-only `failNextDraw` seam in the presenter. A test saves an experiment into a temporary
    storage, sets the seam, and draws so the session fails. The preset file must be byte-identical, and a new session
    over the same storage lists and opens it.
  - **Sample files.** Committed `preset-{valid,newer,damaged,invalid}.json` and `state-{valid,newer,damaged}.json`
    under the experience's test fixtures, answered by `SimulationPresetStore` or `SimulationCore.restore` as specified
    and byte-identical afterwards.
  - **Old sessions.** The state and preset schemas are both at version 1, so no older stored form exists and no
    schema examples are registered; this is recorded in the release checklist.

  A license inventory in `privacy-and-credits.md` lists the six presets, the three palettes and the shader programs:
  the parameters' scientific sources are public domain, and the palettes and shaders are original code.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A person exploring simulations shares nothing they did not choose to share. The experience asks for no permission,
makes no network request, and stores only its saved experiments and the session state, which a reviewer can list.

**Why this priority**: the privacy answer of the app must stay unchanged.

**Independent Test**: scan the experience's sources for network, sensor and tracking uses; read the privacy document.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **Then** none of the refused uses appears.
2. **Given** the privacy document, **Then** it lists what is stored, where, how it is deleted, and that a capture
   leaves the device only through the share sheet the person opens.

---

### User Story 2 - Saved data survives failures (Priority: P1)

A person's saved experiments survive a drawing failure and damaged or newer files; nothing is lost or rewritten.

**Why this priority**: local data migration and crash recovery.

**Independent Test**: fail a draw; compare the files; open a new session; answer committed samples.

**Acceptance Scenarios**:

1. **Given** saved experiments, **When** a draw fails, **Then** the files are byte-identical and a new session lists
   and opens them.
2. **Given** committed sample files (valid, newer, damaged, refused), **Then** each is answered as specified and left
   byte-identical.

---

### User Story 3 - Truthful release documents (Priority: P1)

A reviewer reads a release checklist, an artifact inventory, a license inventory and a claims table, in which every
claim names the test that proves it and no claim promises accuracy, prediction or certification.

**Why this priority**: the phase gates.

**Independent Test**: run the release checks and the claims scan.

**Acceptance Scenarios**:

1. **Given** the release documents, **Then** the experience-release and copy-claims checks pass and every named test
   exists.

---

### User Story 4 - The interface end to end (Priority: P2)

A person on the iPhone simulator chooses a family, steps it, paints a cell and saves an experiment, and the interface
answers as expected.

**Why this priority**: the interface gate on the iOS 27.x phone.

**Independent Test**: run the interface chunk.

**Acceptance Scenarios**:

1. **Given** the app, **When** the journeys run, **Then** each passes in under 60 s.

### Edge Cases

- **Owner-only steps** (signing, archive, upload): listed with the owner's steps, never done.
- **Device-only items** (frame rate, thermal, VoiceOver on device): listed as pending-campaign-ii with their
  campaign rows.
- **A word in the copy that the shared check refuses but the experience has** (`share`, `simulation`): allowed
  explicitly, with the reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A16-601**: The experience's sources MUST contain none of the refused network, sensor and tracking uses.
- **FR-A16-602**: The app's privacy answers and usage descriptions MUST stay unchanged.
- **FR-A16-603**: A privacy-and-credits document MUST list what is stored, where, how it is deleted, and the sources and
  licenses of every bundled preset, palette and shader.
- **FR-A16-610**: Saved experiments MUST survive a failed draw byte-identical, and a new session MUST open them.
- **FR-A16-611**: Committed sample files MUST be answered as specified and left byte-identical.
- **FR-A16-620**: A release checklist, an artifact inventory, a claims table and a device-campaign plan MUST exist, with
  statuses `verified`, `pending-campaign-ii` or `owner-action`.
- **FR-A16-621**: Copy MUST contain no accuracy, prediction, certification or measured-performance claim, and every
  claim MUST name an existing test.
- **FR-A16-622**: Every experiment MUST show and speak its method and limits (the approximation label).
- **FR-A16-630**: Interface journeys MUST run on the iOS 27.x phone simulator.
- **FR-A16-631**: The release build checks MUST pass.
- **FR-A16-632**: The experience's package suites MUST pass on iOS 27.

### Key Entities

- **Release checklist**: item, area, status, evidence.
- **License inventory**: each bundled preset, palette and shader, with its source and license.
- **Sample files**: preset files in each answered form.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A16-601**: 0 refused uses in the sources.
- **SC-A16-602**: 100 % of sample files answered as specified and byte-identical afterwards.
- **SC-A16-603**: 0 forbidden words in the copy; 100 % of claimed tests exist.
- **SC-A16-604**: The release checks and the interface chunk pass; every journey runs in under 60 s.
- **SC-A16-605**: Every package test runs in under 10 s.

## Assumptions

- The release-check tool's steps (`experience-release-<id>`, `copy-claims-<id>`, app privacy and licenses) are reused;
  the experience-release configuration is added for A16. No VisualCore change.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06 deliverable: privacy and permission strings | FR-A16-601–603 |
| Accessibility; method and limits shown and spoken | FR-A16-622 |
| App Store asset and credit review | FR-A16-603, 620 |
| Local data migration; crash recovery | FR-A16-610, 611 |
| CPU/GPU/device tests | FR-A16-630–632; device items pending-campaign-ii |
| Build and archive instructions | FR-A16-620 (owner-action rows) |
| Gate: unsupported promised features removed | FR-A16-621 |
| Contract G-RELEASE | FR-A16-601–631 |

## Negative Requirements

- No fabricated measured performance claim; no device result from a simulator run; no signing, archive or upload; no
  network, permission, account, advertising or tracking; no VisualCore change.
