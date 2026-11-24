# Requirements Quality Checklist: R02-G14-07 persistence and replay

**Purpose**: Unit tests for the requirements of feature 437 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 427's checklist; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what survives a save (level, gear phases, lamp height, actions left, mode, stars, open levels, tutorial step,
  sound choice; the shown key frame not saved) and what the player sees when results are dropped? [Completeness, Spec §US1; FR-R02G1407-001; Clarifications
  Q2]

## Deterministic invariants

- [x] CHK002 Is the trace defined exactly (effective turns, re-seats and lamp steps and the run, no undo or redo; actions spent still counting
  undone actions) and when a result is replaced? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the reconciliation rule stated as a checkable condition (wins, the trace's actions no more than the
  recorded actions spent, stars matching the stars rule for them) with the frontier kept as saved? [Measurability, Spec
  §FR-R02G1407-003; Clarifications Q2]
- [x] CHK004 Are the inputs of the state listed so determinism is testable (seed, catalog, date action, actions; no
  clock)? [Clarity, Spec §FR-R02G1407-005; Clarifications Q5]
- [x] CHK005 Is it stated that the sound choice and the dropped count never enter the digest? [Consistency, Spec
  §FR-R02G1407-007; Clarifications Q2, Q5]

## Empty and error states

- [x] CHK006 Are interrupted writes, damaged, edited and newer saves, and untraced results covered with named outcomes?
  [Coverage, Spec §Edge Cases; Clarifications Q3]
- [x] CHK007 Are replay refusals (no replay, replay over, stop first) and the actions still allowed during replay
  (tutorial dismiss, key frame shown, sound, the panel's chosen gear, the camera) defined? [Coverage, Spec §Clarifications Q4]

## Source licence and code-only graphics

- [x] CHK012 Is a save taken during a replay defined (restored only when it is the start of the verified trace, else
  damaged)? [Edge Case, Spec §Edge Cases] — corrected 2026-11-24: the plan required it but the spec did not state it.
- [x] CHK008 Is it stated that no network, accounts or third-party content are involved? [Consistency, Spec §Negative
  Requirements; Assumptions]

## iPad/iPhone layout

- [x] CHK009 Are the replay controls placed in the existing accessible panel on both form factors? [Coverage, Spec
  §Assumptions]

## Simulator proof

- [x] CHK010 Are sample sizes stated for round trips (500), migrations (100), edited saves (200) and certified traces
  (100)? [Measurability, Spec §SC-R02G1407-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK011 Is a save surviving a real termination deferred to D1–D3 after ImplementationLock-100? [Completeness, Spec
  §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK012 failed at first reading; the spec was corrected before the item was judged.
