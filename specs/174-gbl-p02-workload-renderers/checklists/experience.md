# Requirements Quality Checklist: Graphics Benchmark Lab — Phase 02 workloads and experience

**Purpose**: Unit tests for the Phase 02 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [data-model.md](../data-model.md),
[contracts/experience.md](../contracts/experience.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Is each workload's drawing specified with its inputs, so its picture is a function of case and frame only? [Spec §FR-A24-201, Clarifications Q1] — yes.
- [x] CHK002 Are the timeline's phase boundaries specified exactly (strict and non-strict ends)? [Spec §FR-A24-203, US2, Clarifications Q2] — yes.
- [x] CHK003 Is every recorded sample field's source specified, with no placeholder value? [Spec §FR-A24-204, Clarifications Q2] — yes, after a correction (see Notes).
- [x] CHK004 Are the core's state, actions, digest and rule ids specified? [Clarifications Q3] — yes.
- [x] CHK005 Are the interface's identifiers, status words and summary contents specified? [Spec §FR-A24-205, Clarifications Q4] — yes.

## Requirement Clarity and Consistency

- [x] CHK006 Is "not blank" quantified? [Spec §US1] — yes, after a correction (luma spans at least 16 of 255).
- [x] CHK007 Is GPU absence consistent across the samples, the summary and the status (null, no distribution, a flag, a sentence)? [Spec §US3, Clarifications Q2, Q4] — yes.
- [x] CHK008 Is the out-of-scope list consistent with what this phase measures (CPU time measured here, its device validation later)? [Spec §Canonical overrides] — yes, after the same correction as CHK003.

## Acceptance Criteria and Testability

- [x] CHK009 Can determinism be measured (byte-identical across two hosts)? [Spec §SC-A24-201] — yes.
- [x] CHK010 Is testing bounded so no test waits for a real plan? [Spec §SC-A24-206, Assumptions] — yes.

## Scenario and Edge Case Coverage

- [x] CHK011 Are case changes, leaving during a run, context loss and resize covered? [Spec §Edge Cases, US4] — yes.
- [x] CHK012 Is a case over the host's limits refused before allocation? [Spec §FR-A24-202, US1/AC3] — yes.

## Non-Functional, Architecture and Release

- [x] CHK013 Is graphics ownership in the host stated, with no GL call of the experience's own? [Spec §Negative Requirements, FR-A24-201] — yes.
- [x] CHK014 Are copy limits stated (no frame rate, no benchmark number)? [Clarifications Q4, Negative Requirements] — yes.
- [x] CHK015 Is availability kept to a candidate until X-A24, with the runner on iOS 27.2? [Spec §FR-A24-207, Clarifications Q5] — yes.
- [x] CHK016 Are privacy and permissions unchanged (none)? [Spec §Negative Requirements] — yes.

## Notes

- CHK003 and CHK008 failed at first: clarification Q2 recorded `cpuMs` as 0 until A24-P03, which would be a
  fabricated zero against the phase's own regression rule; the presenter now reads its own submit time from a
  monotonic clock, and the out-of-scope list keeps only its device validation for later.
- CHK006 failed at first: "not blank" had no measure; it now requires a luma spread of at least 16 of 255.
- `/speckit-implement` reads checklist state; it does not change the markers.
