# Feature Specification: Visual Programming Lab — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `171-vpl-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A23-P06 (legacy ledger) · ID namespace FR-A23-6##, SC-A23-6##, T-A23-6##

**Input**: User description: archived manual `apps/23-visual-programming-lab.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **ADR-0009:** A23 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable; the experience's release documents feed the app's release. Its quality, privacy, accessibility and
  regression gates stand. Visuals are code only; the app makes no network request.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy: no general programming language, no
    script or shader text typed by the person, no sharing, upload or export, no measured speed.
- **Gap built here:** G-RELEASE of `docs/apps/visual-programming-lab/visualcore-contract.json` (the A23 copy-claims
  and experience-release steps and the release documents); its iOS 26.x runner half is cited at X-A23.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/164-ss-p06-release`.

## Clarifications

### Session 2026-11-19

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- **Permissions:** `Catalog/registrations.json` gives `a23.visual-programming-lab` the permissions `[]`, so no usage
  string is needed.
- **Copy steps:** `scripts/release_check.py` builds `experience-release-<code>` and `copy-claims-<code>` from an
  experience's `release.json` (as Shader Studio's `docs/apps/shader-studio/release.json`). The shared denylist is
  `Configs/copy-claims-denylist.json`; the lab shares nothing, so `copyCheck.allow` is empty.
- **Stored data:**
  - the session snapshot (`LabCore`, schema 1, digest domain `a23.visual-programming-lab.v1`: the graph and the
    selection);
  - `graph-<n>.json` (kind `a23.saved-graph`, version 1, at most 81,920 bytes, embedding the graph file
    `a23.visual-graph` version 1);
  - `library.json` (kind `a23.graph-library`, version 1), at most 24 graphs.

  The refusals are `damaged`, `newer-version`, `too-large` and the graph file's codes. No temporary file is written.
- **Screen:** the experience never changes the idle timer or the brightness; the source shows no such call.
- **Drawing failure:** `LabPresenter.draw` throws to the session; there is no test seam yet.
- **Interface chunk:** the A23 interface chunk is `e3` (A23-P02 to P05).

- Q: Which statuses does the release checklist use? → A: The checker's:
  - `verified`, with evidence;
  - `pending-campaign-ii`, for device rows naming VPL-D1 … VPL-D6 of
    `docs/apps/visual-programming-lab/device-campaign.md`;
  - `owner-action`, with the steps of `docs/release/build-and-archive.md`.
- Q: Which words does the experience's own claims scan refuse? → A: It scans the store text and the interface Swift
  (controls, canvas overlay, library view, presenter and the adapter's words), whole words, case-insensitively:
  - programming language, write code, coding, script, scripting, type shaders, shader code editor;
  - Shadertoy, TouchDesigner, Blender, Unreal, Unity, node-based compositor;
  - compatible with, imports, educational, teaches, learn to code, scientific (the A23 section of the constitution:
    no compatibility claim, no educational or scientific outcome claim);
  - upload, export, cloud, sync, account, share;
  - fps, unlimited, real-time.

  The phrase "no code to type" is required in the store text. Every test named in the claims table must exist.
- Q: What does the source scan refuse? → A: The A22 list, in `Packages/ExperiencesCreative/VisualProgrammingLab`:
  - `URLSession`, `import Network`, `CLLocation` and `import CoreLocation`;
  - `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap` and `CMMotion`;
  - `CNContact`, `PHPhotoLibrary`, `import Photos` and `PhotosUI`;
  - `ASIdentifierManager`, `AppTrackingTransparency` and `isIdleTimerDisabled`;
  - any `brightness =` write;
  - `UIPasteboard` and `ShareLink`.
- Q: How are crash recovery and the sample files proved? → A:
  - **Crash recovery:** a test-only `failNextDraw` seam in the presenter makes the next draw throw once
    (`LabDrawError.injected`). A test saves two graphs, sets the seam and draws, so the session fails with the injected
    message. Every storage file must be byte-identical, and a new session over the same storage lists and opens both
    graphs.
  - **Sample files:** committed fixtures under `ExperienceTests/Fixtures/` beside the A23-P04 `graph-sample.json`:
    - `snapshot-v1.json` (current), `snapshot-newer.json` and `snapshot-damaged.json`;
    - `graph-newer.json` and `graph-damaged.json` (the current saved graph is `graph-sample.json`);
    - `library-current.json`, `library-newer.json` and `library-damaged.json`.

    The current samples open. The newer and damaged snapshots are refused. A newer or damaged graph file is listed as
    unreadable with its code. A newer index makes the library read-only; a damaged index still lists the graphs from
    their files. Every file stays byte-identical after reading.
- Q: Which interface journey runs? → A: `VPLReleaseUITests` joins chunk `e3`. A fresh start shows the status "Ready",
  the list form's rows `node-row-1` and `node-row-2` and no `node-row-3`, no `feedback`, and an empty library (no
  `library-row-graph-1`). The test takes under 60 s.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A reviewer reads one page: what Visual Programming Lab stores (the open graph in the session snapshot, and the named
graphs of the library), where and how they are removed; that it sends nothing over the network; that it asks for no
permission; and that every node operator, example graph and picture is made in code.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; run the source scan.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored data and its removal, says nothing is sent and no permission is
   asked, and lists the licences.
