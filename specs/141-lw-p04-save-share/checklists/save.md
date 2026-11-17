# Save and Share Requirements Quality Checklist: Living Wallpapers — Phase 04

**Purpose**: Unit tests for the requirements of A19-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are the share item, its content type, its file name and when it is offered specified? [Spec §FR-A19-401, Q1] — yes.
- [x] CHK002 Are the job's steps, progress values, cancel points, failure reasons and retry specified? [Spec §FR-A19-403, Q2] — yes.
- [x] CHK003 Are the history's fields, bound, order, refusals and storage specified? [Spec §FR-A19-404, Q3] — yes.
- [x] CHK004 Is the phase's MVP (short loop) addressed by the recorded decision and its guard, without new code? [Overrides, FR-A19-405, Q5] — yes.

## Architecture ownership

- [x] CHK005 Is the split of the job between the main actor (render) and a detached task (encode, verify) justified by a verified rule? [Q2, research D2] — yes (`renderOffscreen` asserts the main thread).
- [x] CHK006 Is it stated that the snapshot and project schemas do not change? [Q4] — yes.

## Privacy and permissions

- [x] CHK007 Are broad library access, direct saving and PhotoKit excluded, with a scan and the usage-description release step? [FR-A19-402, Q1, Negative Requirements] — yes.
- [x] CHK008 Is the new stored data (the history) disclosed, with its contents, bound and how to clear it? [Gap] — failed (no disclosure requirement); the spec's Assumptions now assign it to A19-P06's privacy page with those details.
- [x] CHK009 Is a declined Photos destination in the sheet addressed? [Spec §Edge Cases] — yes.

## iOS lifecycle

- [x] CHK010 Are a removed temporary file, a cancel during encode and the history bound addressed? [Spec §Edge Cases] — yes.
- [x] CHK011 Is the live picture required to keep rendering after cancels and failures? [US2 AC2, contracts/save.md] — yes.

## Testability and release

- [x] CHK012 Are the progress values and the zero-leftover counts measurable? [SC-A19-402] — yes.
- [x] CHK013 Is the injected clock required so history times are testable without the wall clock? [Q3] — yes.
- [x] CHK014 Is the Release build needed by the usage-description step scheduled in this phase? [research D4, quickstart] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
