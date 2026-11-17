# Audit Requirements Quality Checklist: Shader Studio — Phase 00

**Purpose**: Unit tests for the requirements of A22-P00 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-17 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are all inventory areas named (products, host and thread, shader and resource interfaces, experience host, build and release, ownership, regression)? [Spec §FR-A22-001] — yes.
- [x] CHK002 Are the five brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A22-002, SC-A22-001] — yes.
- [x] CHK003 Are the gaps to assess enumerated? [Spec §FR-A22-003] — yes (eleven areas).
- [x] CHK004 Are the three manual risks required with owner, verification and release blocker? [Spec §FR-A22-006] — yes.
- [x] CHK005 Is the stop condition defined? [Spec §US4/AC2] — yes (no runtime compile, log or full-screen drawing over the existing renderer).

## Architecture ownership and lifecycle

- [x] CHK006 Is the thread on which a person's shader compiles specified, given that the host's thread is the main thread? [Spec §FR-A22-003, Clarifications] — corrected: FR-A22-003 now states that a control queues a compile request that the preview scene runs at its next frame, after the caps, one at a time; an edge case covers a waiting request.
- [x] CHK007 Is ownership of each missing piece (VisualCore or app-local) required per gap? [Spec §FR-A22-003, SC-A22-002] — yes.
- [x] CHK008 Is context-loss, resize and orientation rebuild in scope? [Spec §FR-A22-003] — yes.
- [x] CHK009 Is the availability rule defined? [Spec §Clarifications Q2] — yes.

## Clarity and measurability

- [x] CHK010 Are pass conditions numeric (0 problems, 7 of 7, 21 registered, empty diff)? [Spec §SC-A22-001–005] — yes.
- [x] CHK011 Are time limits stated? [Spec §SC-A22-006] — yes.

## Edge cases

- [x] CHK012 Are partial and experience-only capabilities addressed? [Spec §Edge Cases] — yes.
- [x] CHK013 Are line shifts from inserted code addressed? [Spec §Edge Cases, Clarifications Q3] — yes.

## Privacy, claims and release

- [x] CHK014 Are network, gallery, permission and sandbox claims excluded? [Spec §FR-A22-006, Negative Requirements] — yes.
- [x] CHK015 Is "no VisualCore or ProjectM change" measurable? [Spec §FR-A22-008, SC-A22-005] — yes (empty diff since 6218b9a1).
- [x] CHK016 Is the experience kept unregistered? [Spec §FR-A22-005] — yes.

## Notes

- CHK006's correction also needs the constitution's A22 compile rule worded for the main-thread host; that is a PATCH
  amendment, made with `/speckit-constitution` before the plan is used.
- `/speckit-implement` reads these markers and does not change them.
