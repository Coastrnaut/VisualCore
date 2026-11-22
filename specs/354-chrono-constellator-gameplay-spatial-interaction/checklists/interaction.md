# Requirements Quality Checklist: R02-G06-04 gameplay spatial interaction

**Purpose**: Unit tests for the requirements of feature 354 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what each gesture does for the player (drag a star to set its start, scrub the timeline,
  long-press to toggle a hold, tap to select, two fingers orbit, double tap resets)? [Clarity, Spec §US1–US4;
  Clarifications Q1–Q5]

## Deterministic invariants

- [x] CHK002 Are the distances (tap 10, drag 16, minimum target 22 points), the long press (0.5 s), the double-tap window
  (0.35 s), the timeline band (0.25·u) and the orbit bounds stated numerically? [Clarity, Spec §Clarifications Q1–Q4]
- [x] CHK003 Is picking defined so one touch has exactly one result (star before field, timeline band before cells,
  nearest within the target)? [Clarity, Spec §FR-R02G0604-004; Clarifications Q1, Q2]
- [x] CHK004 Is the tick a scrub reaches defined by a formula and required to equal a plain replay? [Measurability, Spec
  §FR-R02G0604-002; SC-R02G0604-003]
- [x] CHK005 Is it stated that only event timestamps are read, so a long press is judged without a clock? [Clarity, Spec
  §Clarifications Q3, Q5]
- [x] CHK006 Is it stated that the orbit never enters the digest, snapshot or kernel and is not saved? [Completeness,
  Spec §FR-R02G0604-005; Clarifications Q4]

## Empty and error states

- [x] CHK007 Are cancels, second fingers, short drags, edits after tick 0, won and failed plays and a used-up budget
  covered? [Coverage, Spec §Edge Cases; US1 scenario 3]
- [x] CHK008 Are the stages in which scrubbing works consistent between the edge cases and the clarification (playing and
  failed; never won)? [Consistency, Spec §Edge Cases; Clarifications Q2]

## Accessibility

- [x] CHK009 Is every gesture available through the panel, including winning every level, with rewind, undo and redo as
  buttons? [Coverage, Spec §FR-R02G0604-003, 007; SC-R02G0604-005]

## Source licence and code-only graphics

- [x] CHK010 Is the drag highlight drawn in code with no assets and no new shader? [Consistency, Spec §Assumptions;
  Plan research R6]

## iPad/iPhone layout

- [x] CHK011 Is the orbit framing required for aspects 0.4 … 2.5 with a 5 % margin? [Coverage, Spec §FR-R02G0604-005]

## Simulator proof

- [x] CHK012 Are host scripted gestures and simulator wiring tests both required, with sample sizes? [Measurability,
  Spec §SC-R02G0604-001; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK013 Is touch feel and latency deferred to devices after ImplementationLock-100? [Completeness, Spec
  §SC-R02G0604-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
