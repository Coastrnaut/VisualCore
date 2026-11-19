# Requirements Quality Checklist: Visual Programming Lab — Phase 00 boundary audit

**Purpose**: Unit tests for the Phase 00 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-18
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [contracts/contract.md](../contracts/contract.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-18); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all inventory areas named (products, host and thread, pass and resource interfaces, experience host, build and release, ownership, regression)? [Spec §FR-A23-001] — yes.
- [x] CHK002 Are the five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A23-002, SC-A23-001] — yes.
- [x] CHK003 Are the gaps to assess enumerated? [Spec §FR-A23-003] — yes (ten areas).
- [x] CHK004 Are the three manual risks required with owner, verification and release blocker? [Spec §FR-A23-006] — yes.
- [x] CHK005 Is the stop condition defined? [Spec §US4/AC2] — yes (no pass chain over render targets, no sampling between passes, or no bounded generated program over the existing renderer).

## Requirement Clarity and Consistency

- [x] CHK006 Is the place where a graph is validated (before any GPU work) specified? [Spec §Edge Cases, Clarifications Q2] — yes.
- [x] CHK007 Is ownership of each missing piece (VisualCore or app-local) required per gap? [Spec §FR-A23-003, SC-A23-002] — yes.
- [x] CHK008 Is context-loss, resize and orientation rebuild in scope? [Spec §FR-A23-003] — yes.
- [x] CHK009 Is the reason for not using VisualCore's effect graph recorded, so the decision is reviewable? [Spec §Clarifications Q1] — yes.

## Acceptance Criteria Quality

- [x] CHK010 Are pass conditions numeric (0 problems, 7 of 7, 22 registered, empty diff)? [Spec §SC-A23-001–005] — yes.
- [x] CHK011 Are time limits stated? [Spec §SC-A23-006] — yes.

## Edge Cases

- [x] CHK012 Are partial and experience-only capabilities addressed? [Spec §Edge Cases] — yes.
- [x] CHK013 Are texture memory, touch wiring and file migration (risks 1–3) addressed? [Spec §Edge Cases, Clarifications Q4, Q5] — yes.

## Non-Functional and Release

- [x] CHK014 Are network, sharing, permission, scripting and unbounded-loop features excluded? [Spec §FR-A23-006, Negative Requirements] — yes.
- [x] CHK015 Is "no VisualCore or ProjectM change" measurable? [Spec §FR-A23-008, SC-A23-005] — yes (empty diff since 7b64fedf).
- [x] CHK016 Is the experience kept unregistered, and is the synthetic test id's use recorded? [Spec §FR-A23-005, Canonical overrides] — yes.

## Notes

- Every item passed on the first evaluation; no artifact needed a correction.
- `/speckit-implement` reads checklist state; it does not change the markers.
