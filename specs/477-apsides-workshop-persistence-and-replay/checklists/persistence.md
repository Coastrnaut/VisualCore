# Requirements Quality Checklist: R02-G18-07 persistence and replay

**Purpose**: Unit tests for the requirements of feature 477 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-26
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-26, following feature 467's checklist; failures
were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what survives a save (level, tunings, actions left, mode, stars, open levels, tutorial step,
  sound choice; the shown tick, a pending orbit, a drag preview and the camera not saved) and what the player
  sees when results are dropped? [Completeness, Spec §US1; FR-R02G1807-001; Edge Cases; Clarifications Q2]

## Deterministic invariants

- [x] CHK002 Is the trace defined exactly (effective periapsis and size tunings with their steps, then the play; no undo
  or redo; actions spent still counting undone tunings) and when a result is replaced? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the reconciliation rule stated as a checkable condition (wins, the trace's tunings no more than
  the recorded actions spent, stars matching the stars rule for them and the certified tuning count) with the
  frontier kept as saved? [Measurability, Spec §FR-R02G1807-003; Clarifications Q2]
- [x] CHK004 Are the inputs of the state listed so determinism is testable (seed, catalog, date action, actions; no
  clock)? [Clarity, Spec §FR-R02G1807-005; Clarifications Q5]
- [x] CHK005 Is it stated that the sound choice and the dropped count never enter the digest? [Consistency, Spec
  §FR-R02G1807-007; Clarifications Q2, Q5]

## Empty and error states

- [x] CHK006 Are interrupted writes, damaged, edited and newer saves, and untraced results covered with named outcomes?
  [Coverage, Spec §Edge Cases; Clarifications Q3]
- [x] CHK007 Are replay refusals (no replay, replay over, stop first) and the actions still allowed during replay
  (tutorial dismiss, shown tick, sound, the pending orbit, drag previews and
  the camera, with any tuning they would send refused) defined? [Coverage, Spec §Clarifications Q4]
- [x] CHK008 Is a save taken during a replay defined (restored only when it is the start of the verified trace, else
  damaged)? [Edge Case, Spec §Edge Cases]

## Source licence and code-only graphics

- [x] CHK009 Is it stated that no network, accounts or third-party content are involved? [Consistency, Spec §Negative
  Requirements; Assumptions]

## iPad/iPhone layout

- [x] CHK010 Are the replay controls placed in the existing accessible panel on both form factors? [Coverage, Spec
  §Assumptions]

## Simulator proof

- [x] CHK011 Are sample sizes stated for round trips (500), migrations (100), edited saves (200) and certified traces
  (100)? [Measurability, Spec §SC-R02G1807-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK012 Is a save surviving a real termination deferred to D1–D3 after ImplementationLock-100? [Completeness, Spec
  §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- Every item passed at first reading; feature 467's answers (a save taken during a replay, the frontier as saved) were
  taken into the spec from the start, and the trace of tunings ending with the play is the adaptation to this game.
