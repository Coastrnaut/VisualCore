# Editor Requirements Quality Checklist: Living Wallpapers — Phase 03

**Purpose**: Unit tests for the requirements of A19-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are the colour edit, its reset and what clears it specified, with ranges and opacity? [Spec §FR-A19-301, Q1] — yes.
- [x] CHK002 Are both schema raises specified with migration defaults and the stored earlier examples? [Q1, data-model, lesson of X-A17] — yes.
- [x] CHK003 Is the fallback notice's wording specified with its three numbers and the no-limit case? [Q2, contracts/editor.md] — yes.
- [x] CHK004 Is the export result line specified from the read-back file, not the request? [Spec §FR-A19-303, Q3] — yes.
- [x] CHK005 Are the help sections, their reachability and their scans specified? [Spec §FR-A19-304, Q4] — yes.

## Architecture ownership

- [x] CHK006 Is it stated that no VisualCore change is needed and which existing pieces are reused (`ExperienceFeedback`, `AnnouncementPlanner`, `MigrationChain`)? [plan Constitution II, research D5] — yes.
- [x] CHK007 Are the notice, result line and help placed in the core so they are testable without the GPU? [research D3, D4] — yes.

## Platform truth and privacy

- [x] CHK008 Is the help's description of the system's steps worded so it stays true across iOS versions and names no development phase to the person? [Q4, constitution A19 platform truth] — failed (the help named A19-P04 and a fixed Settings path); corrected: user-facing text names no phase and notes that the steps can differ between iOS versions.
- [x] CHK009 Are wallpaper-setting claims, Photos calls and network excluded? [Negative Requirements, FR-A19-306] — yes.

## iOS lifecycle and accessibility

- [x] CHK010 Are labels with values, one announcement per outcome with its kind, and the largest text size specified measurably? [Q5, SC-A19-303] — yes.
- [x] CHK011 Are Reduce Motion and newer-schema refusals addressed? [Spec §Edge Cases] — yes.

## Testability and release

- [x] CHK012 Are the notice's limits (2048, 4096, 8192) and the zero-notice case for fitting templates measurable? [SC-A19-302] — yes.
- [x] CHK013 Is the rollback consequence of schema 2 stated (refused as newer by older code)? [plan Migration] — yes.
- [x] CHK014 Are the test time limits stated and audits deferred to the device campaign? [SC-A19-305, Q5] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
