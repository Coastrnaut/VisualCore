# Library and Persistence Requirements Quality Checklist: Molecular Explorer — Phase 04

**Purpose**: Unit tests for the requirements of A15-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer); two items failed and were corrected
before this record (CHK010, CHK013).

## Completeness

- [x] CHK001 Are all three Phase 04 gates (labels, bond types and panel kept; inference deterministic and marked; host owns the context) required with measurable outcomes? [Spec §Canonical overrides, SC-A15-404] — yes.
- [x] CHK002 Are the library list's contents (name, formula, counts, source, license) and its action specified? [FR-A15-401, Clarifications Q4] — yes.
- [x] CHK003 Are the recent list's cap, order, uniqueness, file, byte limit and unknown-id rule stated? [FR-A15-410, Clarifications Q1] — yes.
- [x] CHK004 Are the settings document's field, values, default, file and byte limit stated? [FR-A15-420, Clarifications Q2] — yes.

## Clarity and consistency

- [x] CHK005 Are refusal reasons and their wording defined for both documents, and is "the file stays byte for byte" testable? [FR-A15-411, Clarifications Q3, SC-A15-403] — yes.
- [x] CHK006 Is the determinism fixture quantified (molecules, seeded shuffles, mapping back)? [FR-A15-430, Clarifications Q5] — yes.
- [x] CHK007 Is it consistent that the recent list and settings live outside the engine state while `molecule.select` stays the only engine action used? [FR-A15-440, Clarifications Q4] — yes.

## Architecture ownership

- [x] CHK008 Are the documents pure core types and the stores experience code over the existing storage, with no VisualCore change? [Plan Project Structure, Assumptions] — yes.
- [x] CHK009 Is the ViewStore pattern (load never writes, in-memory without storage) required rather than implied? [Clarifications facts, research D1] — yes.

## iOS lifecycle, privacy and edge cases

- [x] CHK010 Is deleting the stored data (the app's per-experience reset) addressed? [Spec §Edge Cases] — failed (no deletion path was stated); an edge case now says the reset removes both files and the next opening starts empty with defaults.
- [x] CHK011 Are full lists, re-opened molecules, unknown ids, missing storage, failed writes and interrupted writes addressed? [Spec §Edge Cases] — yes.
- [x] CHK012 Are local-only storage and the absence of network, accounts and sync stated? [Negative Requirements, constitution A15] — yes.
- [x] CHK013 Is it stated that the phase raises no system prompt, in line with the owner's rule that prompting checks are human tests? [Negative Requirements] — failed (not stated); the negative requirements now say no system prompt of any kind.

## Accessibility

- [x] CHK014 Do the Library, Recent and Labels controls require accessible labels and values? [FR-A15-440, Clarifications Q4] — yes.

## Testability and performance

- [x] CHK015 Can every success criterion be checked without a device, with fixtures for each refusal? [SC-A15-401–405, quickstart] — yes.
- [x] CHK016 Are document sizes bounded and no performance figures claimed? [Clarifications Q1, Q2, Plan Technical Context] — yes.

## Notes

- 16 items evaluated on 2026-11-16; two corrected. `/speckit-implement` reads these markers and does not change them.