2. **Given** the experience's sources, **Then** no network, location, tracking, sensor, microphone, camera, photo,
   contact, pasteboard, sharing, idle-timer or brightness use appears.

---

### User Story 2 - Recover without losing the graphs (Priority: P1)

A drawing failure ends the session with a message; the saved graphs are unchanged; a new session opens and lists them.
Stored files of every kind open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** saved graphs, **When** a draw fails, **Then** the session fails with a message, every stored file is byte
   for byte unchanged, and a new session lists and opens them.
2. **Given** committed samples of the session snapshot, a saved graph file and the library index (current, newer,
   damaged), **Then** current samples open and newer and damaged ones are refused without a crash, every file
   byte-identical afterwards.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text claims only what a test proves and never claims a programming language, typed code, sharing or export,
or a measured speed or battery figure; the release checklist lists every result as verified, pending the device
campaign, or an owner action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text and the interface's words, **Then** no refused word appears and every claim names a test
   that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - A first session in the app (Priority: P2)

In the one app, a first session opens on the starter graph (Noise into Output), drawn in the preview, with no problem
shown and an empty library.

**Why this priority**: interface evidence at the release gate (first-session flow).

**Independent Test**: the A23 interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **Then** the list form shows two nodes, the status reads "Ready", no feedback is shown,
   and the library lists no graph.

### Edge Cases

- **A sample of a schema not yet written:** refused as newer.
- **Copy that implies the lab is a programming language or runs typed code:** refused.
- **Copy that promises sharing, export or a cloud library:** refused.
- **A damaged library index:** graphs are still listed from their files; the index is rebuilt by the next change,
  never by reading.
- **A saved graph above the file size limit:** refused as too large, the file kept.
- **A device-only check:** pending the campaign, never claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A23-601**: A privacy-and-credits page MUST list the stored data (session snapshot, named graphs and their
  index), its place (the experience's own storage), its removal (by the person in the library, or when the app is
  deleted), "nothing is sent", "no permission is asked", and the licence inventory.
- **FR-A23-602**: A source scan MUST find no network, location, tracking, sensor, microphone, camera, photo, contact,
  pasteboard, sharing, idle-timer or brightness use in the experience.
- **FR-A23-603**: A drawing failure MUST fail the session with a message, leave every stored file unchanged, and a new
  session MUST list and open the saved graphs.
- **FR-A23-604**: Committed samples of the snapshot, a saved graph file and the library index MUST open or be refused
  as specified, and stay byte-identical after reading.
- **FR-A23-605**: The store text MUST make only claims a named test proves; refused words MUST not appear in the store
  text or the interface's words.
- **FR-A23-606**: The release checklist and release.json MUST list every document and result, and
  `docs/release/known-limitations.md` MUST gain an A23 section (seven node kinds, at most 32 nodes and 64 connections,
  at most six preview textures, no typed code, no sharing or export, device rows pending); the experience-release and
  copy-claims steps for A23 MUST pass. The device rows MUST be `pending-campaign-ii` and name their campaign rows
  VPL-D1 … VPL-D6 of `docs/apps/visual-programming-lab/device-campaign.md`. Accessibility is listed with its automated
  evidence (spoken labels, the list form for every connection, Dynamic Type layout) as `verified`, and the system
  accessibility audits as `pending-campaign-ii` (they run only in the device campaign, owner ruling of 2026-11-13).
- **FR-A23-607**: The interface tests MUST cover the first-session defaults in the A23 chunk.

### Key Entities

- **Release checklist**: rows with status (verified, pending-campaign-ii, owner-action) and evidence.
- **Store text claims**: claim and proving test.
- **Sample files**: committed stored values with their expected outcome (opens, refused with a code).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A23-601**: 0 refused uses in the experience's sources.
- **SC-A23-602**: After a drawing failure, every stored file is unchanged and the experience reopens with the graphs.
- **SC-A23-603**: 0 refused words; every claim's test exists.
- **SC-A23-604**: The release checks and the interface chunk pass on iOS 27; unit tests under 10 s, interface tests
  under 60 s.

## Assumptions

- The A23-P01 to P05 work is reused; no new capability is added.
- The release build checks of `scripts/release_check.py` read `docs/apps/visual-programming-lab/release.json` like
  Shader Studio's.
- The registration's permissions are empty, so no usage string is needed.

## Traceability

| Source | Requirement |
|---|---|
| Release checklist and artifact inventory complete | FR-A23-606 |
| Automated and device tests have attached results | FR-A23-606, SC-A23-604 |
| Unsupported promised features removed from UI and copy | FR-A23-605, SC-A23-603 |
| Privacy/permission strings, App Store asset/credit review | FR-A23-601, 602 |
| Local data migration, crash recovery | FR-A23-603, 604 |
| Contract G-RELEASE | FR-A23-601–607 |

## Negative Requirements

- No VisualCore or ProjectM change; no new feature; no device run before `ImplementationLock-100`; no fabricated
  measurement; no claim of a programming language or typed code; no owner-only step done by the agent.
