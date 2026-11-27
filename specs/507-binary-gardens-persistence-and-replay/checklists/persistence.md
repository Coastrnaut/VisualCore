# Requirements Quality Checklist: R02-G21-07 persistence and replay

**Purpose**: Unit tests for the requirements of feature 507 (player impact, deterministic invariants, empty and error
states, restore work, source licence, iPad/iPhone layout, changed tests, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 497's checklist, after the
items were generated in this skill invocation; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what survives a save (level, rings, phases, luminosities, tilt, actions left, mode, stars,
  open levels, tutorial step, sound choice; the shown tick, the selected star, previews, the inspected world, the hint
  level and the view not saved) and what the player hears and sees when results are dropped? [Completeness, Spec §US1;
  FR-R02G2107-001; Edge Cases; Clarifications Q2]

## Deterministic invariants

- [x] CHK002 Is the trace defined exactly (effective ring, phase, luminosity and tilt actions, then the run; no undo or
  redo; actions spent still counting undone actions) and when a result is replaced (fewer actions; a tie keeps the
  earlier trace)? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the reconciliation rule stated as a checkable condition (wins on a fresh campaign play, the trace's
  actions no more than the recorded actions spent, stars matching the stars rule) with the frontier kept as saved?
  [Measurability, Spec §FR-R02G2107-003; Clarifications Q2]
- [x] CHK004 Are the inputs of the state listed so determinism is testable (seed, catalog, date action, actions; no
  clock)? [Clarity, Spec §FR-R02G2107-005; Clarifications Q5]
- [x] CHK005 Is it stated what digest v3 covers (level, play fingerprint, progress with traces, mode) and that the
  sound choice, the tutorial step, the shown tick and the dropped count never enter it? [Consistency, Spec
  §Clarifications Q5, Q6]

## Empty and error states

- [x] CHK006 Are interrupted writes, damaged, edited and newer saves, traces over 64 actions, traces without a final run
  and verified results with empty traces covered with named outcomes? [Coverage, Spec §Edge Cases; Clarifications Q2,
  Q3]
- [x] CHK007 Are replay refusals (`r02-g21.no-replay`, `r02-g21.replay-end`, `r02-g21.replay`) and the actions still
  allowed during replay (tick scrubbing, sound, presentation) defined, with any arrangement action refused? [Coverage,
  Spec §Clarifications Q4; FR-R02G2107-006]
- [x] CHK008 Is a save taken during a replay defined (restored only when its records are the start of the verified
  trace, else damaged)? [Edge Case, Spec §Clarifications Q4]

## Restore work

- [x] CHK009 Is the restore work bounded by count (at most 100 results × 64 actions, the certifying solver run at most
  once per level per process with at most 5,000 arrangements judged)? [Measurability, Spec §Edge Cases]

## Source licence and layout

- [x] CHK010 Is it stated that no network, accounts or third-party content are involved? [Consistency, Spec §Negative
  Requirements; Assumptions]
- [x] CHK011 Are the replay controls placed in the existing accessible panel on both form factors, with announcements?
  [Coverage, Spec §FR-R02G2107-008]

## Changed tests

- [x] CHK012 Are the existing assertions that change named, the newer-schema literal versions and the snapshot schema
  version included? [Traceability, Spec §Clarifications Q6; SC-R02G2107-005]

## Simulator proof

- [x] CHK013 Are sample sizes stated for round trips (500), migrations (100), edited saves (200) and certified traces
  (100), and the simulator replay proof through the experience port? [Measurability, Spec §SC-R02G2107-001 … 004, 006]

## Future D1/D2/D3 evidence

- [x] CHK014 Is a save surviving a real termination deferred to D1–D3 after ImplementationLock-100? [Completeness, Spec
  §SC-R02G2107-007]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK005, CHK009 and CHK012 failed at first reading and were corrected in the spec: digest v3's parts were named only
  by version; the Restore work edge case said no restore runs a search although a level's first use in a process runs
  its certifying solver; and the changed tests omitted the newer-schema literal versions and the snapshot schema
  assertion. FR-006 also listed `r02-g21.not-whole` as new; it now says the existing code covers the new controls.
