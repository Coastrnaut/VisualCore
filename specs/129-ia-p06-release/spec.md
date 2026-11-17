# Feature Specification: Interactive Anatomy — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `129-ia-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A17-P06 (legacy ledger) · ID namespace FR-A17-6##, SC-A17-6##, T-A17-6##

**Input**: User description: archived manual `apps/17-interactive-anatomy.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **ADR-0009:** A17 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable, and the experience's release documents feed the app's release. Its quality, privacy, accessibility
  and regression gates stand.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy.
- **Gap built here:** G-RELEASE of `docs/apps/interactive-anatomy/visualcore-contract.json`. It covers:
  - the license inventory of text, data and procedural geometry;
  - the educational, schematic and not-reviewed labels;
  - no diagnostic, treatment, accuracy or certification claims;
  - an unchanged privacy answer;
  - registration and the experience-release and copy-claims steps.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/122-sl-p06-release`.

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time). The facts were checked
in code:
- `scripts/release_check.py` builds `experience-release-<code>` and `copy-claims-<code>` from
  `docs/apps/<slug>/release.json`, and the last interface chunk is `x2` (A16-P06).
- The shared denylist (`Configs/copy-claims-denylist.json`) refuses, among others, `camera`, `instant` and `share`.
- The presenter already has the test seam `failNextTranslucentDraw` (A17-P03). The view file is written through
  `ExperienceStorage` (A17-P03).

- Q: Which statuses does the release checklist use? → A: The checker's:
  - `verified`, with evidence;
  - `pending-campaign-ii`, for device rows naming IA-D1 … IA-D7 of `docs/apps/interactive-anatomy/device-campaign.md`;
  - `owner-action`, with the owner's steps from `docs/release/build-and-archive.md`. The clinical review is one more
    owner-action row.
- Q: Which words does the experience's own scan refuse? → A: It scans the store text and the interface Swift (controls,
  presenter, overlay, the adapter's words and `AnatomyReview`), matching whole words case-insensitively:
  - diagnose, diagnosis, diagnostic, treatment, cure, symptom, symptoms, therapy, medical advice;
  - accurate, accuracy, precise, certified, certification, anatomically correct, realistic, lifelike, real-time;
  - fps, frames per second, battery.

  "clinician" stays allowed, because the not-reviewed sentence names one. The shared copy check runs with `camera`
  allowed: in A17 it means the orbit camera of the 3D view ("Turn the camera", "The camera is at its limit."), never
  the device camera. Every test named in the claims table must exist.
- Q: What does the source scan refuse? → A: The A16 list, in `Packages/ExperiencesCreative/InteractiveAnatomy`:
  `URLSession`, `import Network`, `CLLocation`, `AVCapture`, `AVAudioRecorder`, `inputNode`, `installTap`, `CMMotion`,
  `CNContact`, `PHPhotoLibrary`, `UIImagePickerController`, `ASIdentifierManager`, `AppTrackingTransparency`,
  `UIScreen.main.brightness` and `isIdleTimerDisabled`.
- Q: Which interface journeys run, and how? → A: A new serial chunk `y2`, launched through `IASupport` as `SLSupport`
  does. Each test takes under 60 s.
  - `IAExploreUITests`:
    - choose "Femur" in the list, and the panel shows "Femur", a citation and "Not reviewed by a clinician.";
    - the About row shows the model statement;
    - switch off the bones layer, and the femur row is marked hidden.
  - `IASearchUITests`:
    - type "ACL" in the search field and choose the first result, and the anterior cruciate ligament is selected;
    - Isolate selected, then Show all.
- Q: How are crash recovery, sample files and old views proved? → A: Three proofs:
  - **Crash recovery:** a test-only `failNextDraw` seam in the presenter makes the next draw throw once. A test saves a
    view to a temporary storage, sets the seam and draws, so the session fails. `view.json` must be byte-identical,
    and a new session over the same storage opens with the view.
  - **Sample files:** committed `view-{v2,v1,newer,damaged}.json` under the experience's test fixtures. They open, or
    leave the opening view, as specified, and are byte-identical afterwards.
  - **Old views:** view schema 1 (A17-P02) is the only older form, and it is covered by the v1 sample.

  The license inventory in `privacy-and-credits.md` lists the content pack's sources (Gray's Anatomy 1918
  public-domain, Terminologia Anatomica facts, original descriptions), the procedural geometry (original code), the
  review record (original) and the colours (original).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device and everything is credited (Priority: P1) 🎯

