# Requirements Quality Checklist: Effects Composer — Phase 04 image import

**Purpose**: Unit tests for the Phase 04 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [contracts/visualcore.md](../contracts/visualcore.md),
[contracts/import.md](../contracts/import.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Is the VisualCore upload's contract complete (formats, row order, refusals, docs, baseline, regression)? [Spec §FR-A25-401, Clarifications Q1] — yes.
- [x] CHK002 Are the decode's size limit, refusal codes and messages specified? [Spec §FR-A25-403, Clarifications Q2, Q4] — yes.
- [x] CHK003 Is the loading state and a second pick during decoding specified? [Spec §Edge Cases] — yes, after a correction (see Notes).
- [x] CHK004 Are the regression fixture's pictures, orientations and colour tolerance specified? [Spec §Clarifications Q3] — yes.

## Clarity and Consistency

- [x] CHK005 Is the colour space of the decoded bytes stated, consistent with the effects working on stored sRGB values? [Spec §Clarifications Q2, A25-P01] — yes.
- [x] CHK006 Is the limit consistent with the pool cap of A25-P02 and the texture limit? [Spec §Clarifications Q2] — yes.

## Privacy, Lifecycle and Ownership

- [x] CHK007 Is it explicit that no read permission is asked, only the picked item is read, and nothing is stored? [Spec §Canonical overrides, Negative Requirements] — yes.
- [x] CHK008 Is re-upload after a context loss and the decode's thread specified? [Spec §FR-A25-404, Clarifications Q4] — yes.
- [x] CHK009 Is the VisualCore change additive and owned by VisualCoreRendering, the decoder by the experience? [Plan §Project Structure] — yes.

## Acceptance and Edge Cases

- [x] CHK010 Are the outcomes measurable (8 of 8, within 3/255, exact edges, 7 of 7)? [Spec §SC-A25-401–405] — yes.
- [x] CHK011 Are cancelled picks, transparency, tiny and huge inputs, and a restored session addressed? [Spec §Edge Cases] — yes.

## Notes

- CHK003 failed at first: nothing said what the preview shows while a picture is read or what a second pick does; an
  edge case now states both.
- `/speckit-implement` reads checklist state; it does not change the markers.
