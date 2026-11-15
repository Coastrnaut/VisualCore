# Release Requirements Quality Checklist: Light Maze — Phase 06

**Purpose**: Unit tests for the requirements of A13-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK012).

## Completeness

- [x] CHK001 Are all three Phase 06 gates (checklist and inventory complete; test results attached and device rows listed; unsupported promises removed) required? [Spec §Canonical overrides, FR-A13-620–623] — yes.
- [x] CHK002 Are privacy requirements complete (permissions, sources, manifest, note with deletion and credits)? [FR-A13-601–604, Clarifications Q3] — yes.
- [x] CHK003 Are all four sample progress forms and their expected answers specified? [FR-A13-610, data model] — yes.
- [x] CHK004 Are the device-only items enumerated as pending rather than claimed? [FR-A13-622, Edge Cases] — yes.

## Architecture ownership

- [x] CHK005 Is the one-app override stated (no per-app listing, pricing or dossier)? [Spec §Canonical overrides, Negative Requirements] — yes.
- [x] CHK006 Is the failure seam limited to tests and the drawing path? [Clarifications Q5, plan Lifecycle] — yes.

## Clarity and consistency

- [x] CHK007 Are checklist statuses defined with what each must carry? [Clarifications Q1, data model] — yes.
- [x] CHK008 Is the refused-word list explicit, with its scope (store text and interface Swift)? [Clarifications Q2] — yes.
- [x] CHK009 Is the source-scan pattern list explicit? [Clarifications Q3] — yes.

## iOS lifecycle and recovery

- [x] CHK010 Is the recovery flow specified end to end (failure state, file byte-identical, reopen draws)? [FR-A13-611] — yes.
- [x] CHK011 Is migration of saved states of schema 1 required? [FR-A13-612] — yes.

## Accessibility and privacy

- [x] CHK012 Are the interface journeys consistent with the app's rules (a fresh install has level 2 locked)? [FR-A13-630, Clarifications Q4, research D4] — failed (the journey chose level 2 before solving level 1); spec and research corrected to choose level 2 after the solve.
- [x] CHK013 Are the accessibility facts proved so far and the audits deferred listed? [FR-A13-623] — yes.

## Testability and performance

- [x] CHK014 Can every success criterion be checked without a device? [SC-A13-601–605, quickstart] — yes.
- [x] CHK015 Are time limits stated (interface < 60 s, package < 10 s) with no measured performance claims? [SC-A13-605, Negative Requirements] — yes.
- [x] CHK016 Are owner-only steps recorded as BLOCKED_OWNER_ACTION with steps? [Spec §Canonical overrides, Edge Cases] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
