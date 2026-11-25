# Requirements Quality Checklist: R02-G17-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 461 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 451's checklist; every item
but CHK010 passed at first reading.

## Player impact

- [x] CHK001 Are the player's goal (the target eclipses in exact order, each inside its window, with no other eclipse
  first) and the player's levers (the phases of the movable bodies, then running the clock) stated plainly? [Clarity,
  Spec §US1; Clarifications Q2, Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (2 … 6 bodies, orbits of 4 … 24 positions within
  ±32, radii 1 … 8, horizon 8 … 96, target 1 … 6 eclipses, budget 1 … 24)? [Clarity, Spec §Clarifications Q1, Q2, Q3]
- [x] CHK003 Are a body's position at a tick with its phase, the overlap test and the event tick defined so two readers
  compute the same values? [Measurability, Spec §FR-R02G1701-004; Clarifications Q1]
- [x] CHK004 Are the depth order (one front body per pair at every tick) and the visibility classes (partial, total,
  annular, and an interval's class) defined without ambiguity at their boundaries? [Clarity, Spec §FR-R02G1701-002;
  Clarifications Q1]
- [x] CHK005 Is the truth metric (ordered intervals with classes, the matched prefix, the predicted outcome) required
  after every action and excluded from deciding on its own? [Measurability, Spec §FR-R02G1701-014; Clarifications Q5]
- [x] CHK006 Are the timeline order (first tick, then front, then back body) and the judge's order (match, `window`,
  `unwanted`, `horizon`; events after the last match ignored) fixed, and is it stated what each failure names?
  [Consistency, Spec §Clarifications Q3]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (phases and actions spent; from failed back to playing before the run; a won level is final) stated? [Completeness,
  Spec §FR-R02G1701-007; Clarifications Q2, Q4]

## Empty and error states

- [x] CHK008 Are refusals named for an unknown or fixed body, an offset outside the period or unchanged, no action left,
  wrong stage and staleness, and are the failures (unwanted, window, horizon) named? [Coverage, Spec §Edge Cases;
  Clarifications Q2, Q3]
- [x] CHK009 Are touching discs (no eclipse), an eclipse already under way at tick 0 (it begins at tick 0) and two
  eclipses on one tick (a fixed order) addressed? [Edge Case, Spec §Edge Cases; Clarifications Q1, Q3]
- [x] CHK010 Are malformed levels excluded (values out of range, no movable body, a broken depth order, a target eclipse
  with the same body twice or with its front body behind its back body, a window outside the horizon, starting phases
  that already win)? [Edge Case, Spec §FR-R02G1701-002; Clarifications Q1; data-model] — failed at first reading: a
  target naming the back body of its pair as the front one was not excluded, although it could never be met; FR-002 and
  the data model now refuse it.
- [x] CHK011 Are the boundaries stated (an eclipse exactly on a window's opening or closing tick is inside; the horizon's
  last tick counts; a spent budget still allows the run)? [Edge Case, Spec §Edge Cases; SC-R02G1701-004]
- [x] CHK012 Is it stated why the run costs no action and why the predicted outcome is reported before it (the timeline
  is fully determined by the phases; the run is the commitment)? [Consistency, Plan research R7]

## Accessibility (colour independence)

- [x] CHK013 Is it required that every body, eclipse and measure is available in words and numbers? [Coverage, Spec
  §FR-R02G1701-013; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK015 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK016 Are host-test sizes, the independent recomputation and the boundary cases (windows, horizon, overlap limit)
  stated? [Measurability, Spec §SC-R02G1701-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK017 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
