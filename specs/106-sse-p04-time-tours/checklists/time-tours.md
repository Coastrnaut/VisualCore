# Time and Tours Requirements Quality Checklist: Solar System Explorer — Phase 04

**Purpose**: Unit tests for the requirements of A14-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK008).

## Completeness

- [x] CHK001 Are both Phase 04 gates (time with a UTC date; captioned tours) required with measurable outcomes? [Spec §Canonical overrides, SC-A14-401–403] — yes.
- [x] CHK002 Are the rates, their labels, the step size and the range-end behaviour stated? [FR-A14-401, 402, Clarifications Q1] — yes.
- [x] CHK003 Are both tours' stops, hold times and caption sources stated? [FR-A14-410, Clarifications Q2] — yes.
- [x] CHK004 Are the saved view's fields, file name, size limit and refusals stated? [FR-A14-421, Clarifications Q5] — yes.

## Clarity and consistency

- [x] CHK005 Is "Now" defined so replays never read the device clock? [FR-A14-403, Clarifications Q1] — yes.
- [x] CHK006 Is the label placement rule quantified (offset, box size, order, hiding rule)? [FR-A14-420, Clarifications Q4] — yes.
- [x] CHK007 Is the spoken-date rate limit quantified and its triggers named? [FR-A14-403, Clarifications Q1] — yes.
- [x] CHK008 Are the interactions of a running tour with body choices, restoring a view and starting another tour defined? [FR-A14-411, Edge Cases] — failed (only body choices were covered); the spec and contract now say that body choices and `view.apply` stop the tour and `tour.start` restarts with the chosen tour.

## Architecture ownership

- [x] CHK009 Is the host addition generic, additive and defaulted, with docs, tests and baseline required? [FR-A14-420, Clarifications Q3, Plan II-a] — yes.
- [x] CHK010 Are the clock and tours kept in the deterministic core and the wall clock only in the presenter? [Plan Lifecycle] — yes.

## iOS lifecycle and edge cases

- [x] CHK011 Is the no-fast-forward rule tied to the host's suspension contract? [Story 1 AC4, Assumptions, Clarifications facts] — yes.
- [x] CHK012 Are range ends, date steps while playing, labels behind the camera and rapid announcements covered? [Spec §Edge Cases] — yes.
- [x] CHK013 Is the state migration 3 → 4 and the saved view's schema defined? [FR-A14-430, Clarifications Q5] — yes.

## Accessibility and privacy

- [x] CHK014 Are labels non-interactive and kept off the controls, with captions and dates spoken? [FR-A14-420, Negative Requirements] — yes.
- [x] CHK015 Are no network and storage only inside the app's own storage stated? [Negative Requirements, Plan Constitution VIII] — yes.

## Testability and performance

- [x] CHK016 Can every success criterion be checked without a device and without wall-clock asserts? [SC-A14-401–406, Plan Technical Context, quickstart] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
