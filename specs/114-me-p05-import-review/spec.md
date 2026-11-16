# Feature Specification: Molecular Explorer — Phase 05 Import fuzz/error and scientific review

**Feature Branch**: `114-me-p05-import-review` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A15-P05 (legacy ledger) · ID namespace FR-A15-5##, SC-A15-5##, T-A15-5##

**Input**: User description: archived manual `apps/15-molecular-explorer.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — small XYZ file import with strict bounds and parser errors; regression
  fixture — switching molecules and restoring the orientation do not leak buffers; graphics context ownership stays
  solely in the audited VisualCore host.
- **Gaps built here** (contract `docs/apps/molecular-explorer/visualcore-contract.json`): G-IMPORT (an XYZ file chosen
  in the system document picker, checked for size before reading, parsed strictly, copied into the experience's own
  storage, shown as a molecule, refused with a visible reason) and G-REVIEW (a provenance and wording review of every
  bundled value and every displayed sentence). Release work stays for A15-P06.
- **The import enters the engine as ordinary actions**, as Digital Aquarium reopens a saved aquarium: the engine stays
  deterministic and replayable, and the import is part of its saved state.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A15; every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open my own molecule file (Priority: P1) 🎯

A person chooses a small XYZ file from Files and sees the molecule drawn like a library molecule, with its atoms,
inferred bonds, labels and panel; the molecule is kept and returns when the experience is opened again.

**Why this priority**: the phase's MVP and the v0.1 feature "small XYZ import".

**Independent Test**: import a valid fixture file; read the panel; leave and reopen.

**Acceptance Scenarios**:

1. **Given** a valid XYZ file within the limits, **When** it is chosen, **Then** the molecule is shown with its atom and
   inferred bond counts, its title from the file name, and "Source: imported file — your own data".
2. **Given** an imported molecule, **When** the experience is reopened, **Then** the same molecule is shown and it is
   in the recent list.
3. **Given** an imported molecule, **When** a library molecule is chosen and the imported one is chosen again from the
   recent list, **Then** it is shown again.

---

### User Story 2 - Understand why a file was refused (Priority: P1)

A person who picks a file that is too large, not text, malformed or beyond the limits sees one sentence saying why;
nothing they had changes.

**Why this priority**: the phase's MVP "strict bounds and parser errors".

**Independent Test**: choose each refusal fixture; read the message; compare the state and storage before and after.

**Acceptance Scenarios**:

1. **Given** a file larger than the size limit, **When** it is chosen, **Then** it is refused before it is read, with
   the message naming the limit.
2. **Given** a file with any parser refusal, **When** it is chosen, **Then** the message names the reason and the line,
   and the shown molecule, the stored import and the recent list are unchanged.

---

### User Story 3 - Malformed files never break the experience (Priority: P2)

The engineer can trust the importer with any bytes: a large seeded corpus of mutated files is refused or accepted
without a crash, and accepted results stay within the limits.

**Why this priority**: the phase's fuzz and error corpus.

**Independent Test**: run the seeded corpus; count crashes and limit violations.

**Acceptance Scenarios**:

1. **Given** a seeded corpus of mutated XYZ files, **When** each is imported, **Then** none crashes, every refusal has a
   typed reason, and every accepted molecule is within the atom, coordinate and distance limits.

---

### User Story 4 - Everything shown is sourced and stated plainly (Priority: P2)

A reviewer reads a generated review of every bundled value and every sentence the experience shows, and finds a source,
units and license for each value, the display conventions stated, and no safety, toxicity, medical or therapeutic
claim.

**Why this priority**: the scientific review of the phase.

**Independent Test**: generate the review document; compare it with the committed one; search the words.

**Acceptance Scenarios**:

1. **Given** the bundled elements and molecules, **When** the review is generated, **Then** every displayed value names
   its source, units and license, and the document matches the committed review byte for byte.
2. **Given** every sentence the experience shows, **When** it is checked, **Then** none contains a forbidden claim word,
   and the inferred-bond and display-convention statements are present.

---

### User Story 5 - Switching and restoring do not leak (Priority: P2)

Switching molecules many times, importing, and restoring the saved orientation leave the drawing resources at the same
count as after the first molecule.

**Why this priority**: the phase's regression fixture.

**Independent Test**: switch, import and restore in a loop on the off-screen renderer; read the resource counts.

**Acceptance Scenarios**:

1. **Given** the experience after its first frame, **When** every molecule is chosen in turn, a file is imported and the
   saved state is restored, ten times, **Then** the live mesh, program and buffer counts equal those after the first
   frame.

### Edge Cases

- **A second import:** it replaces the first; there is one imported molecule at a time.
- **The stored import file is missing or damaged at reopening:** the saved state's molecule is still shown (it is in the
  saved state); the stored copy is rewritten at the next import; nothing crashes.
- **An imported molecule in the recent list after a newer import:** the entry stands for the current import.
- **Picking is cancelled:** nothing changes and no message is shown.
- **The file cannot be read (no access, removed meanwhile):** refused with "The file could not be read." and nothing
  changes.
- **A file whose comment line holds markup or very long text:** the comment is never shown as a title; the title comes
  from the file name, shortened to a fixed length.
- **A file name with unusual characters:** the title shows letters, digits, spaces and simple punctuation only.
- **An atom pair too close, an unknown element, non-finite numbers, too many atoms:** each refused with its own reason.

## Requirements *(mandatory)*

### Functional Requirements

**Import (stories 1–2)**

- **FR-A15-501**: The experience MUST let a person choose a plain-text XYZ file through the system document picker,
  with no permission and no usage description.
- **FR-A15-502**: A file larger than the size limit MUST be refused before its contents are read.
- **FR-A15-503**: A file within the limit MUST be parsed strictly with the existing parser rules; any refusal MUST show
  one sentence naming the reason (and line where there is one) and MUST change neither the shown molecule, nor the stored
  import, nor the recent list.
- **FR-A15-504**: An accepted file MUST be copied into the experience's own storage, replacing any earlier import, and
  MUST enter the engine as ordinary actions so it is part of the saved state, replays and digests.
- **FR-A15-505**: The imported molecule MUST be drawn, picked, labelled and described like a library molecule, with
  inferred bonds marked inferred, a title from the file name and the source "imported file — your own data".
- **FR-A15-506**: The imported molecule MUST join the recent list and return after reopening.

**Fuzz (story 3)**

- **FR-A15-510**: A seeded corpus of mutated files MUST import without a crash, with a typed refusal for every refused
  file and every accepted molecule within the limits.

**Review (story 4)**

- **FR-A15-520**: A generated review document MUST list every bundled displayed value with its source, units and
  license, and MUST match the committed document.
- **FR-A15-521**: No sentence the experience shows MUST contain a safety, toxicity, medical or therapeutic claim word;
  the inferred-bond statement and the display-convention statement MUST be present.

**Resources (story 5)**

- **FR-A15-530**: Switching molecules, importing and restoring MUST NOT grow the live drawing resources beyond their
  count after the first frame.

**Experience**

- **FR-A15-540**: The import control MUST have an accessible label, value and hint; the runner's standard scenarios
  MUST pass on iOS 27.

### Key Entities

- **Imported molecule**: atoms (element and position in ångström), inferred bonds, title from the file name, source
  "imported file".
- **Stored import**: the accepted file's bytes in the experience's own storage, at most the size limit.
- **Refusal message**: one sentence with the reason and, where known, the line.
- **Review document**: per displayed value its source, units and license; the convention statements.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A15-501**: Each valid fixture imports and shows the expected atom and bond counts; it is shown again after
  reopening.
- **SC-A15-502**: Each refusal fixture (one per parser reason plus the size limit) shows its sentence and leaves state
  and storage byte-identical.
- **SC-A15-503**: A seeded corpus of at least 2,000 mutated files gives zero crashes and zero limit violations.
- **SC-A15-504**: The generated review matches the committed review; zero forbidden words in shown sentences.
- **SC-A15-505**: After ten rounds of switching, importing and restoring, resource counts equal the first frame's.
- **SC-A15-506**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The parser of A15-P01 (size, atom, line, coordinate and distance limits with twelve typed refusals) is the importer's
  rule set; no limit changes.
- The system document picker needs no permission; nothing here raises a system prompt.
- One imported molecule at a time is enough for version 0.1.

## Traceability

| Source | Requirement |
|---|---|
| Phase 05 MVP: small XYZ file import with strict bounds and parser errors | FR-A15-501–506, SC-A15-501, 502 |
| Phase 05 fuzz and error corpus | FR-A15-510, SC-A15-503 |
| Phase 05 scientific review | FR-A15-520, 521, SC-A15-504 |
| Regression fixture: model switch and orientation restore do not leak buffers | FR-A15-530, SC-A15-505 |
| Contract gaps G-IMPORT, G-REVIEW | FR-A15-501–521 |
| EGL/context ownership in the VisualCore host | FR-A15-540 |

## Negative Requirements

- No network, account, sync, permission prompt or usage description; no storage outside the experience's own folder; no
  file read before its size is checked; no comment text shown as a title; no claim about safety, toxicity, medicine or
  therapy; no change to the library's data.
