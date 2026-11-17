# Feature Specification: Living Wallpapers — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `143-lw-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A19-P06 (legacy ledger) · ID namespace FR-A19-6##, SC-A19-6##, T-A19-6##

**Input**: User description: archived manual `apps/19-living-wallpapers.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **ADR-0009:** A19 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable, and the experience's release documents feed the app's release. Its quality, privacy, accessibility
  and regression gates stand.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy (no wallpaper setting, no live
    wallpaper, no short video in version 0.1).
- **Gap built here:** G-RELEASE of `docs/apps/living-wallpapers/visualcore-contract.json`:
  - the privacy page: the session snapshot, `history.json` and the temporary export folder, the add-only Photos usage
    string used only by the system share sheet's Save Image;
  - the license inventory;
  - no wallpaper-setting, live-wallpaper or measured-performance claim;
  - the source scan (no network, tracking, sensor or Photos library API);
  - crash recovery, stored-file samples, and the experience-release and copy-claims steps.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/136-ac-p06-release`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device unless the person shares it (Priority: P1) 🎯

A reviewer reads one page: what Living Wallpapers stores (its editor settings in the session snapshot and the export
history), where and how to delete them; that an exported file stays in a temporary folder until the person shares it;
that it sends nothing over the network; that the only permission is the add-only Photos prompt, asked by the system
when the person chooses Save Image; and where every scene, preset and template comes from.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; run the source scan.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored data and its removal, the temporary export file, says nothing is
   sent, states the add-only Photos string and when it is asked, and lists the licenses.
2. **Given** the experience's sources, **Then** no network, tracking, sensor or Photos library API appears.

---

### User Story 2 - Recover without losing the history (Priority: P1)

A drawing failure ends the session with a message; the history file is unchanged; a new session opens with the
history listed. Stored files of every kind open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** a stored history, **When** a draw fails, **Then** the session fails, the history file is byte for byte
   unchanged, and a new session opens and lists it.
2. **Given** committed samples of the snapshot (schemas 1 and 2, newer, damaged) and of the history file (current,
   newer, damaged), **Then** current and older open (older migrated) and newer and damaged are refused without a
   crash, every file byte-identical afterwards.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text claims only what a test proves and never says the app sets, installs or animates a wallpaper, or gives
a measured speed; the release checklist lists every result as verified, pending the device campaign, or an owner
action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text and the interface's words, **Then** no refused word appears and every claim names a test
   that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - The history works in the app (Priority: P2)

In the one app, an export is listed in the history and "Clear history" empties it.

**Why this priority**: interface evidence at the release gate.

**Independent Test**: the interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **When** an export is written and the history is cleared, **Then** the history lists
   the export and then lists nothing.

### Edge Cases

- **A sample of a schema not yet written:** refused as newer.
- **Copy that implies the app applies the wallpaper:** refused; the copy says the person sets it in Settings.
- **The person declines the Photos prompt:** Save to Files still works; the copy promises nothing about Photos access.
- **A device-only check:** pending the campaign, never claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A19-601**: A privacy-and-credits page MUST list the stored data (snapshot, `history.json`), its place and
  removal, the temporary export file, "nothing is sent", the add-only Photos string and when it is asked, and the
  license inventory.
- **FR-A19-602**: A source scan MUST find no network, tracking, sensor or Photos library API in the experience.
- **FR-A19-603**: A drawing failure MUST fail the session with a message, leave the history file unchanged, and a new
  session MUST open and list the history.
- **FR-A19-604**: Committed samples of the snapshot and the history file MUST open or be refused as specified.
- **FR-A19-605**: The store text MUST make only claims a named test proves; refused words MUST not appear in the store
  text or the interface's words.
- **FR-A19-606**: The release checklist and release.json MUST list every document and result; the experience-release
  and copy-claims steps for A19 MUST pass. The device rows MUST be `pending-campaign-ii` and name their campaign rows
  LW-D1 … LW-D8 of `docs/apps/living-wallpapers/device-campaign.md`.
- **FR-A19-607**: The interface tests MUST cover an export listed in the history and the history cleared, in the A19
  chunk.

### Key Entities

- **Release checklist**: rows with status (verified, pending-campaign-ii, owner-action) and evidence.
- **Store text claims**: claim and proving test.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A19-601**: 0 refused uses in the experience's sources.
- **SC-A19-602**: After a drawing failure, the history file is unchanged and the experience reopens with it.
- **SC-A19-603**: 0 refused words; every claim's test exists.
- **SC-A19-604**: The release checks and the interface chunk pass on iOS 27; unit tests under 10 s, interface tests
  under 60 s each.

## Assumptions

- The app's release, privacy manifest and build-and-archive documents are shared (`docs/release/`); this phase adds the
  A19 entries and section.
- The add-only Photos usage string already exists in the app (A19-P04) and is unchanged.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06 deliverable: privacy and permission strings, credits, data migration, crash recovery, build and archive | FR-A19-601–604, 606 |
| Phase 06 deliverable: accessibility, CPU/GPU/device tests | FR-A19-606 (LW-D1 … LW-D8), SC-A19-604 |
| Gate: release checklist and inventory complete | FR-A19-606 |
| Gate: automated results attached, device tests planned | FR-A19-606, SC-A19-604 |
| Gate: unsupported promises removed | FR-A19-605 |
| Contract G-RELEASE | FR-A19-601–607 |

## Negative Requirements

- No fabricated measurement; no claim that the app sets, installs or animates a wallpaper; no video claim; no
  permission beyond the add-only Photos string; no signing, archive or upload by the engineer.
