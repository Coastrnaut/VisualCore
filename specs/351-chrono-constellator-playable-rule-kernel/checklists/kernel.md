# Requirements Quality Checklist: R02-G06-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 351 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (every star on its own target on the same tick, without a collision, within the tick
  limit) and the player's two levers (start phases, holds) stated plainly? [Clarity, Spec §US1; Clarifications Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (grid, stars, loop lengths, phases, hold starts
  and lengths, budget, tick limit, the 1/120 s tick)? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK003 Is a star's position at any tick defined by one formula, so stepping and direct computation agree?
  [Measurability, Spec §FR-R02G0601-002, 003; Clarifications Q2]
- [x] CHK004 Are overlapping or touching holds of one star excluded, so the held-tick count is unambiguous? [Edge Case,
  Spec §Clarifications Q2; Edge Cases]
- [x] CHK005 Is the order of collision, win and time on one tick fixed, and is anything judged at tick 0 excluded?
  [Consistency, Spec §FR-R02G0601-005; Clarifications Q4; Edge Cases]
- [x] CHK006 Is it stated that targets are distinct, so a win and a collision can never coincide? [Consistency, Spec
  §Clarifications Q1; Edge Cases]
- [x] CHK007 Is the edit budget defined as edits in use (changed phases plus holds), so undo, release and restoring a
  phase have exact effects on it? [Clarity, Spec §Clarifications Q3]
- [x] CHK008 Are fingerprints, the timeline snapshot, records and replay defined so a trace reproduces every state, and
  is what undo and rewind cover (and that a won level is final) stated? [Completeness, Spec §FR-R02G0601-007;
  Clarifications Q4, Q5]

## Empty and error states

- [x] CHK009 Are refusals named for out-of-range actions, edits after tick 0, an unchanged phase, an overlapping hold, a
  missing hold, wrong stage, staleness and the budget, and failures named for collision (stars and cell) and time?
  [Coverage, Spec §Edge Cases; Clarifications Q3, Q4, Q5]
- [x] CHK010 Is the case of start phases that already collide covered (nothing judged at tick 0)? [Edge Case, Spec
  §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every star, its loop and its target are available in words, numbers and a shape?
  [Coverage, Spec §FR-R02G0601-013; Clarifications Q1]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the step-by-step cross-check and the boundary cases one tick either side of each limit
  stated? [Measurability, Spec §SC-R02G0601-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
