# Requirements Quality Checklist: R02-G18-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 471 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-25
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-25, following feature 461's checklist; every item
but CHK010 passed at first reading.

## Player impact

- [x] CHK001 Are the player's goal (every target met in order, no contact with an exclusion planet) and the player's
  levers (the periapsis knob for eccentricity and direction, the size, then playing the revolution) stated plainly?
  [Clarity, Spec §US1; Clarifications Q3, Q4]

## Deterministic invariants

- [x] CHK002 Is every rule decided on integers with stated bounds (size 8 … 48, eccentricity steps 0 … 15, direction
  steps 0 … 23, period 16 … 96 and even, planets 0 … 6, targets 1 … 6, budget 1 … 24)? [Clarity, Spec §Clarifications
  Q1, Q3, Q4]
- [x] CHK003 Are orbit validity (a(20 − k) ≥ 60, a(20 + k) ≤ 1280), the fixed-point Kepler inversion (start value,
  Newton step limit, stopping residual, bisection bracket and steps), the residual bound and the rounding of positions
  defined so two readers compute the same values? [Measurability, Spec §FR-R02G1801-002, 003; Clarifications Q1]
- [x] CHK004 Are the sectors and their boundary rule, the quadrature (one triangle per tick, counted for P(t)), the share
  unit and its rounding, and the apsis readings defined without ambiguity at their boundaries? [Clarity, Spec
  §FR-R02G1801-004; Clarifications Q2]
- [x] CHK005 Is the truth metric (largest Kepler residual, deviation of every target, first contact, first unmet target,
  predicted outcome) required after every action and excluded from deciding on its own? [Measurability, Spec
  §FR-R02G1801-014; Clarifications Q5]
- [x] CHK006 Are the event ticks of each target kind, the judge's order (contact first by tick then planet; then targets
  in order: `order`, `share`, `apsis-sector`, `apsis-distance`) fixed, and is it stated what each failure names?
  [Consistency, Spec §Clarifications Q3]
- [x] CHK007 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (orbit and actions spent; from failed back to playing before the play; a won level is final) stated? [Completeness,
  Spec §FR-R02G1801-007; Clarifications Q4]

## Empty and error states

- [x] CHK008 Are refusals named for a tuning out of range, unchanged or making the orbit invalid, no action left, wrong
  stage and staleness, and are the failures (contact, order, share, apsis sector, apsis distance) named? [Coverage, Spec
  §Edge Cases; Clarifications Q3, Q4]
- [x] CHK009 Are a grazing planet (no contact), a sector never entered (share 0, event tick T), a point on a sector
  boundary and a circular orbit's apsis direction addressed? [Edge Case, Spec §Edge Cases; Clarifications Q2, Q3]
- [x] CHK010 Are malformed levels excluded (values out of range, a reversed share band or distance range, a planet over
  the star, an invalid starting orbit, a starting orbit that already wins, duplicate targets)? [Edge Case, Spec
  §FR-R02G1801-001; data-model] — failed at first reading: reversed bands and ranges and duplicate targets were only
  implied by "lowest and highest"; FR-001 and the data model now refuse them.
- [x] CHK011 Are the boundaries stated (a share exactly on a band bound is inside; a distance on a range bound is
  inside; a spent budget still allows the play)? [Edge Case, Spec §Edge Cases; SC-R02G1801-004]
- [x] CHK012 Is it stated why the play costs no action and why the predicted outcome is reported before it (the orbit
  determines everything; the play is the commitment)? [Consistency, Plan research R8]

## Accessibility (colour independence)

- [x] CHK013 Is it required that every sector, target, planet and measure is available in words and numbers? [Coverage,
  Spec §FR-R02G1801-013; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK014 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK015 Is it stated that layout and gestures belong to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK016 Are host-test sizes, the independent recomputation (including the `Double` Kepler reference) and the
  boundary cases (share bands, distance ranges, contact) stated? [Measurability, Spec §SC-R02G1801-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK017 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
