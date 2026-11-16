# Feature Specification: Molecular Explorer — Phase 06 Final verification, privacy, packaging and release

**Feature Branch**: `115-me-p06-release` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A15-P06 (legacy ledger) · ID namespace FR-A15-6##, SC-A15-6##, T-A15-6##

**Input**: User description: archived manual `apps/15-molecular-explorer.md` §9 Phase 06 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 06):** the release checklist and artifact inventory are complete; every required
  automated test has attached results and every device test is planned for the device campaign; unsupported promised
  features are removed from interface and store copy.
- **Inapplicable parts** (ADR-0009): the per-app store listing, pricing and release dossier; the store text here is the
  experience's entry in the single app's listing. Quality, privacy, accessibility and regression gates stand.
- **Device work** waits for ImplementationLock-100 and is planned here as device-campaign rows; signing, archive and
  upload are owner actions.
- **Owner rulings:** short tests; audits in the device campaign; iOS 27 at phase gates; reference regression and iOS 26
  at X-A15; every Spec Kit step runs. Follow `specs/108-sse-p06-release`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Nothing leaves the device (Priority: P1) 🎯

The owner can show that Molecular Explorer asks for no permission, reads only the file the person picks, sends
nothing anywhere, stores only its own small files and session state in the app, and credits every data source.

**Why this priority**: privacy and licensing gates of the release.

**Independent Test**: scan the sources; read the privacy and credits note; run the privacy-manifest and no-tracking
checks.

**Acceptance Scenarios**:

1. **Given** the experience's sources, **When** scanned, **Then** no network, tracking, sensor or recording use is found
   and no usage string is added.
2. **Given** the note, **Then** it states what is stored (recent list, settings, the imported copy and its title, the
   session state), where, how to delete it, and credits PubChem and the covalent and van der Waals radius sources with
   their licenses.

---

### User Story 2 - Saved data and failures are handled (Priority: P1)

Damaged, newer or oversized stored files are refused without harm; older saved sessions open; a drawing failure fails
the session safely and a reopen draws normally with the stored files untouched.

**Why this priority**: local data migration and crash recovery gates.

**Independent Test**: load committed sample files of each form; force a drawing failure; reopen.

**Acceptance Scenarios**:

1. **Given** committed sample recent, settings and import files (valid, newer, damaged, oversized), **When** opened,
   **Then** each loads or is refused as specified and the file stays byte-identical.
2. **Given** a forced drawing failure while a molecule is imported, **Then** the session fails, the stored files are
   unchanged, and a new session draws the same molecule.
3. **Given** saved sessions of schemas 1 to 3, **Then** each opens in schema 4.

---

### User Story 3 - Truthful release documents (Priority: P1)

The owner has a release checklist with an artifact inventory, store text whose every claim names a proving test, the
device plan, known limitations and build instructions; no copy claims precision, measured performance or a chemical
safety, toxicity or medical fact.

**Why this priority**: the phase's release gate and the no-fabricated-claims rule.

**Independent Test**: run the release-document and copy-claim checks.

**Acceptance Scenarios**:

1. **Given** the release documents, **When** checked, **Then** the release-document check passes and every store claim
   has a test.
2. **Given** the store text and interface copy, **Then** no word implies measured accuracy, simulation of chemistry or
   measured performance.

---

### User Story 4 - The interface works end to end (Priority: P2)

Interface tests in the app open Molecular Explorer, choose a molecule from the library, switch the display mode, select
an atom, open a recent molecule and change the label setting, each in under 60 seconds.

**Why this priority**: the release's interface regression.

**Independent Test**: run the interface chunk on iOS 27.

**Acceptance Scenarios**:

1. **Given** the app on iOS 27, **When** the interface tests run, **Then** each passes in under 60 seconds without
   presenting the document picker.

### Edge Cases

- **No recent molecules yet:** the Recent menu says so.
- **A drawing failure right after an import:** the stored copy is unchanged and the reopened session shows the import.
- **A stored file for an unknown molecule:** dropped from the list when read.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A15-601**: Molecular Explorer MUST request no permission and add no usage string.
- **FR-A15-602**: The experience's sources MUST contain none of the scanned network, tracking, sensor, recording,
  brightness or idle-timer uses.
- **FR-A15-603**: The app's privacy manifest MUST cover every required-reason use the experience makes.
- **FR-A15-604**: A privacy and credits note MUST state what is stored and where, that only the picked file is read and
  nothing is sent, how to delete it, and credit every bundled data source with its license.
- **FR-A15-610**: Committed sample recent, settings and import files of each form MUST load or be refused as specified,
  refused files staying byte-identical.
- **FR-A15-611**: A forced drawing failure (test-only seam) MUST fail the session with the stored files unchanged, and a
  reopen MUST draw normally.
- **FR-A15-612**: Saved sessions of schemas 1 to 3 MUST open in schema 4 (stored examples).
- **FR-A15-620**: A release checklist with an artifact inventory, store text with a claim → test table, the device plan
  and a release configuration MUST exist and pass the release-document check; its `owner-action` rows are the signing
  set-up, the archive and its upload, recorded as BLOCKED_OWNER_ACTION and never done by the agent; its
  `pending-campaign-ii` rows name the device-campaign rows.
- **FR-A15-621**: The shared copy-claim check MUST pass on the store text and the interface copy, and the experience's
  own scan MUST refuse accuracy, simulation, safety, medical and measured-performance words.
- **FR-A15-622**: Known limitations MUST list the device-only items, the five-molecule library, the bond-inference rule
  and the import limits.
- **FR-A15-623**: The checklist MUST list the accessibility facts proved so far and the audits pending for devices.
- **FR-A15-630**: Interface tests on iOS 27 MUST cover choosing a library molecule, a display-mode switch, an atom
  selection, a recent molecule and the label setting, each under 60 s, in their own chunk.
- **FR-A15-631**: The release build checks MUST pass.
- **FR-A15-632**: The experience's package tests MUST pass on iOS 27.

### Key Entities

- **Release checklist row**: item, area, status (verified, pending device campaign, owner action), evidence or steps.
- **Store claim**: text and its proving test.
- **Sample stored file**: kind (recent, settings, import), form (valid, newer, damaged, oversized), expected answer.
- **Device campaign row**: id, device, what a person checks, pass rule.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A15-601**: 0 permission requests and 0 scanned uses in the experience's sources.
- **SC-A15-602**: 100 % of sample files answer as specified and stay byte-identical when refused.
- **SC-A15-603**: The release-document and copy-claim checks pass; 100 % of store claims name a test.
- **SC-A15-604**: Every interface test passes in under 60 s on iOS 27; the release build checks pass.
- **SC-A15-605**: The runner's standard scenarios pass on iOS 27; every package test runs in under 10 s.

## Assumptions

- The experience and its review documents of A15-P01 to A15-P05 exist; the release tools (`check_experience_release.py`,
  `check_copy_claims.py`, the release build checks) discover the experience from its release configuration.

## Traceability

| Source | Requirement |
|---|---|
| Phase 06: privacy and permission strings | FR-A15-601–604 |
| Phase 06: local data migration and crash recovery | FR-A15-610–612 |
| Phase 06: store asset and credit review, no fabricated claims | FR-A15-620–623 |
| Phase 06: CPU/GPU/device tests, build and archive | FR-A15-630–632, device-campaign.md |

## Negative Requirements

- No per-app listing or pricing; no measured performance claims; no device runs before ImplementationLock-100; no
  owner-only action taken (signing, upload, App Store Connect); no interface test presents the document picker.
