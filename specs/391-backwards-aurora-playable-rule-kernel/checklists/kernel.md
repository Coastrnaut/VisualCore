# Requirements Quality Checklist: R02-G10-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 391 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (every checkpoint at its true height and every bend within the limit, within the
  reversal budget) and the player's lever (reverse a section chosen by its two ends) stated plainly? [Clarity, Spec
  §US1; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (N 12 … 32 samples, heights −64 … 64, L 1 … 64,
  B L … 128, sections 2 … N, budget)? [Clarity, Spec §Clarifications Q1, Q2]
- [x] CHK003 Is the bend defined exactly (second difference at interior positions) and is it stated which bends a
  reversal can change (positions i − 1, i, j, j + 1)? [Measurability, Spec §FR-R02G1001-003; Clarifications Q2]
- [x] CHK004 Is the truth metric (distance as an exact fraction, 0/1 for an all-zero target; worst bend) required after
  every action and excluded from deciding? [Measurability, Spec §FR-R02G1001-014; Clarifications Q4]
- [x] CHK005 Is the order of tear, win and budget after a reversal fixed? [Consistency, Spec §FR-R02G1001-005;
  Clarifications Q4]
- [x] CHK006 Is it stated why the target must hold the opening wave's multiset of heights (a reversal only reorders)?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (from failed back to playing; a won level is final) stated? [Completeness, Spec §FR-R02G1001-007; Clarifications Q4,
  Q5]

## Empty and error states

- [x] CHK008 Are refusals named for out-of-range or wrong-length sections, a section that reads the same both ways,
  wrong stage and staleness, and failures named for a tear (the reversal and the seam) and the budget? [Coverage, Spec
  §Edge Cases; Clarifications Q3, Q4, Q5]
- [x] CHK009 Are malformed levels excluded (lengths or heights out of range, a target that is not a reordering,
  checkpoints out of range or repeated, B < L, section limits out of order, an opening wave that already wins)? [Edge
  Case, Spec §Clarifications Q5; data-model]
- [x] CHK010 Are the boundaries stated (a bend equal to L is smooth, equal to B does not tear, B + 1 tears; a win on the
  last reversal wins)? [Edge Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every sample, checkpoint, seam and measure is available in words and numbers?
  [Coverage, Spec §FR-R02G1001-013]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the independent recomputation and the boundary cases (breaking limit, one reversal
  either side of the budget) stated? [Measurability, Spec §SC-R02G1001-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]
