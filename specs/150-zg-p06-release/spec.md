# Feature Specification: Digital Zen Garden — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `150-zg-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-17

**Status**: Draft

**Ledger gate**: A20-P06 (legacy ledger) · ID namespace FR-A20-6##, SC-A20-6##, T-A20-6##

**Input**: User description: archived manual `apps/20-digital-zen-garden.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **ADR-0009:** A20 is an experience inside the one VisualCore app. A per-app store listing, pricing and dossier are
  inapplicable, and the experience's release documents feed the app's release. Its quality, privacy, accessibility
  and regression gates stand.
- **Phase gates (manual §9 Phase 06):**
  - the release checklist and the artifact inventory are complete;
  - every required automated test has attached results, and device tests are planned for the device campaign
    (pending-campaign-ii, after ImplementationLock-100);
  - unsupported promised features are removed from the interface and the copy (no granular sand physics, no online
    gallery, no therapeutic or wellbeing claim).
- **Gap built here:** G-RELEASE of `docs/apps/digital-zen-garden/visualcore-contract.json`:
  - the privacy page: the session snapshot, the named-garden library, the calm switches and the temporary still file,
    and the add-only Photos usage string used only by the system share sheet's Save Image;
  - the license inventory;
  - no physics, therapeutic, medical, wellbeing or unmeasured performance claim (the experience's claims scan and the
    shared copy check);
  - the source scan (no network, tracking, sensor or Photos library API);
  - crash recovery, stored-file samples, and the experience-release and copy-claims steps.
- **Owner-only:** signing, archive and upload stay `BLOCKED_OWNER_ACTION`, with the steps of
  `docs/release/build-and-archive.md`.
- Follow `specs/143-lw-p06-release`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device unless the person shares it (Priority: P1) 🎯

A reviewer reads one page: what Digital Zen Garden stores (the open garden in the session snapshot, the named gardens
of its library, the calm switches), where and how to delete them; that a still picture stays in a temporary folder
until the person shares it; that it sends nothing over the network; that the only permission is the add-only Photos
prompt, asked by the system when the person chooses Save Image; and that every sand, rake and stone shape is drawn in
code.

**Why this priority**: privacy and credits gate the release.

**Independent Test**: read the privacy-and-credits page; run the source scan.

**Acceptance Scenarios**:

1. **Given** the page, **Then** it names the stored data and its removal, the temporary still file, says nothing is
   sent, states the add-only Photos string and when it is asked, and lists the licenses.
2. **Given** the experience's sources, **Then** no network, tracking, sensor or Photos library API appears.

---

### User Story 2 - Recover without losing the gardens (Priority: P1)

A drawing failure ends the session with a message; the saved gardens are unchanged; a new session opens with the
library listed. Stored files of every kind open or are refused as specified.

**Why this priority**: crash recovery and local data migration.

**Independent Test**: inject a drawing failure; reopen; open committed sample files.

**Acceptance Scenarios**:

1. **Given** saved gardens, **When** a draw fails, **Then** the session fails with a message, every library file is
   byte for byte unchanged, and a new session opens and lists the gardens.
2. **Given** committed samples of the snapshot, of a saved garden and of the library index (current, newer, damaged),
   **Then** current samples open and newer and damaged ones are refused without a crash, every file byte-identical
   afterwards.

---

### User Story 3 - Honest copy and a complete checklist (Priority: P1)

The store text claims only what a test proves and never claims sand physics, a therapeutic, medical or wellbeing
benefit, or a measured speed; the release checklist lists every result as verified, pending the device campaign, or
an owner action.

**Why this priority**: the phase's gates.

**Independent Test**: run the claims scan and the release checks.

**Acceptance Scenarios**:

1. **Given** the store text and the interface's words, **Then** no refused word appears and every claim names a test
   that exists.
2. **Given** the release checklist, **Then** every row has a status and evidence.

---

### User Story 4 - The still and the calm switches work in the app (Priority: P2)

In the one app, a still picture of the garden is made and offered to the share sheet, and the calm switches start off.

**Why this priority**: interface evidence at the release gate.

**Independent Test**: the interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** a fresh start, **Then** the three calm switches are off; **When** a still is made, **Then** its message
   names the PNG and 1600 × 1200, and the share button exists.

### Edge Cases

- **A sample of a schema not yet written:** refused as newer.
- **Copy that implies relaxation as a health effect:** refused; the copy describes what the person does, not an effect.
- **The person declines the Photos prompt:** saving to Files still works; the copy promises nothing about Photos.
- **A damaged library index:** the gardens it cannot list stay on disk and are reported, never deleted.
- **A device-only check:** pending the campaign, never claimed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A20-601**: A privacy-and-credits page MUST list the stored data (snapshot, named gardens and their index, the
  calm switches), its place and removal, the temporary still file (at most one, replaced by the next still and removed
  with the app's temporary data), "nothing is sent", the add-only Photos string and when it is asked, and the license
  inventory.
- **FR-A20-602**: A source scan MUST find no network, tracking, sensor, Photos library, idle-timer or brightness API in
  the experience.
- **FR-A20-603**: A drawing failure MUST fail the session with a message, leave the library files unchanged, and a new
  session MUST open and list the gardens.
- **FR-A20-604**: Committed samples of the snapshot, a saved garden and the library index MUST open or be refused as
  specified.
- **FR-A20-605**: The store text MUST make only claims a named test proves; refused words MUST not appear in the store
  text or the interface's words.
- **FR-A20-606**: The release checklist and release.json MUST list every document and result; the experience-release
  and copy-claims steps for A20 MUST pass. The device rows MUST be `pending-campaign-ii` and name their campaign rows
  ZG-D1 … ZG-D8 of `docs/apps/digital-zen-garden/device-campaign.md`.
- **FR-A20-607**: The interface tests MUST cover the calm switches off at a fresh start and a still made and offered to
  share, in the A20 chunk.

### Key Entities

- **Release checklist**: rows with status (verified, pending-campaign-ii, owner-action) and evidence.
- **Store text claims**: claim and proving test.
- **Sample files**: committed stored files with their expected outcome (opens, migrates, refused with a code).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A20-601**: 0 refused uses in the experience's sources.
- **SC-A20-602**: After a drawing failure, every library file is unchanged and the experience reopens with it.
- **SC-A20-603**: 0 refused words; every claim's test exists.
- **SC-A20-604**: The release checks and the interface chunk pass on iOS 27; unit tests under 10 s, interface tests
  under 60 s each.

## Assumptions

- The app's release, privacy manifest and build-and-archive documents are shared (`docs/release/`); this phase adds the
  A20 entries and section.
- The add-only Photos usage string already exists in the app and is unchanged; A20 already declares the
  `photo-library-add` permission in `Catalog/registrations.json`.
- The sand, rake and stone visuals are procedural; the experience bundles no third-party data.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06 deliverable: privacy and permission strings, credits, data migration, crash recovery, build and archive | FR-A20-601–604, 606 |
| Phase 06 deliverable: accessibility, CPU/GPU/device tests | FR-A20-606 (ZG-D1 … ZG-D8), SC-A20-604 |
| Gate: release checklist and inventory complete | FR-A20-606 |
| Gate: automated results attached, device tests planned | FR-A20-606, SC-A20-604 |
| Gate: unsupported promises removed (non-goals: granular physics, online galleries, AI content) | FR-A20-605 |
| Contract G-RELEASE | FR-A20-601–607 |

## Negative Requirements

- No fabricated measurement; no physics, therapeutic, medical or wellbeing claim; no gallery, account or sharing
  beyond the system share sheet; no permission beyond the add-only Photos string; no signing, archive or upload by the
  engineer.