A reviewer reads one page: what the experience stores (the saved view), where it is and how to delete it; that it
sends nothing; and where every bundled text, name and shape comes from, under which license.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; scan the sources for network use.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored file and how to remove it, says nothing is sent, and lists the
   pack's sources and licenses, the procedural geometry and the review record.
2. **Given** the experience's sources, **Then** no network, tracking or advertising API is used.

---

### User Story 2 - Recover from a failure without losing the view (Priority: P1)

A drawing failure ends the session with a message, the saved view on disk is unchanged, and a new session opens with
it. Stored files of every kind (current, older, newer, damaged) open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** a saved view, **When** a draw fails, **Then** the session fails, the file is byte for byte unchanged,
   and a new session opens with the view.
2. **Given** committed samples (schema 2, schema 1, newer, damaged), **Then** schema 2 and 1 open (1 migrated);
   newer and damaged leave the opening view.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text claims only what a test proves, carries no diagnostic, treatment, accuracy or certification wording,
and the release checklist lists every required result: verified, pending the device campaign, or owner action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text and the interface's words, **Then** no refused word appears, and every claim names a
   test that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - The interface works in the app (Priority: P2)

In the one app, the experience opens, is explored through its controls (layers, list selection, search, isolate,
camera) and draws. Its interface tests run in a chunk of their own.

**Why this priority**: interface evidence at the release gate.

**Independent Test**: run the experience's interface tests on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **Then** choosing a part from the list selects it, the panel shows its text and the review
   lines, and the About row shows the model statement.
2. **Given** a search for "ACL", **Then** its result selects the anterior cruciate ligament.
3. **Given** the bones layer switched off, **Then** the bones rows are marked hidden.

### Edge Cases

- **A sample file of a schema not yet written:** refused as newer.
- **Copy that names a feature not in the build** (for example in-scene labels on a canvas too small): the copy says
  labels may be skipped and the list names every part.
- **An interface test that would need a device feature:** none; device rows wait for the campaign.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A17-601**: A privacy-and-credits page MUST list the stored file, its place and deletion, "nothing is sent",
  and the license inventory: pack sources, procedural geometry, review record, colours.
- **FR-A17-602**: A source scan MUST find no network, tracking or advertising API in the experience.
- **FR-A17-603**: A drawing failure MUST fail the session with a message, leave the saved view file unchanged, and a
  new session MUST open with it.
- **FR-A17-604**: Committed sample files of view schemas 2 and 1, newer and damaged MUST open or be refused as
  specified.
- **FR-A17-605**: The store text MUST make only claims a named test proves, and the refused words MUST not appear in
  the store text or the interface's words.
- **FR-A17-606**: The release checklist and release.json MUST list every document and result; the release checks
  (experience release and copy claims for A17) MUST pass.
- **FR-A17-607**: The experience's interface tests MUST cover list selection with the panel, search, a layer switch
  and the About row, in their own chunk.

### Key Entities

- **Release checklist**: rows with status (verified, pending-campaign-ii, owner-action) and evidence.
- **Store text claims**: claim and proving test.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A17-601**: 0 network, tracking or advertising uses in the experience's sources.
- **SC-A17-602**: After a drawing failure, the saved view file is unchanged and reopens.
- **SC-A17-603**: 0 refused words; every claim's test exists.
- **SC-A17-604**: The release checks and the interface chunk pass on iOS 27; every unit test runs in under 10 s and
  every interface test in under 60 s.

## Assumptions

- The app's release, privacy manifest and build-and-archive document are shared (`docs/release/`); this phase adds
  the A17 entries and section.

## Traceability

| Source | Requirement |
|---|---|
| Deliverable: privacy/permission strings | FR-A17-601, 602 |
| Deliverable: crash recovery, local data migration | FR-A17-603, 604 |
| Deliverable: asset/credit review | FR-A17-601 |
| Gate: checklist and inventory complete | FR-A17-606 |
| Gate: tests have results | FR-A17-606, 607 |
| Gate: unsupported features removed from copy | FR-A17-605 |
| Contract G-RELEASE | FR-A17-601–607 |

## Negative Requirements

- No measured performance claim, no device result claimed, no signing, archive or upload by the engineer.
- No diagnostic, treatment, accuracy or certification wording; no clinical review claim.
