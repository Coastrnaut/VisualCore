# Feature Specification: Graphics Benchmark Lab — Phase 04 Results persistence/export

**Feature Branch**: `176-gbl-p04-results-export` (spec directory only; work stays on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: A24-P04 (legacy ledger) · ID namespace FR-A24-4##, SC-A24-4##, T-A24-4##

**Input**: User description: archived manual `apps/24-graphics-benchmark-lab.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):**
  - MVP: the device, OS, build, quality and thermal-context report with provenance, now kept with every saved result
    and shown when a result is opened;
  - regression fixture: the identical case version and settings are stored with the run, so a saved result names
    exactly what was measured;
  - graphics context ownership stays solely in the audited VisualCore host (saving and exporting touch no graphics).
- **Gaps built here:** G-RESULTS and G-EXPORT of `docs/apps/graphics-benchmark-lab/visualcore-contract.json`.
- **Privacy:** results stay in the experience's own storage; an export happens only when the person chooses it, through
  the system share sheet; nothing is uploaded.
- **No VisualCore or ProjectM change.** Follow `specs/169-vpl-p04-library-diagnostics` (the library) and A19's export.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A finished run is kept with what was measured (Priority: P1) 🎯

After a run finishes, the person saves it. The saved result holds the case's full settings and version, every frame
sample, the summary and the provenance report; opening it later shows the same numbers and the same report.

**Why this priority**: the phase's regression fixture and MVP.

**Independent Test**: save a run, open it in a new session, compare.

**Acceptance Scenarios**:

1. **Given** a finished run, **When** it is saved and opened in a new session, **Then** the case settings, version,
   samples, summary and report equal the originals.
2. **Given** a saved result, **When** its file is read, **Then** it names the case's every setting and run-plan length,
   not only its identifier.

---

### User Story 2 - A list of saved results that never loses one (Priority: P1)

The person sees saved results newest first (case, date order, the frame-interval p50 and p95, "GPU timed" or not),
opens one, removes one. A damaged or newer file is listed as unreadable with its reason and is never deleted by itself.

**Why this priority**: local persistence (constitution IX).

**Independent Test**: fill the library to its cap; add damaged and newer files; list and remove.

**Acceptance Scenarios**:

1. **Given** the cap of saved results, **When** another is saved, **Then** it is refused with a message and nothing is
   removed.
2. **Given** a damaged, truncated, newer or non-finite file, **When** the list is read, **Then** it is shown as
   unreadable with its reason and kept on disk.

---

### User Story 3 - Export only by the person's choice (Priority: P1)

The person exports a result as versioned JSON (the result file itself) or CSV (one row per frame sample, with a header
naming the format version, the case, its settings and the report). The export opens the system share sheet; nothing
leaves the device otherwise.

**Why this priority**: version 0.1 feature 05.

**Independent Test**: build the JSON and CSV of a fixture run and compare with golden files; check that the share item is
made only from the person's action.

**Acceptance Scenarios**:

1. **Given** a fixture run, **When** exported, **Then** the JSON and CSV equal their golden files byte for byte.
2. **Given** a field with a comma, quote or line break, **When** written to CSV, **Then** it is quoted and escaped.
3. **Given** no action by the person, **When** the experience runs, **Then** no export file is written.

### Edge Cases

- **Storage full:** saving is refused with a message; nothing else changes.
- **A result saved by a newer app version:** listed as unreadable ("saved by a newer version"), kept.
- **A run that was stopped or interrupted:** can be saved, and is listed with its state.
- **A run without GPU times:** the CSV's GPU column is empty, never 0.
- **Opening a result of a case version the app no longer has:** the stored settings are shown; the result still opens.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A24-401**: A saved result MUST store the case's identifier, version, every workload setting and run-plan length,
  the samples, the summary, the state and the report, in a versioned file read through a migration chain.
- **FR-A24-402**: A library MUST list saved results newest first with case, state, interval p50 and p95 and whether GPU
  times exist, open and remove them, and hold at most a documented number of results and bytes.
- **FR-A24-403**: Damaged, truncated, newer, oversized and non-finite files MUST be listed as unreadable with a named
  reason and never deleted or rewritten automatically.
- **FR-A24-404**: Export MUST write the result as versioned JSON and as CSV (format version, case and settings, report,
  one row per sample with an empty GPU field when absent, RFC 4180 quoting), to a temporary file handed to the share
  sheet only from the person's action.
- **FR-A24-405**: Opening a saved result MUST show its summary and its report.
- **FR-A24-406**: Every public name MUST carry documentation; G-RESULTS and G-EXPORT MUST be closed with evidence.

### Key Entities

- **Saved result**: the run with the full case, in its versioned file.
- **Result library**: the index and its entries (name, case, state, order, readable or the reason).
- **Export**: JSON and CSV texts and their temporary files.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A24-401**: A saved and reopened result equals the original in 100% of its fields.
- **SC-A24-402**: 100% of the refusal fixtures are listed with their reason and stay byte-identical on disk.
- **SC-A24-403**: The JSON and CSV of the fixture run match their golden files byte for byte.
- **SC-A24-404**: 0 export files exist before the person's action.
- **SC-A24-405**: Each unit test finishes in under 10 seconds.

## Assumptions

- A24-P01 to P03 are reused; the run file gains the case's settings in a new version with a migration.
- The system share sheet is reached through SwiftUI's `ShareLink`, as other experiences of the app do.

## Traceability

| Source | Requirement |
|---|---|
| MVP: device/OS/build/quality/thermal report with provenance | FR-A24-401, 405 |
| Regression fixture: identical case version and settings stored with the run | FR-A24-401, US1 |
| EGL/context ownership solely in the host | Assumptions (no graphics in saving or export) |
| Version 0.1 feature 05: results export as versioned JSON or CSV | FR-A24-404, US3 |
| Contract G-RESULTS, G-EXPORT | FR-A24-401–406 |

## Negative Requirements

- No upload, no network, no automatic export, no deletion of an unreadable file, no VisualCore change, no zero in place
  of a missing GPU time.
