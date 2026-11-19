# Requirements Quality Checklist: Effects Composer — Phase 03 editing, compare and presets

**Purpose**: Unit tests for the Phase 03 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [contracts/presets.md](../contracts/presets.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are the preset files, index, caps, name rules, refusal codes and messages all specified? [Spec §Clarifications Q2] — yes.
- [x] CHK002 Is what compare shows, and whether it is stored, specified? [Spec §FR-A25-301, Clarifications Q1] — yes.
- [x] CHK003 Is opening over unsaved changes specified? [Spec §Edge Cases] — yes, after a correction (see Notes).
- [x] CHK004 Are the accessibility actions listed per node, including their absence at the ends? [Spec §Clarifications Q5] — yes.

## Requirement Clarity and Consistency

- [x] CHK005 Is the aliasing audit defined over every drawn pass, not only the plan? [Spec §FR-A25-304, Clarifications Q4] — yes.
- [x] CHK006 Is the move of import and export to later phases consistent with the manual's gates and recorded? [Spec §Canonical overrides, research R1] — yes.
- [x] CHK007 Are the presenter's library actions and the core's `replace` edit consistent with "one undoable edit"? [Spec §Clarifications Q3] — yes.

## Acceptance Criteria Quality

- [x] CHK008 Are the outcomes measurable (100% of pixels, equal with the same fingerprint, 0 aliasing passes)? [Spec §SC-A25-301–305] — yes.

## Edge Cases and Recovery

- [x] CHK009 Are empty chain compare, invalid names, duplicate names, full storage and context loss with compare on addressed? [Spec §Edge Cases] — yes.
- [x] CHK010 Is the treatment of damaged and newer files and indexes defined without automatic deletion? [Spec §FR-A25-303, Clarifications Q2] — yes.

## Non-Functional, Architecture and Lifecycle

- [x] CHK011 Is storage local with no network, and is the library independent of graphics? [Spec §Negative Requirements, Plan] — yes.
- [x] CHK012 Is ownership clear (no VisualCore change; the library app-local after GraphLibrary)? [Spec §Canonical overrides] — yes.

## Notes

- CHK003 failed at first: the spec said opening is undoable but not whether a confirmation is asked over unsaved
  changes; the edge case now says none is asked because undo returns them.
- `/speckit-implement` reads checklist state; it does not change the markers.
