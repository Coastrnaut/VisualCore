# Feature Specification: Molecular Explorer — Phase 04 Curated molecule content and persistence

**Feature Branch**: `113-me-p04-library` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A15-P04 (legacy ledger) · ID namespace FR-A15-4##, SC-A15-4##, T-A15-4##

**Input**: User description: archived manual `apps/15-molecular-explorer.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — element labels, bond types and the metadata panel (built in A15-P03 and
  kept working here); regression fixture — bond inference is deterministic and marked inferred; graphics context
  ownership stays solely in the audited VisualCore host.
- **Gap built here** (contract `docs/apps/molecular-explorer/visualcore-contract.json`): G-LIBRARY (the curated
  library shown with its attributions, the bounded recent-molecules list and the visual settings, each stored with a
  versioned schema). The import and data review stay for A15-P05; release work for A15-P06.
- **Experience:** the candidate grows; no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A15; every Spec Kit step runs.

## Clarifications

### Session 2026-11-16

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`ExperienceStorage.write(_:to:)` replaces a file atomically, `read(_:)`, `exists(_:)` and `remove(_:)` work inside the
experience's own folder; Solar System Explorer's `ViewStore` keeps one small versioned document there with missing,
refused and unreadable results, never writing on a load, and keeps bytes in memory without storage; the recent list and
the settings follow that pattern.

- Q: What are the recent list's cap and file? → A: At most 8 molecule ids, newest first, in `recent.json` (document
  schema 1, sorted keys, at most 2,048 bytes); the molecule opened at start counts as opened; ids not in the library are
  dropped when the list is read.
- Q: What does the settings document hold? → A: `settings.json` (schema 1, at most 1,024 bytes) with the label mode:
  `all` (default), `selected` (only the selected atom's label) or `none`; the selection ring is always drawn when an
  atom is selected.
- Q: How are refusals and failed writes reported? → A: A recent or settings file that is damaged, oversized, of a newer
  schema or out of range is refused with that reason (`damaged`, `oversized`, `newer-version`, `out-of-range`) and left
  byte for byte; the message reads "Recent molecules could not be read (damaged)." or "Settings could not be read
  (damaged); labels are shown for all atoms." A failed write keeps the previous file and reads "Recent molecules could
  not be saved (<storage code>)."
- Q: What are the controls? → A: A Library section listing each molecule as a button with its name, formula, counts
  and "Source: PubChem Compound CID 2519, 3D conformer — public domain" (choosing one sends `molecule.select`); a Recent
  menu (`recent`) listing the recent titles newest first (choosing one sends `molecule.select`; empty → "No recent
  molecules"); a Labels picker (`labels`: All, Selected, None). None of them is an engine action except
  `molecule.select`.
- Q: How is determinism of bond inference proven? → A: For each library molecule, five seeded shuffles of its atoms
  (fixed seeds 1 to 5): the inferred pairs mapped back through the shuffle equal the unshuffled inferred pairs and the
  recorded bonds, every bond is inferred and single, and two runs on the same input give identical lists.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse the library with its sources (Priority: P1) 🎯

A person opens a library list showing every bundled molecule with its name, formula, size and where its structure came
from, and opens any of them from the list.

**Why this priority**: the v0.1 feature "shipping curated small-molecule library with source attributions".

**Independent Test**: open the library list; read every entry; choose one.

**Acceptance Scenarios**:

1. **Given** the library, **When** the list is read, **Then** each molecule shows its name, formula, atom and bond counts
   and its source with the license.
2. **Given** the list, **When** a molecule is chosen, **Then** it opens, as the Molecule menu would open it.

---

### User Story 2 - Return to recent molecules (Priority: P1)

A person finds the molecules they looked at most recently, newest first, and opens one again; the list survives leaving
and reopening the experience.

**Why this priority**: the v0.1 feature "local recent molecules".

**Independent Test**: open several molecules; leave and reopen; read the recent list.

**Acceptance Scenarios**:

1. **Given** molecules opened in turn, **When** the recent list is read, **Then** it holds each once, newest first, at
   most its cap.
2. **Given** a damaged, oversized or newer recent file, **When** the experience opens, **Then** the list starts empty, a
   message says why, and the file is left as it was until the next change replaces it.

---

### User Story 3 - Keep my label setting (Priority: P2)

A person chooses whether element labels are shown for all atoms, only the selected atom or none; the choice is kept
the next time.

**Why this priority**: the v0.1 feature "local visual settings".

**Independent Test**: change the setting; leave and reopen; read the overlay and the setting.

**Acceptance Scenarios**:

1. **Given** the setting "selected only", **When** an atom is selected, **Then** only its label is shown.
2. **Given** a saved setting, **When** the experience reopens, **Then** the setting is the same.

---

### User Story 4 - Inferred bonds are reproducible (Priority: P2)

The engineer can trust bond inference: the same atoms in any order give the same connections, and every inferred bond
is marked inferred.

**Why this priority**: the phase's regression fixture.

**Independent Test**: infer bonds for every library molecule in several atom orders; compare.

**Acceptance Scenarios**:

1. **Given** a molecule's atoms in a shuffled order, **When** bonds are inferred, **Then** the connections are the same
   (after mapping the order back) and every bond is marked inferred and single.

### Edge Cases

- **Labels set to "selected only" with nothing selected:** no label is shown.
- **A malformed recent or settings file** (more than 8 ids, a duplicate, an empty or malformed id, an unknown label mode): refused as out-of-range.
- **The recent list is full:** opening another molecule drops the oldest.
- **Opening a molecule already in the list:** it moves to the front; it is never listed twice.
- **A recent entry for a molecule that no longer exists:** dropped when the list is read.
- **No storage (tests, previews):** the lists and settings are kept in memory with the same rules.
- **A refused write:** the previous file stays; the in-memory list still changes and a message says the change was not
  saved.
- **Leaving during a write:** the file is replaced atomically, never half written.
- **The person resets the experience's data in the app's Settings:** both files are removed with the experience's
  folder; the next opening starts with an empty recent list and the default label mode.

## Requirements *(mandatory)*

### Functional Requirements

**Library (story 1)**

- **FR-A15-401**: A library list MUST show every bundled molecule with its name, formula, atom and bond counts and its
  source title and license, and choosing an entry MUST open it through the same action as the Molecule menu.

**Recent molecules (story 2)**

- **FR-A15-410**: The experience MUST keep a recent-molecules list in its own storage: newest first, each molecule once,
  at most a stated cap, updated whenever the molecule changes; unknown entries are dropped when read.
- **FR-A15-411**: A damaged, oversized, newer or out-of-range recent file MUST be refused with its reason, leave the
  list empty and stay byte for byte as it was until the next change replaces it.

**Settings (story 3)**

- **FR-A15-420**: The experience MUST keep a settings document in its own storage holding the label mode (all, selected
  only, none); the overlay MUST follow it; a refused settings file is handled like a refused recent file and the default
  (all) applies.

**Determinism (story 4)**

- **FR-A15-430**: Bond inference MUST give the same connections for the same atoms in any order and mark every inferred
  bond inferred and single.

**Experience**

- **FR-A15-440**: The recent list and the settings MUST live outside the engine state (no digest or replay changes);
  the label setting and the recent list MUST have native controls with accessible labels and values; the runner's
  standard scenarios MUST pass on iOS 27.

### Key Entities

- **Recent list** (document schema 1): molecule ids, newest first, at most the cap.
- **Settings** (document schema 1): label mode.
- **Library entry**: molecule, title, formula, counts, source, license.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A15-401**: The library list shows all five molecules with name, formula, counts, source and license.
- **SC-A15-402**: After opening more molecules than the cap, the recent list holds exactly the cap, newest first, no
  duplicates; it is the same after reopening the experience.
- **SC-A15-403**: Each damaged, oversized, newer and out-of-range recent or settings fixture is refused with its reason
  and stays byte-identical.
- **SC-A15-404**: For every library molecule and at least five shuffled atom orders, inferred connections are equal and
  100 % are marked inferred.
- **SC-A15-405**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- The experience storage, atomic replacement and the document pattern of Solar System Explorer's `ViewStore` are reused;
  no VisualCore change is needed.
- The library stays at the five molecules of A15-P01; more molecules are content, not this slice.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 MVP: element labels, bond types and metadata panel (kept, setting added) | FR-A15-420 |
| Regression fixture: bond inference deterministic and marked inferred | FR-A15-430, SC-A15-404 |
| v0.1 feature: curated library with source attributions | FR-A15-401, SC-A15-401 |
| v0.1 feature: local recent molecules and visual settings | FR-A15-410, 411, 420 |
| Contract gap G-LIBRARY | FR-A15-401–420 |
| EGL/context ownership in the VisualCore host | FR-A15-440 |

## Negative Requirements

- No system prompt of any kind (nothing here needs a permission); no import, network, account or sync; no storage outside the experience's own folder; no data without a source and
  license; no change to the engine state, digests or replays from the recent list or settings.
