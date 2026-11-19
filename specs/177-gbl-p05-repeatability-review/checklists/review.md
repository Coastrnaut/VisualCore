# Requirements Quality Checklist: Graphics Benchmark Lab — Phase 05 review

**Purpose**: Unit tests for the Phase 05 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [data-model.md](../data-model.md),
[contracts/review.md](../contracts/review.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all qualification classes, reasons and sentences enumerated? [Clarifications Q1] — yes.
- [x] CHK002 Are the comparability keys and the not-comparable reasons enumerated? [Clarifications Q3] — yes.
- [x] CHK003 Are the explanation's sections and their content named? [Clarifications Q5, US3] — yes.
- [x] CHK004 Is how a background interruption is detected specified and justified from the code? [Clarifications, background fact] — yes.
- [x] CHK005 Is the background duration in the interface test specified against the sample cap? [Clarifications Q5] — yes, after a correction (see Notes).

## Requirement Clarity and Consistency

- [x] CHK006 Is "spread" defined (largest minus smallest) and is a statistical claim avoided? [Clarifications Q3, research R4] — yes.
- [x] CHK007 Is the CSV version change consistent with the unchanged JSON run file? [Clarifications Q2] — yes.
- [x] CHK008 Is the qualification consistent between list, opened result and exports? [Spec §FR-A24-502] — yes.

## Acceptance Criteria and Testability

- [x] CHK009 Are the interface tests bounded in time and environment (iOS 27.2 phone, under 60 s)? [Spec §SC-A24-504] — yes.
- [x] CHK010 Is the copy scan of the explanation named with its tool and scope? [Spec §SC-A24-503] — yes, after a correction.

## Scenario and Edge Case Coverage

- [x] CHK011 Are warm-up interruptions, a hot start, old saved results and changed case versions covered? [Spec §Edge Cases] — yes.
- [x] CHK012 Is a mixed GPU-timer set of trials covered? [Spec §Edge Cases, Clarifications Q3] — yes.

## Non-Functional, Architecture and Release

- [x] CHK013 Is the device plan's state and its no-claim rule stated? [Spec §US5, FR-A24-506] — yes.
- [x] CHK014 Is accessibility specified for the explanation (spoken headings, text not colour)? [Spec §US3, plan] — yes.
- [x] CHK015 Is no VisualCore change and no device run stated? [Spec §Canonical overrides] — yes.
- [x] CHK016 Is privacy unchanged (no network, no sending)? [Spec §Negative Requirements] — yes.

## Notes

- CHK005 failed at first: the interface test's time in the background was not tied to the 1,000 ms sample cap; it is
  now at least 2 seconds.
- CHK010 failed at first: SC-A24-503's copy scan named no tool; it is `scripts/check_copy_claims.py` with the shared
  denylist over `GBLExplanation.swift`.
- `/speckit-implement` reads checklist state; it does not change the markers.
