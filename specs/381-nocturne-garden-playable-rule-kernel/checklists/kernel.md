# Requirements Quality Checklist: R02-G09-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 381 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (a shadow mask matching the target closely enough without leaking into the forbidden
  regions, within the move budget) and the player's levers (plant, move, resize, remove blooms; set the sun) stated
  plainly? [Clarity, Spec §US1; Clarifications Q1, Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (bed 16 … 32 × 12 … 24, six fixed outlines,
  sizes 1 … 3, four sun elevations with factor e/2)? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the cell test defined exactly (cell centre inside or on the boundary of the cast polygon, doubled integer
  coordinates, winding number) and the mask as the union clipped to the bed? [Measurability, Spec §Clarifications Q2]
- [x] CHK004 Is the truth metric (the mask recomputed from scratch equals the kept mask; the boundary deviation computed
  exactly) required after every action? [Measurability, Spec §FR-R02G0901-014; Clarifications Q4]
- [x] CHK005 Is the order of leak, win and budget after an action fixed, and is a win before the first bloom excluded?
  [Consistency, Spec §FR-R02G0901-005; Clarifications Q4; Edge Cases]
- [x] CHK006 Is "IoU exceeds requirement" defined (at least p/q, by cross multiplication, an empty union never wins)?
  [Clarity, Spec §Assumptions; Clarifications Q2]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (and that a won level is final) stated? [Completeness, Spec §FR-R02G0901-007; Clarifications Q4, Q5]

## Empty and error states

- [x] CHK008 Are refusals named for out-of-range actions, an exhausted supply, an action that changes nothing, wrong
  stage and staleness, and failures named for a leak (the action) and the budget? [Coverage, Spec §Edge Cases;
  Clarifications Q3, Q4, Q5]
- [x] CHK009 Are malformed levels excluded (bed out of range, forbidden cells overlapping the target, an empty target, a
  supply out of range, a required match outside (0, 1])? [Edge Case, Spec §FR-R02G0901-001; data-model]
- [x] CHK010 Are the boundaries stated (a match equal to the requirement wins, a leak equal to the allowance is
  allowed)? [Edge Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every bloom, region and measure is available in words and numbers?
  [Coverage, Spec §FR-R02G0901-013; Clarifications Q1, Q3]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design and the bloom outlines are the project's own and nothing is drawn in this
  feature? [Consistency, Spec §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the independent cell cross-check and the boundary cases (leak allowance, one move
  either side of the budget) stated? [Measurability, Spec §SC-R02G0901-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]
