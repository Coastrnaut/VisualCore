# Requirements Quality Checklist: Graphics Benchmark Lab — Phase 03 runner, timer and report

**Purpose**: Unit tests for the Phase 03 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [contracts/visualcore.md](../contracts/visualcore.md),
[contracts/experience.md](../contracts/experience.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are the VisualCore additions specified as names, types and behaviour, with their documentation, baseline and regression obligations? [Spec §FR-A24-303, 305, 308; contracts/visualcore.md] — yes.
- [x] CHK002 Is the timer's result rule specified (available and not disjoint; discard on disjoint; old generations never read)? [Clarifications Q2, Edge Cases] — yes.
- [x] CHK003 Is every report field's public source named, and the identifiers refused listed? [Clarifications Q5] — yes.
- [x] CHK004 Is the dropped-frame rule quantified? [Clarifications Q4] — yes (25 ms).
- [x] CHK005 Are the units of GPU time and the behaviour on a renderer whose entry points do not resolve specified? [Spec §Edge Cases] — yes, after a correction (see Notes).

## Requirement Clarity and Consistency

- [x] CHK006 Is the warm-up exclusion consistent between the regression gate, US1 and the summary rules of A24-P01? [Spec §FR-A24-301, US1] — yes.
- [x] CHK007 Is "supported" defined the same way in the probe, the timer initializer and the report's timing sources? [Clarifications Q2, Q3, Q5] — yes.
- [x] CHK008 Is the run file's version change and its migration specified? [Clarifications Q5, data-model.md] — yes.

## Acceptance Criteria and Testability

- [x] CHK009 Are the timer's acceptance criteria measurable without a device (finite, non-negative, within the cap; none from a disjoint result)? [Spec §SC-A24-303] — yes.
- [x] CHK010 Is a forced-unsupported path testable? [Clarifications Q3] — yes (a test seam).

## Scenario and Edge Case Coverage

- [x] CHK011 Are late results, disjoint events, rebuilds, thermal changes and Low Power Mode covered? [Spec §Edge Cases] — yes.
- [x] CHK012 Are stop, stall, resize and leaving covered for the runner? [Spec §US4, FR-A24-302] — yes.

## Non-Functional, Architecture and Release

- [x] CHK013 Is ownership split stated (generic timing and renderer facts in VisualCore; probe, rules and report in the experience)? [Plan §Parallel work, Constitution II] — yes.
- [x] CHK014 Is privacy stated (no unique identifier, no network, public APIs only) and provable by a scan? [Spec §US3, Clarifications Q5] — yes.
- [x] CHK015 Is the simulator-not-device-evidence rule stated for GPU times? [Spec §Canonical overrides, Assumptions] — yes.
- [x] CHK016 Is the reference regression required after the VisualCore change? [Spec §FR-A24-308, SC-A24-305] — yes.

## Notes

- CHK005 failed at first: the spec did not state the query result's unit or what happens where the extension is
  listed but its entry points do not resolve (as on a build machine's stand-in renderer); both edge cases were added
  before marking.
- `/speckit-implement` reads checklist state; it does not change the markers.
