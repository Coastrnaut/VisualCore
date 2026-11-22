# Requirements Quality Checklist: R02-G08-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 371 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (pieces whose shares and face counts match the target within the cut budget) and the
  player's lever (cut one piece with one plane) stated plainly? [Clarity, Spec §US1; Clarifications Q2]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact fractions with stated bounds (13 directions, depths −24 … 24, the crystal
  box, budget, sliver limit) and with overflow refused? [Clarity, Spec §Clarifications Q1, Q3]
- [x] CHK003 Is a cut defined as exactly two convex halves of one piece, with every other piece unchanged and the
  pieces kept in a stated canonical order? [Measurability, Spec §FR-R02G0801-002; Clarifications Q2]
- [x] CHK004 Is the truth metric (volumes sum to the crystal's, every edge on exactly two faces) required after every
  cut? [Measurability, Spec §FR-R02G0801-014; Clarifications Q3]
- [x] CHK005 Is the order of sliver, win and budget after a cut fixed, and is a win before the first cut excluded?
  [Consistency, Spec §FR-R02G0801-005; Clarifications Q4; Edge Cases]
- [x] CHK006 Is "within tolerance" defined (exact equality of fractions) and the target a multiset, so order does not
  matter? [Clarity, Spec §Assumptions; Edge Cases]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (and that a won level is final) stated? [Completeness, Spec §FR-R02G0801-007; Clarifications Q4, Q5]

## Empty and error states

- [x] CHK008 Are refusals named for out-of-range actions, a degenerate cut, wrong stage and staleness, and failures
  named for a sliver (piece and cut) and the budget? [Coverage, Spec §Edge Cases; Clarifications Q2, Q4, Q5]
- [x] CHK009 Are malformed levels excluded (a crystal without interior or outside the box, shares not summing to one,
  fewer than two target pieces, a sliver limit out of range)? [Edge Case, Spec §FR-R02G0801-001; Clarifications Q1]
- [x] CHK010 Is the sliver limit's boundary stated (equal is allowed, below fails)? [Edge Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every piece, direction and target entry is available in words and numbers?
  [Coverage, Spec §FR-R02G0801-013; Clarifications Q1, Q2]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the independent geometric cross-check and the boundary cases (sliver limit, one cut
  either side of the budget) stated? [Measurability, Spec §SC-R02G0801-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]
