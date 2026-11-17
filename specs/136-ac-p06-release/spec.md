# Feature Specification: Ambient Clock — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `136-ac-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A18-P06 (legacy ledger) · ID namespace FR-A18-6##, SC-A18-6##, T-A18-6##

**Input**: User description: archived manual `apps/18-ambient-clock.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **ADR-0009:** A18 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable, and the experience's release documents feed the app's release. Its quality, privacy, accessibility
  and regression gates stand.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy.
- **Gap built here:** G-RELEASE of `docs/apps/ambient-clock/visualcore-contract.json`:
  - the privacy page, including the opt-in keep-awake and its one named file;
  - the license inventory;
  - no accuracy, always-on, battery, weather or measured-performance claims;
  - the source scan (idle timer only in `KeepAwake.swift`, no brightness write, no network);
  - crash recovery, stored-file samples, and the experience-release and copy-claims steps.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/129-ia-p06-release`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device and everything is disclosed (Priority: P1) 🎯

A reviewer reads one page: what the clock stores (its settings and favourites), where and how to delete them; that it
sends nothing and needs no permission; that it can keep the screen on only when the person turns that on; and where
every theme and palette comes from.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; run the source scan.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored data and its removal, says nothing is sent and no permission is
   asked, states the keep-awake rule, and lists the licenses.
2. **Given** the experience's sources, **Then** no network, tracking, sensor or brightness API appears, and the idle
   timer appears only in the one named file.

---

### User Story 2 - Recover without losing settings or favourites (Priority: P1)

A drawing failure ends the session with a message; the favourites file is unchanged; a new session opens with the
settings. Stored files of every kind open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** saved favourites, **When** a draw fails, **Then** the session fails, the favourites file is byte for byte
   unchanged, and a new session opens.
2. **Given** committed samples of the snapshot (schemas 1, 2, 3, newer, damaged) and of the favourites file (current,
   newer, damaged), **Then** current and older open (older migrated) and newer and damaged are refused without a
   crash, every file byte-identical afterwards.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text claims only what a test proves and makes no accuracy, always-on, battery or weather claim; the release
checklist lists every result as verified, pending the device campaign, or an owner action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text and the interface's words, **Then** no refused word appears and every claim names a test
   that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - The interface works in the app (Priority: P2)

In the one app, the clock opens, a theme is chosen and a favourite saved through the controls.

**Why this priority**: interface evidence at the release gate.

**Independent Test**: the interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **When** a theme is picked and saved as a favourite, **Then** the favourite is listed and
   applies.

### Edge Cases

- **A sample of a schema not yet written:** refused as newer.
- **Copy that implies the screen stays on:** refused; the copy says the person may choose to keep it on while the
  clock is open.
- **A device-only check:** pending the campaign, never claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A18-601**: A privacy-and-credits page MUST list the stored data, its place and removal, "nothing is sent", no
  permission, the keep-awake rule and its one named file, and the license inventory.
- **FR-A18-602**: A source scan MUST find no network, tracking, sensor or brightness API in the experience, and the
  idle timer only in `Experience/KeepAwake.swift`.
- **FR-A18-603**: A drawing failure MUST fail the session with a message, leave the favourites file unchanged, and a
  new session MUST open.
- **FR-A18-604**: Committed samples of the snapshot and favourites file MUST open or be refused as specified.
- **FR-A18-605**: The store text MUST make only claims a named test proves; refused words MUST not appear in the store
  text or the interface's words.
- **FR-A18-606**: The release checklist and release.json MUST list every document and result; the experience-release
  and copy-claims steps for A18 MUST pass.
- **FR-A18-607**: The interface tests MUST cover picking a theme and saving and applying a favourite, in the A18 chunk.

### Key Entities

- **Release checklist**: rows with status (verified, pending-campaign-ii, owner-action) and evidence.
- **Store text claims**: claim and proving test.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A18-601**: 0 refused uses in the experience's sources; the idle timer in exactly one file.
- **SC-A18-602**: After a drawing failure, the favourites file is unchanged and the clock reopens.
- **SC-A18-603**: 0 refused words; every claim's test exists.
- **SC-A18-604**: The release checks and the interface chunk pass on iOS 27; unit tests under 10 s, interface tests
  under 60 s each.

## Assumptions

- The app's release, privacy manifest and build-and-archive documents are shared (`docs/release/`); this phase adds the
  A18 entries and section.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06 deliverable: privacy, credits, data migration, crash recovery, build and archive | FR-A18-601–604, 606 |
| Gate: release checklist and inventory complete | FR-A18-606 |
| Gate: automated results attached, device tests planned | FR-A18-606, SC-A18-604 |
| Gate: unsupported promises removed | FR-A18-605 |
| Contract G-RELEASE | FR-A18-601–607 |

## Negative Requirements

- No fabricated measurement; no accuracy beyond the system clock, always-on, battery or weather claim; no permission;
  no signing, archive or upload by the engineer.
