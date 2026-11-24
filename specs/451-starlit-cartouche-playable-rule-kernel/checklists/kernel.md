# Requirements Quality Checklist: R02-G16-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 451 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-24
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-24, following feature 441's checklist; every item
passed at first reading.

## Player impact

- [x] CHK001 Are the player's goal (the drawn strokes equal the symbol and the ship rests at the beacon) and the
  player's levers (choose the next star and the wait before departure) stated plainly? [Clarity, Spec §US1;
  Clarifications Q2, Q4]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (4 … 12 stars, orbits of 1 … 4 positions within
  ±8, glyph points on a 5 × 5 grid, range 1 … 12, travel 1 … 3, waits 0 … 8, deadline 1 … 64, budget 1 … 16)?
  [Clarity, Spec §Clarifications Q1, Q2, Q5]
- [x] CHK003 Are a star's position at a beat, the range test at the departure beat and the departure and arrival beats
  of a leg defined so two readers compute the same values? [Measurability, Spec §FR-R02G1601-002; Clarifications Q1, Q2]
- [x] CHK004 Are the hazard meeting rule (closed intervals on the same corridor) and the window rules (departure at most
  the close of the star left, arrival within the destination's window) defined without ambiguity at the boundaries?
  [Clarity, Spec §FR-R02G1601-003; Clarifications Q3]
- [x] CHK005 Is the truth metric (missing and stray strokes, mismatch, hazard clearance) required after every action and
  excluded from deciding on its own? [Measurability, Spec §FR-R02G1601-014; Clarifications Q4]
- [x] CHK006 Is the order of decisions after a leg fixed (departure window, hazard, arrival window, deadline, stroke,
  then the win, then the budget) and is it stated what each failure names? [Consistency, Spec §Clarifications Q3, Q5]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (star, beat, drawn strokes, legs, actions spent; from failed back to playing with the action refunded; a won level is
  final) stated? [Completeness, Spec §FR-R02G1601-007; Clarifications Q5]

## Empty and error states

- [x] CHK008 Are refusals named for an unknown star, the same star, no corridor, a wait out of range, stars out of range,
  wrong stage and staleness, and are the failures (window, hazard, deadline, stroke, budget) named? [Coverage, Spec
  §Edge Cases; Clarifications Q2, Q3, Q5]
- [x] CHK009 Is a retraced stroke addressed (allowed, drawn once)? [Edge Case, Spec §Edge Cases; Clarifications Q4]
- [x] CHK010 Are malformed levels excluded (values out of range, repeated glyph points, duplicate or self corridors,
  windows outside 0 … deadline, a start window without beat 0, symbol strokes that are not corridors, an empty symbol)?
  [Edge Case, Spec §Clarifications Q1, Q3, Q5; data-model]
- [x] CHK011 Are the boundaries stated (arrival exactly on a window edge or the deadline is allowed; a hazard ending one
  beat before departure is clear; a leg on the last action can win)? [Edge Case, Spec §Edge Cases; SC-R02G1601-004]
- [x] CHK012 Is it stated why an out-of-range leg is refused rather than failed (it changes nothing and would only grow
  the search)? [Consistency, Plan research R3]

## Accessibility (colour independence)

- [x] CHK013 Is it required that every star, corridor and measure is available in words and numbers? [Coverage, Spec
  §FR-R02G1601-013]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK015 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK016 Are host-test sizes, the independent recomputation and the boundary cases (budget, windows, deadline,
  hazard, range) stated? [Measurability, Spec §SC-R02G1601-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK017 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
