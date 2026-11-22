# Requirements Quality Checklist: R02-G07-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 361 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (the pearl leaves the outer shell through its exit gap within the move budget) and
  the player's two levers (rotate a shell, advance the pearl) stated plainly? [Clarity, Spec §US1; Clarifications Q2]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (sectors, shells, offsets, apertures, walls,
  wedges, start, budget)? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK003 Is the advance defined as exactly one transition with a fixed priority (outward, then clockwise, then
  refused), so the same offsets always give the same move? [Measurability, Spec §FR-R02G0701-003; Clarifications Q2]
- [x] CHK004 Is it stated that the pearl turns only with its own shell, and that a full turn of N steps returns the same
  state? [Edge Case, Spec §FR-R02G0701-002; Edge Cases]
- [x] CHK005 Is the order of exit, wedge and budget after a move fixed, and is a win before the first move excluded?
  [Consistency, Spec §FR-R02G0701-005; Clarifications Q4; Edge Cases]
- [x] CHK006 Is the budget defined so undo, redo and refused actions have exact effects on it (and an exit on the last
  move wins)? [Clarity, Spec §Clarifications Q3; Edge Cases]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (and that a won level is final) stated? [Completeness, Spec §FR-R02G0701-007; Clarifications Q4, Q5]

## Empty and error states

- [x] CHK008 Are refusals named for out-of-range actions, a stuck advance, wrong stage and staleness, and failures named
  for a wedge (shell and sector) and the budget? [Coverage, Spec §Edge Cases; Clarifications Q2, Q4, Q5]
- [x] CHK009 Are malformed levels excluded (no aperture in a shell, more than one exit gap, every sector blocked, a
  blocked start, a full ring of walls)? [Edge Case, Spec §Clarifications Q1]

## Accessibility (colour independence)

- [x] CHK010 Is it required that every shell, sector, aperture, wall and wedge is available in words and numbers?
  [Coverage, Spec §FR-R02G0701-013; Clarifications Q1]

## Source licence and code-only graphics

- [x] CHK011 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK012 Is it stated that layout belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK013 Are host-test sizes, the independent pocket-graph cross-check and the boundary cases one move either side
  of the budget stated? [Measurability, Spec §SC-R02G0701-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK014 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
