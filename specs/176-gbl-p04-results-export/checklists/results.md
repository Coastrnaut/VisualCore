# Requirements Quality Checklist: Graphics Benchmark Lab — Phase 04 results and export

**Purpose**: Unit tests for the Phase 04 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [data-model.md](../data-model.md),
[contracts/results.md](../contracts/results.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are the stored case settings enumerated, with how a mismatch is refused? [Spec §FR-A24-401, Clarifications Q1] — yes.
- [x] CHK002 Are the library's files, index, caps and messages specified? [Clarifications Q2] — yes.
- [x] CHK003 Are the CSV's parts, columns, number text, line ends and quoting specified? [Spec §FR-A24-404, Clarifications Q4] — yes.
- [x] CHK004 Is the list's ordering defined without a clock? [Spec §US2] — yes, after a correction (see Notes).
- [x] CHK005 Is when saving is possible, and a repeated save, specified? [Spec §Edge Cases] — yes, after a correction.

## Requirement Clarity and Consistency

- [x] CHK006 Is "export only by the person's choice" defined as a specific action and file location? [Clarifications Q5] — yes.
- [x] CHK007 Are the refusal codes consistent between the run file, the saved-result file and the list? [Clarifications Q2, A24-P01] — yes.
- [x] CHK008 Is a missing GPU time written the same way in JSON (absent) and CSV (empty)? [Spec §Edge Cases, Clarifications Q4] — yes.

## Acceptance Criteria and Testability

- [x] CHK009 Are golden files named as the measure for the exports? [Spec §SC-A24-403] — yes.
- [x] CHK010 Is "no automatic export" measurable (no file before the action)? [Spec §SC-A24-404] — yes.

## Scenario and Edge Case Coverage

- [x] CHK011 Are full storage, newer files, damaged index and stopped runs covered? [Spec §Edge Cases, Clarifications Q2] — yes.
- [x] CHK012 Is opening a result of a case version the app no longer has covered? [Spec §Edge Cases, Clarifications Q1] — yes.

## Non-Functional, Architecture and Release

- [x] CHK013 Is graphics ownership unaffected (no GL in saving or export)? [Spec §Canonical overrides] — yes.
- [x] CHK014 Is privacy stated (own storage, share sheet only, no upload)? [Spec §Canonical overrides, Negative Requirements] — yes.
- [x] CHK015 Are the caps justified against the storage quota? [research R5] — yes.
- [x] CHK016 Is no VisualCore change required? [Spec §Canonical overrides] — yes.

## Notes

- CHK004 failed at first: US2 said "date order" though nothing stores a date (the core has no clock); the list is
  ordered by save order and the spec now says so.
- CHK005 failed at first: the spec did not say when saving is offered or what a second save of the same run does; an
  edge case now covers both.
- `/speckit-implement` reads checklist state; it does not change the markers.
