# Feature Specification: Shader Studio — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `164-ss-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-18

**Status**: Draft

**Ledger gate**: A22-P06 (legacy ledger) · ID namespace FR-A22-6##, SC-A22-6##, T-A22-6##

**Input**: User description: archived manual `apps/22-shader-studio.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **ADR-0009:** A22 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable; the experience's release documents feed the app's release. Its quality, privacy, accessibility and
  regression gates stand.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy: no sandbox or safety claim for GPU code,
    no Shadertoy, WebGL or desktop GLSL compatibility, no sharing, upload or export, no measured speed.
- **Gap built here:** G-RELEASE of `docs/apps/shader-studio/visualcore-contract.json` (the A22 copy-claims and
  experience-release steps and the release documents); its iOS 26.x runner half is cited at X-A22.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/157-au-p06-release`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

A reviewer reads one page: what Shader Studio stores (the open session in the snapshot, and the named projects of the
library), where and how they are removed; that it sends nothing over the network; that it asks for no permission;
that a person's shaders run on the device's graphics processor without any claim of a sandbox; and that every
template and texture is made in code.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; run the source scan.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored data and its removal, says nothing is sent and no permission is
   asked, says GPU code is not sandboxed, and lists the licences.
2. **Given** the experience's sources, **Then** no network, location, tracking, sensor, microphone, camera, photo,
   contact, idle-timer or brightness API appears.

---

### User Story 2 - Recover without losing the projects (Priority: P1)

A drawing failure ends the session with a message; the saved projects are unchanged; a new session opens and lists
them. Stored files of every kind open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** saved projects, **When** a draw fails, **Then** the session fails with a message, every stored file is
   byte for byte unchanged, and a new session lists and opens them.
2. **Given** committed samples of the snapshot, a project file and the library index (current, newer, damaged),
   **Then** current samples open and newer and damaged ones are refused without a crash, every file byte-identical
   afterwards.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text claims only what a test proves and never claims a sandbox, safety for any shader, compatibility with
another shader site or language, sharing, or a measured speed or battery figure; the release checklist lists every
result as verified, pending the device campaign, or an owner action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text and the interface's words, **Then** no refused word appears and every claim names a test
   that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - A first session in the app (Priority: P2)

In the one app, a first session opens on the Gradient template, compiled, with no diagnostics, an empty library and
the inspector showing the template's uniform.

**Why this priority**: interface evidence at the release gate (first-session flow).

**Independent Test**: the A22 interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **Then** the status reads "Compiled", no diagnostic is listed, the library is empty, and
   the inspector lists one uniform.

### Edge Cases

- **A sample of a schema not yet written:** refused as newer.
- **Copy that implies GPU code is safe or isolated:** refused; the copy says GPU code is not a sandbox.
- **Copy that names a shader website or another language as compatible:** refused.
- **A damaged library index:** projects are still listed from their files; the index is rebuilt by the next change,
  never by reading.
- **A device-only check:** pending the campaign, never claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A22-601**: A privacy-and-credits page MUST list the stored data (snapshot, named projects and their index), its
  place (the experience's own storage), its removal (by the person in the library, or when the app is deleted),
  "nothing is sent", "no permission is asked", "GPU code is not a sandbox", and the licence inventory.
- **FR-A22-602**: A source scan MUST find no network, location, tracking, sensor, microphone, camera, photo, contact,
  idle-timer or brightness API in the experience.
- **FR-A22-603**: A drawing failure MUST fail the session with a message, leave every stored file unchanged, and a new
  session MUST list and open the saved projects.
- **FR-A22-604**: Committed samples of the snapshot, a project file and the library index MUST open or be refused as
  specified, and stay byte-identical after reading.
- **FR-A22-605**: The store text MUST make only claims a named test proves; refused words MUST not appear in the store
  text or the interface's words.
- **FR-A22-606**: The release checklist and release.json MUST list every document and result, and
  `docs/release/known-limitations.md` MUST gain an A22 section (no sandbox, GLSL ES 3.00 fragment shaders only, no
  sharing or export, device rows pending); the experience-release and copy-claims steps for A22 MUST pass. The device
  rows MUST be `pending-campaign-ii` and name their campaign rows SS-D1 … SS-D6 of
  `docs/apps/shader-studio/device-campaign.md`.
- **FR-A22-607**: The interface tests MUST cover the first-session defaults in the A22 chunk.

### Key Entities

- **Release checklist**: rows with status (verified, pending-campaign-ii, owner-action) and evidence.
- **Store text claims**: claim and proving test.
- **Sample files**: committed stored values with their expected outcome (opens, refused with a code).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A22-601**: 0 refused uses in the experience's sources.
- **SC-A22-602**: After a drawing failure, every stored file is unchanged and the experience reopens with the projects.
- **SC-A22-603**: 0 refused words; every claim's test exists.
- **SC-A22-604**: The release checks and the interface chunk pass on iOS 27; unit tests under 10 s, interface tests
  under 60 s.

## Assumptions

- The A22-P01 to P05 work is reused; no new capability is added.
- The release build checks of `scripts/release_check.py` read `docs/apps/shader-studio/release.json` like Aurora's.

## Traceability

| Source | Requirement |
|---|---|
| Release checklist and artifact inventory complete | FR-A22-606 |
| Automated and device tests have attached results | FR-A22-606, SC-A22-604 |
| Unsupported promised features removed from UI and copy | FR-A22-605, SC-A22-603 |
| Privacy/permission strings, App Store asset/credit review | FR-A22-601, 602 |
| Local data migration, crash recovery | FR-A22-603, 604 |
| Contract G-RELEASE | FR-A22-601–607 |

## Negative Requirements

- No VisualCore or ProjectM change; no new feature; no device run before `ImplementationLock-100`; no fabricated
  measurement; no sandbox claim; no owner-only step done by the agent.
