# Requirements Quality Checklist: Graphics Benchmark Lab — Phase 00 boundary audit

**Purpose**: Unit tests for the Phase 00 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [contracts/contract.md](../contracts/contract.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all inventory areas named (products, host and thread, shader and resource interfaces, frame clock, diagnostics, experience host, build and release, ownership, regression)? [Spec §FR-A24-001] — yes.
- [x] CHK002 Are the five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A24-002, SC-A24-001] — yes.
- [x] CHK003 Are the gaps to assess enumerated, including how the renderer's facts reach the experience? [Spec §FR-A24-003, Clarifications Q2] — yes, after a correction (see Notes).
- [x] CHK004 Are the three manual risks required with owner, verification and release blocker? [Spec §FR-A24-006] — yes.
- [x] CHK005 Is the stop condition defined? [Spec §US4/AC2] — yes (no bounded workload in the host's context or no monotonic frame time over the existing renderer).

## Requirement Clarity and Consistency

- [x] CHK006 Is the rule for GPU time unambiguous (shown only from a confirmed timer, never a relabelled CPU time)? [Spec §Edge Cases, Clarifications Q1] — yes.
- [x] CHK007 Is ownership of each missing piece (VisualCore or app-local) required per gap, with the two upstream gaps named? [Spec §FR-A24-003, SC-A24-002, Clarifications Q1, Q2] — yes.
- [x] CHK008 Is context-loss, resize and orientation handling during a run in scope? [Spec §FR-A24-003, Edge Cases] — yes.
- [x] CHK009 Is the reason for not using `PacingMeter` or the debug-only device reader recorded, so the decision is reviewable? [Spec §Clarifications Q3, Q5] — yes.

## Acceptance Criteria Quality

- [x] CHK010 Are pass conditions numeric (0 problems, 7 of 7, 23 registered, empty diff)? [Spec §SC-A24-001–005] — yes.
- [x] CHK011 Are time limits stated? [Spec §SC-A24-006] — yes.

## Edge Cases

- [x] CHK012 Are partial and experience-only capabilities addressed? [Spec §Edge Cases] — yes.
- [x] CHK013 Are thermal and refresh skew, timer availability and overheating (risks 1–3) addressed? [Spec §Edge Cases, Clarifications Q1, Q5] — yes.

## Non-Functional and Release

- [x] CHK014 Are network, upload, private identifiers, rankings, invented numbers and unbounded stress runs excluded? [Spec §FR-A24-006, Negative Requirements] — yes.
- [x] CHK015 Is "no VisualCore or ProjectM change" measurable? [Spec §FR-A24-008, SC-A24-005] — yes (empty diff since 7de0f2af).
- [x] CHK016 Is the experience kept unregistered, and is the synthetic test id's use recorded? [Spec §FR-A24-005, Canonical overrides] — yes.

## Notes

- CHK003 failed at first: FR-A24-003 did not list how the renderer's facts reach the experience, although
  clarification Q2 makes it an upstream gap; the bullet was added before marking.
- `/speckit-implement` reads checklist state; it does not change the markers.
