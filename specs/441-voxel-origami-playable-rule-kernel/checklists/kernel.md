# Requirements Quality Checklist: R02-G15-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 441 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 431's checklist. CHK009
first failed (a hinge whose descendants all lie on its axis would spend an action and move nothing, while only leaf
hinges were refused); clarification Q2 now refuses every hinge with nothing that would move, and every item passes.

## Player impact

- [x] CHK001 Are the player's goal (the occupied cells equal the target solid up to a translation and an allowed
  orientation) and the player's lever (turn a hinge by a quarter turn either way) stated plainly? [Clarity, Spec §US1;
  Clarifications Q2, Q4]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (4 … 12 cubes, six rest directions, quarter
  turns 0 … 3, the 24 cube rotations, budget 1 … 40)? [Clarity, Spec §Clarifications Q1, Q2, Q5]
- [x] CHK003 Are the pose rule (x(i) = x(p) + O(p) · d(i), O(i) = O(p) · R(d(i), q(i)), right-hand rule), which cubes
  swing on a turn and which stand still defined? [Measurability, Spec §FR-R02G1501-002; Clarifications Q2, Q3]
- [x] CHK004 Are the end-pose collision and the swept band (same coordinate along the axis, inside the quarter arc's
  box, strictly within one cell of its circle, integer squares) defined so two readers decide every case the same?
  [Clarity, Spec §FR-R02G1501-003; Clarifications Q3]
- [x] CHK005 Is the truth metric (occupancy, canonical hash, covered count with its alignment) required after every
  action and excluded from deciding on its own? [Measurability, Spec §FR-R02G1501-014; Clarifications Q4]
- [x] CHK006 Is the order of decisions after a turn fixed (collision, then sweep, then the match, then the budget) and
  is it stated which cubes and cell a failure names (the lowest swinging cube, the still cube, its cell)? [Consistency,
  Spec §Clarifications Q3, Q5]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (quarter turns, actions spent; from failed back to playing with the action refunded; a won level is final) stated?
  [Completeness, Spec §FR-R02G1501-007; Clarifications Q5]

## Empty and error states

- [x] CHK008 Are refusals named for an unknown hinge, a step other than ±1, wrong stage and staleness, and are the
  failures (collision, sweep, budget) named? [Coverage, Spec §Edge Cases; Clarifications Q3, Q5]
- [x] CHK009 Is a turn that would move nothing addressed (a leaf hinge, or a hinge whose descendants all lie on its
  axis)? [Edge Case, Spec §Clarifications Q2; Edge Cases]
- [x] CHK010 Are malformed levels excluded (values out of range, a cube without a lower-index parent, a rest or starting
  pose with two cubes in one cell, a target with a wrong count or repeated cells, a starting pose that already matches)?
  [Edge Case, Spec §Clarifications Q1, Q4; data-model]
- [x] CHK011 Are the boundaries stated (a cube landing beside another is allowed, inside it fails; a sweep that just
  clears is allowed, one that touches fails; a match only after a disallowed rotation is no win; a turn on the last
  action can win)? [Edge Case, Spec §Edge Cases; SC-R02G1501-004]
- [x] CHK012 Is it stated why "disconnected hierarchy" cannot arise from a turn and what guards it (the re-check after
  every turn and the refusal of damaged stored states)? [Consistency, Spec §Clarifications Q2; Assumptions]

## Accessibility (colour independence)

- [x] CHK013 Is it required that every cube, hinge and measure is available in words and numbers? [Coverage, Spec
  §FR-R02G1501-013]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK015 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK016 Are host-test sizes, the independent recomputation and the boundary cases (budget, collision, sweep)
  stated? [Measurability, Spec §SC-R02G1501-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK017 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
