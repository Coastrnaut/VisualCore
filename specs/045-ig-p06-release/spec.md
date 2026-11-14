# Feature Specification: Infinite Geometry — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `045-ig-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A05-P06 (legacy ledger) · ID namespace FR-A05-6##, SC-A05-6##, T-A05-6##

**Input**: User description: archived manual `apps/05-infinite-geometry.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; all required automated
  tests have attached results and device tests are planned for the device campaign; unsupported promised features are
  absent from the interface and the store text.
- **Pattern:** the release readiness of Particle Universe (A04-P06, `specs/038-pu-p06-release`): privacy and credits
  note, no-network scan, library format fixtures, drawing-failure recovery, release documents with a release-document
  check and a copy-claim check, known limitations, interface tests in the one app, release build checks.
- **Owner rulings:** 2026-11-13 — short tests; accessibility audits and all device measurements wait for the device
  campaign; 2026-11-14 — phase gates run iOS 27 only (iOS 26 at X-A05), no reference regression unless VisualCore
  changes; every Spec Kit step still runs. Owner-only actions (signing, archive upload, App Store Connect) are
  `BLOCKED_OWNER_ACTION`; device rows are `{device}` tasks after ImplementationLock-100.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
Particle Universe proves recovery with an internal presenter seam `failNextDraw` (throws once from `draw`);
interface tests open a candidate experience with the debug arguments `-vcCandidates` and `VC.openExperience <id>`
(`PUSupport.swift`) and run in chunks of `release_check.py` `UI_CHUNKS`; the release build steps are
`app-release-build`, `app-release-symbols`, `app-privacy-manifest`, `app-no-tracking`, `app-licenses`,
`app-usage-descriptions`; the A05 library treats a file without `format` as unreadable (Phase 04 decision, no older
files exist).

- Q: How is a drawing failure produced without touching release behaviour? → A: An internal `failNextDraw` flag on
  `GeometryPresenter`, as in Particle Universe: the next draw throws `GeometryDrawError.injected` and clears the flag;
  only tests set it (internal, reached through `@testable`).
- Q: What does the missing-format fixture expect? → A: Counted as unreadable and kept (the Phase 04 rule); the other
  four fixtures: format 1 listed and opens with its digest; newer format and newer document version counted as newer,
  refused on open, never rewritten; damaged counted as unreadable.
- Q: Which interface chunk and classes? → A: Chunk `k2` with `IGControlsUITests` (open, preset, symmetry order, camera
  buttons, description) and `IGLibraryExportUITests` (save, choose another preset, reopen, export shows the share
  control), using the candidate launch arguments; added to `UI_CHUNKS`.
- Q: Which release build checks count for this phase? → A: The six release steps listed above in one run; they cover
  the whole app (the experience adds no usage string, tracking domain or license).
- Q: What is the copy check's input? → A: `docs/apps/infinite-geometry/store-listing.md` and the experience's
  `GeometryControls.swift` and `GeometryPresenter.swift` strings, through `release.json`'s `copyCheck`, with the
  shared denylist `Configs/copy-claims-denylist.json`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing about me leaves the device (Priority: P1) 🎯

A person using Infinite Geometry is not asked for any permission, and nothing they make is sent anywhere; their saved
compositions stay on the device, and an exported picture goes only where they share it.

**Why this priority**: privacy is a release gate of the one app (constitution; App Store privacy answers).

**Independent Test**: scan the experience's sources for network, tracking, advertising and sensor use (none); check the
app's privacy manifest covers every required-reason use; read the privacy note.

**Acceptance Scenarios**:

1. **Given** the release build, **When** its usage strings are listed, **Then** Infinite Geometry adds none.
2. **Given** the experience's sources, **When** they are scanned, **Then** no network, tracking, advertising, camera,
   microphone, location or motion use is found.
3. **Given** the privacy note, **When** it is read, **Then** it states what is stored (saved compositions), where (the
   experience's own folder), that pictures leave only through the share sheet, and that nothing is collected.

---

### User Story 2 - My saved work survives updates and failures (Priority: P1)

Saved compositions from this version open in later versions; files from a newer version are kept and not overwritten;
a damaged file does not break the list; a drawing failure ends the session cleanly without touching saved work.

**Why this priority**: local data migration and crash recovery are named in the phase deliverable.

**Independent Test**: committed fixtures of every library file form load as specified; a forced drawing failure puts the
session into its failure state with the saved files byte-identical.

**Acceptance Scenarios**:

1. **Given** a format-1 file, **When** the library loads, **Then** it is listed and opens with its saved digest.
2. **Given** a file of a newer format or a newer document version, **When** the library loads, **Then** it is counted as
   newer, refused when opened, and never rewritten.
3. **Given** a damaged file or one without a format number, **When** the library loads, **Then** it is counted as
   unreadable and kept.
4. **Given** a running session with saved compositions, **When** a drawing failure is forced, **Then** the session
   reaches its failure state, the files are byte-identical and a new session opens normally.

---

### User Story 3 - The store text promises only what exists (Priority: P2)

The App Store text input and the in-app wording describe only features that exist and are tested, with no speed,
device or measured claims.

**Why this priority**: the gate "unsupported promised features are absent from UI and marketing copy".

**Independent Test**: the copy-claim check finds no measured or unimplemented claim in the store text and the
experience's interface strings; every store sentence maps to a test in a traceability table.

**Acceptance Scenarios**:

1. **Given** the store text and the controls' strings, **When** the copy check runs, **Then** it reports 0 problems.
2. **Given** the release documents, **When** the release-document check runs, **Then** every required document exists
   and every checklist item has a status and evidence; removing a document makes it fail.

---

### User Story 4 - The app's interface proves the main journeys (Priority: P2)

In the one app, an interface test opens Infinite Geometry, changes the symmetry, moves the camera with the buttons,
saves and reopens a composition, and exports a picture.

**Why this priority**: the gate "all required automated tests have attached results" for the interface.

**Independent Test**: the new interface chunk passes on the iOS 27 phone simulator.

**Acceptance Scenarios**:

1. **Given** the app, **When** Infinite Geometry is opened, **Then** the canvas and its description appear.
2. **Given** the controls, **When** the preset, symmetry order and camera buttons are used, **Then** the description
   reflects each change.
3. **Given** a saved composition, **When** another preset is chosen and the composition is reopened, **Then** the
   description matches the saved one.
4. **Given** the export button, **When** it is pressed, **Then** the share control appears.

### Edge Cases

- A newer file never blocks loading the rest of the library.
- A drawing failure during an export does not leave a partial file (exports are in memory).
- With Reduce Motion the composition is static (Infinite Geometry has no animation; nothing to reduce) — stated in the
  privacy-and-accessibility notes, not claimed as a feature.
- Interface tests run with the app's debug launch arguments only in debug builds; the release build contains none.

## Requirements *(mandatory)*

### Functional Requirements

**Privacy (story 1)**
- **FR-A05-601**: Infinite Geometry MUST declare no permission and add no usage string.
- **FR-A05-602**: The experience's sources MUST contain no network, tracking, advertising or sensor use (scan).
- **FR-A05-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A05-604**: A privacy and credits note MUST state what is stored, where, how pictures leave, that nothing is
  collected, and the credits (no third-party art; code and shaders original).

**Data and recovery (story 2)**
- **FR-A05-610**: Committed fixtures of each library file form (format 1, newer format, newer document version, damaged,
  missing format) MUST load as specified by the Phase 04 library rules.
- **FR-A05-611**: A forced drawing failure (test-only seam) MUST put the session into its failure state with saved files
  byte-identical, and a new session MUST open normally.

**Copy and release documents (story 3)**
- **FR-A05-620**: A release checklist with an artifact inventory, a store text input with a traceability table, a
  device-campaign plan and the privacy note MUST exist; a release-document check MUST verify them.
- **FR-A05-621**: The copy-claim check MUST find no measured or unimplemented claim in the store text and the
  experience's interface strings.
- **FR-A05-622**: The known limitations MUST list Infinite Geometry's device-only items, and the device-campaign plan
  MUST name each measurement without a value: frame time per quality tier for every preset kind on D1–D3, the tier the
  governor settles on, memory with the mesh cache full, thermal state over a short session, export time, the
  accessibility audits and VoiceOver journeys.

**Interface and builds (story 4)**
- **FR-A05-630**: An interface test chunk for Infinite Geometry MUST pass on the iOS 27 phone simulator.
- **FR-A05-631**: The release build checks (release build, symbols, privacy manifest) MUST pass.
- **FR-A05-632**: Every Infinite Geometry suite MUST pass on iOS 27; every new test MUST finish in under 10 seconds.

**Common**
- **FR-A05-640**: No new permission, no network, no VisualCore change unless proven needed; owner-only steps are
  recorded as `BLOCKED_OWNER_ACTION`, device steps as `{device}` tasks.

### Key Entities

- **Release configuration**: the experience id, the required documents, the checklist and the copy-check inputs.
- **Library fixture**: one stored file per form with its expected loading outcome.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A05-601**: 0 usage strings, 0 network uses and 0 tracking domains added; the privacy manifest check passes.
- **SC-A05-602**: 5 of 5 library fixtures load as specified; the format-1 fixture reopens with its saved digest.
- **SC-A05-603**: The forced drawing failure reaches the failure state in 1 of 1 run with saved files byte-identical.
- **SC-A05-604**: The release-document check passes; removing a required document makes it fail.
- **SC-A05-605**: The copy check finds 0 problems.
- **SC-A05-606**: The interface chunk passes; the release build checks pass; all suites pass on iOS 27; every new test
  is under 10 seconds.

## Assumptions

- The one app's release build and privacy manifest checks already exist (UA-F10, UA-F11) and only need to pass.
- Device measurements (frame time, thermal, memory) and the accessibility audits are in the device campaign plan, not
  claimed here.
- The interface chunk follows the existing UI chunk pattern (built once, run without building, two simulator clones).

## Out of Scope

- Signing, archive upload, App Store Connect (owner); device runs (campaign); new features.

## Traceability

| Source | Requirement |
|---|---|
| Manual §9 Phase 06 deliverable: privacy/permission strings | FR-A05-601–604 |
| Local data migration, crash recovery | FR-A05-610, 611 |
| App Store asset/credit review; no fabricated performance claims | FR-A05-604, 620–622 |
| CPU/GPU/device tests | FR-A05-622 (device plan), 630–632 |
| Build/archive instructions | FR-A05-620 (checklist cites `docs/release/build-and-archive.md`) |

## Negative Requirements

- No measured performance claim anywhere; no new permission; no network, analytics, ads or accounts.
- No device install or run before ImplementationLock-100.
