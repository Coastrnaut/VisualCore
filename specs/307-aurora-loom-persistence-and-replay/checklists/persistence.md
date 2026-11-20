# Requirements Quality Checklist: R02-G01-07 persistence and replay

**Purpose**: Unit tests for the requirements of feature 307 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a returning player finds (level, moves, mode, stars, open levels) and that earlier
  progress is never lost silently? [Completeness, Spec §US1]
- [x] CHK002 Is what a player sees when results are dropped defined (a count, announced once)? [Clarity, Spec
  §Clarifications Q2]

## Deterministic invariants

- [x] CHK003 Are all inputs of the state named so a save restores and replays identically on every device? [Clarity,
  Spec §FR-R02G0107-005; Clarifications Q5]
- [x] CHK004 Is the reconciliation rule exact (wins in exactly the recorded moves with the recorded stars)? [Measurability,
  Spec §Clarifications Q2]
- [x] CHK005 Is the replacement rule for a better win (fewer moves; ties keep the earlier trace) defined? [Clarity, Spec
  §Clarifications Q1]

## Empty and error states

- [x] CHK006 Are damaged, newer, edited and old (traceless) saves, a replay without a trace and a replay past its end
  each given an outcome and a code? [Coverage, Spec §Edge Cases; Clarifications Q2–Q4]

## Source licence and code-only graphics

- [x] CHK007 Is it stated that no network, accounts or third-party content are involved? [Consistency, Spec §Excluded
  scope; Assumptions]

## iPad/iPhone layout

- [x] CHK008 Is it stated where the replay controls live and that they inherit the accessible, scrolling panel?
  [Completeness, Spec §Assumptions] — corrected: they join the R02-G01-06 panel with labels and values.

## Simulator proof

- [x] CHK009 Are the property-test sizes (500 round trips, 100 migrations, 200 edited saves, 100 traces) stated?
  [Measurability, Spec §SC-R02G0107-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK010 Is the hardware observation (progress surviving a real termination) deferred to ImplementationLock-100?
  [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
