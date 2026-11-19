# Requirements Quality Checklist: Effects Composer — Phase 00 boundary audit

**Purpose**: Unit tests for the Phase 00 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [contracts/contract.md](../contracts/contract.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all inventory areas named (products, host and thread, shader and resource interfaces including texture upload and read-back, frame clock, diagnostics, experience host, build and release, ownership, regression)? [Spec §FR-A25-001] — yes.
- [x] CHK002 Are the six brainstorm capabilities and six version 0.1 features required in the matrix? [Spec §FR-A25-002, SC-A25-001] — yes.
- [x] CHK003 Are the gaps to assess enumerated, including how an imported image's bytes reach a pass input? [Spec §FR-A25-003, Clarifications Q2] — yes, after a correction (see Notes).
- [x] CHK004 Are the three manual risks required with owner, verification and release blocker? [Spec §FR-A25-006] — yes.
- [x] CHK005 Is the stop condition defined? [Spec §US4/AC2] — yes (no texture-sampling full-screen pass into an offscreen target in the host's context over the existing renderer).

## Requirement Clarity and Consistency

- [x] CHK006 Is the reason for drawing effects app-locally rather than through the effects graph recorded, so the decision is reviewable? [Spec §Clarifications Q1, research D6] — yes.
- [x] CHK007 Is ownership of each missing piece (VisualCore or app-local) required per gap, with the upstream gap named? [Spec §FR-A25-003, SC-A25-002, Clarifications Q2] — yes.
- [x] CHK008 Is context-loss, resize and orientation handling, including re-uploading an imported image, in scope? [Spec §FR-A25-003, Edge Cases, Clarifications Q2] — yes.
- [x] CHK009 Are colour-space boundaries stated with a fallback when half-float targets are not renderable? [Spec §Clarifications Q3] — yes.
- [x] CHK010 Is the permission decision consistent between the picker (none) and export (photo-library-add)? [Spec §Clarifications Q2, Q5] — yes.

## Acceptance Criteria Quality

- [x] CHK011 Are pass conditions numeric (0 problems, 7 of 7, 24 registered, empty diff)? [Spec §SC-A25-001–005] — yes.
- [x] CHK012 Are time limits stated? [Spec §SC-A25-006] — yes.

## Edge Cases

- [x] CHK013 Are partial and experience-only capabilities addressed? [Spec §Edge Cases] — yes.
- [x] CHK014 Are colour mistakes, oversized images and unbounded targets (risks 1–3) and a cancelled pick addressed? [Spec §Edge Cases] — yes.

## Non-Functional and Release

- [x] CHK015 Are network, upload, private APIs, user code, video editing, unconsented import and accuracy or compatibility claims excluded? [Spec §FR-A25-006, Negative Requirements] — yes.
- [x] CHK016 Is "no VisualCore or ProjectM change" measurable? [Spec §FR-A25-008, SC-A25-005] — yes (empty diff since a2d68e21).
- [x] CHK017 Is the experience kept unregistered, and is the synthetic test id's use recorded? [Spec §FR-A25-005, Clarifications] — yes.

## Notes

- CHK003 failed at first: FR-A25-003 did not list how an imported image's bytes reach a pass input, although
  clarification Q2 makes it an upstream gap; the bullet was added before marking.
- `/speckit-implement` reads checklist state; it does not change the markers.
