# Requirements Quality Checklist: Effects Composer — Phase 02 compiler and preview

**Purpose**: Unit tests for the Phase 02 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md), [plan.md](../plan.md), [contracts/experience.md](../contracts/experience.md)

`[x]` means the reviewer judged the requirement's writing satisfactory (evaluated by the lead under the owner's
standing delegation, 2026-11-19); it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Is the pass layout defined for every chain shape, including empty and all-disabled chains? [Spec §FR-A25-201, Clarifications Q1] — yes.
- [x] CHK002 Are the preview source, its size and the present step defined? [Spec §Clarifications Q2] — yes.
- [x] CHK003 Is every action listed with its value ranges and refusal ids? [Spec §FR-A25-203, Clarifications Q3] — yes.
- [x] CHK004 Is the diagnostic's content (effect, line, message) and the kept picture specified? [Spec §FR-A25-205, Clarifications Q4] — yes.
- [x] CHK005 Are accessibility requirements stated for the controls (spoken labels, no dragging)? [Spec §Clarifications Q5, constitution A25] — yes, after a correction (see Notes).

## Requirement Clarity and Consistency

- [x] CHK006 Is the pool cap quantified (targets and size) with its refusal message? [Spec §Clarifications Q2] — yes.
- [x] CHK007 Is the mapping of a normalized value to a parameter's range defined, including whole parameters? [Spec §Clarifications Q3] — yes.
- [x] CHK008 Is it consistent that the snapshot holds the chain only and a restored session has no history? [Spec §Edge Cases, Clarifications Q3] — yes.
- [x] CHK009 Is the registration's permission consistent with A25-P00's decision? [Spec §Clarifications Q5] — yes.

## Acceptance Criteria Quality

- [x] CHK010 Are success criteria measurable (100% of plans, within tolerance, byte for byte, 50 cycles and 10 rebuilds)? [Spec §SC-A25-201–206] — yes.

## Scenario and Edge Case Coverage

- [x] CHK011 Are context loss, resize, refused edits and a restored session addressed? [Spec §Edge Cases] — yes.

## Non-Functional, Architecture and Lifecycle

- [x] CHK012 Is the lifecycle (setup, draw, resize, teardown, rebuild) of programs and targets defined? [Plan §Project Structure] — yes.
- [x] CHK013 Is ownership clear (no VisualCore change; the compiler pure in the core)? [Spec §Canonical overrides] — yes.
- [x] CHK014 Are privacy and release constraints respected (a candidate only; no import, export or network)? [Spec §Negative Requirements] — yes.

## Notes

- CHK005 failed at first: the controls had identifiers but no accessibility requirement; clarification Q5 now requires
  spoken labels and button-only edits.
- `/speckit-implement` reads checklist state; it does not change the markers.
