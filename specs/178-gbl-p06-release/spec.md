# Feature Specification: Graphics Benchmark Lab — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `178-gbl-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A24-P06 (legacy ledger) · ID namespace FR-A24-6##, SC-A24-6##, T-A24-6##

**Input**: User description: archived manual `apps/24-graphics-benchmark-lab.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **ADR-0009:** A24 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable; the experience's release documents feed the app's release. Its quality, privacy, accessibility and
  regression gates stand. Visuals are code only; the app makes no network request.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy: no device ranking, no published or
    invented benchmark number, no claim of scientific rigour or platform comparison, no frame rate, no upload.
- **Sharing is real here:** the experience exports a saved result as a JSON run file or a CSV through the system share
  sheet, only on the person's tap (A24-P04). The source scan therefore allows the share sheet in the results view only,
  and the copy check allows the word "share".
- **Gap built here:** G-RELEASE of `docs/apps/graphics-benchmark-lab/visualcore-contract.json` (the A24 copy-claims and
  experience-release steps, the privacy and credits, and the release documents); its iOS 26.x runner half is cited at
  X-A24.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/171-vpl-p06-release`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device without the person's tap (Priority: P1) 🎯

A reviewer reads one page: what Graphics Benchmark Lab stores (the selected case in the session snapshot, the saved
results and their index, and the export files written only for the share sheet), where and how they are removed; that
it sends nothing over the network and leaves the device only through an export the person starts; that it asks for no
permission; that it reads no private identifier; and that every workload picture is made in code.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; run the source scan.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored data and its removal, says nothing is sent automatically and no
   permission is asked, describes the export, and lists the licences.
2. **Given** the experience's sources, **Then** no network, location, tracking, sensor, microphone, camera, photo,
   contact, pasteboard, idle-timer or brightness use appears, and the share sheet appears in the results view only.

---

### User Story 2 - Recover without losing the results (Priority: P1)

A drawing failure ends the session with a message; the saved results are unchanged; a new session lists and opens
them. Stored files of every kind open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** saved results, **When** a draw fails, **Then** the session fails with a message, every stored file is byte
   for byte unchanged, and a new session lists and opens them.
2. **Given** committed samples of the session snapshot, a saved result file and the results index (current, newer,
   damaged), **Then** current samples open and newer and damaged ones are refused without a crash, every file
   byte-identical afterwards.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text claims only what a test proves and never claims a ranking, a published or invented benchmark number, a
frame rate, scientific rigour or a platform comparison; the release checklist lists every result as verified, pending
the device campaign, or an owner action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text and the interface's words, **Then** no refused word appears and every claim names a test
   that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - A first session in the app (Priority: P2)

In the one app, a first session opens on the textured quads case, ready to run, with no run qualification shown and an
empty results list.

**Why this priority**: interface evidence at the release gate (first-session flow).

**Independent Test**: the A24 interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **Then** the status reads "Ready", the quads case is selected, no qualification is shown,
   and the saved results list no result.

### Edge Cases

- **A sample of a schema not yet written:** refused as newer.
- **Copy that ranks devices, compares platforms or prints a benchmark number:** refused.
- **Copy that promises an upload, a cloud library or an account:** refused.
- **A damaged results index:** results are still listed from their files; the index is rebuilt by the next change,
  never by reading.
- **A saved result above the file size limit:** refused as too large, the file kept.
- **Export files left behind by a killed session:** removed when the experience opens again.
- **A device-only check (GPU timing, thermal behaviour, repeatability on hardware):** pending the campaign, never
  claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A24-601**: A privacy-and-credits page MUST list the stored data (session snapshot, saved results and their
  index, export files), its place (the experience's own storage; exports in a temporary folder), its removal (by the
  person in the results list, when the session closes for exports, or when the app is deleted), "nothing is sent
  automatically", "no permission is asked", the device facts read from public sources only, and the licence inventory.
- **FR-A24-602**: A source scan MUST find no network, location, tracking, sensor, microphone, camera, photo, contact,
  pasteboard, idle-timer, brightness or private-identifier use in the experience, and the share sheet only in the
  results view.
- **FR-A24-603**: A drawing failure MUST fail the session with a message, leave every stored file unchanged, and a new
  session MUST list and open the saved results.
- **FR-A24-604**: Committed samples of the snapshot, a saved result file and the results index MUST open or be refused
  as specified, and stay byte-identical after reading.
- **FR-A24-605**: The store text MUST make only claims a named test proves; refused words MUST not appear in the store
  text or the interface's words.
- **FR-A24-606**: The release checklist and release.json MUST list every document and result, and
  `docs/release/known-limitations.md` MUST gain an A24 section (three cases, a run of at most the plan's length, at most
  12 saved results, GPU time only where the timer exists, simulator numbers are not device evidence, a hot device ends
  a run, no ranking or comparison, device rows pending); the experience-release and copy-claims steps for A24 MUST pass.
  The device rows MUST be `pending-campaign-ii` and name their campaign rows GBL-D1 … GBL-D6 of
  `docs/apps/graphics-benchmark-lab/device-campaign.md`. Accessibility is listed with its automated evidence as
  `verified`, and the system accessibility audits as `pending-campaign-ii`.
- **FR-A24-607**: The interface tests MUST cover the first-session defaults in the A24 chunk.

### Key Entities

- **Release checklist**: rows with status (verified, pending-campaign-ii, owner-action) and evidence.
- **Store text claims**: claim and proving test.
- **Sample files**: committed stored values with their expected outcome (opens, refused with a code).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A24-601**: 0 refused uses in the experience's sources; the share sheet in exactly one view.
- **SC-A24-602**: After a drawing failure, every stored file is unchanged and the experience reopens with the results.
- **SC-A24-603**: 0 refused words; every claim's test exists.
- **SC-A24-604**: The release checks and the interface chunk pass on iOS 27; unit tests under 10 s, interface tests
  under 60 s.

## Assumptions

- The A24-P01 to P05 work is reused; no new capability is added.
- The release build checks read `docs/apps/graphics-benchmark-lab/release.json` like Visual Programming Lab's.
- The registration's permissions are empty, so no usage string is needed; the share sheet needs none.

## Traceability

| Source | Requirement |
|---|---|
| Release checklist and artifact inventory complete | FR-A24-606 |
| Automated and device tests have attached results (CPU/GPU/device tests) | FR-A24-606, SC-A24-604 |
| Unsupported promised features removed from UI and copy; no fabricated measured claims | FR-A24-605, SC-A24-603 |
| Privacy/permission strings, App Store asset/credit review | FR-A24-601, 602 |
| Accessibility | FR-A24-606, 607 |
| Local data migration, crash recovery | FR-A24-603, 604 |
| Build/archive instructions | FR-A24-606 (owner-action rows) |
| Contract G-RELEASE | FR-A24-601–607 |

## Negative Requirements

- No VisualCore or ProjectM change; no new feature; no device run before `ImplementationLock-100`; no fabricated
  measurement; no ranking, comparison or benchmark number in copy; no owner-only step done by the agent.
