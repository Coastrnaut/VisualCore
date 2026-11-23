# Requirements Quality Checklist: R02-G12-05 progression and player teaching

**Purpose**: Unit tests for the requirements of feature 415 (player impact, deterministic invariants, empty and error
states, accessibility, licence, layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the three tutorial instructions, their order and when each advances stated in words, including a
  tuning that completes two steps at once? [Clarity, Spec §Clarifications Q2; FR-R02G1205-001] — corrected 2026-11-23:
  a first tuning that already bridged every step left the second step's end undefined.
- [x] CHK002 Are the three hint levels stated with example wording for both kinds (tune: kind, string, peg; test)?
  [Clarity, Spec §Clarifications Q1]

## Deterministic invariants

- [x] CHK003 Is the hint plan defined (the solver's minimal plan at the current pegs, locks kept; the test when the
  pegs already bridge every step) so that following exact hints from a level's start wins? [Completeness, Spec
  §FR-R02G1205-002; Clarifications Q1; Research R1]
- [x] CHK004 Is "within the moves left" defined precisely (the plan's tunings plus the test fit the actions left) and
  is the work-bound case worded? [Clarity, Spec §Clarifications Q1]
- [x] CHK005 Are the star thresholds, the best-result rule and the unlock rule stated in numbers, with what counts as
  actions spent (undone records included)? [Measurability, Spec §Clarifications Q3]
- [x] CHK006 Is the daily level a stated function of the date (× 83 from 2026-01-01, wrapped), with no clock in the
  core? [Clarity, Spec §Clarifications Q4]
- [x] CHK007 Is it stated what a daily win records (the level's best result and stars) and that it opens nothing?
  [Consistency, Spec §Clarifications Q4]

## Empty and error states

- [x] CHK008 Are hints on won, failed and unwinnable states defined? [Coverage, Spec §Edge Cases; Clarifications Q1]
- [x] CHK009 Are refusals named for a locked level and an impossible date? [Coverage, Spec §Edge Cases; Clarifications
  Q3, Q4]
- [x] CHK010 Is the failure explanation given with its exact wording for both failures (a broken test, with or without
  a string; the exhausted budget after a tuning or a test) and the undo/retry offer, with its numbering stated?
  [Completeness, Spec §FR-R02G1205-003; Clarifications Q5]

## Accessibility

- [x] CHK011 Is it stated that tutorial, hint and failure text appear as wrapping text in the panel, never over the
  bridges? [Coverage, Spec §Assumptions]

## Licence and free content

- [x] CHK012 Is it stated that all 100 levels are free, with no advertising, accounts or network? [Completeness, Spec
  §FR-R02G1205-006]

## Versioning

- [x] CHK013 Is the schema 2 payload and its migration from schema 1 defined? [Completeness, Spec §FR-R02G1205-007;
  Clarifications Q5]

## Simulator proof

- [x] CHK014 Are the host proofs sized (all 100 levels by hints, 200 seeded states, 500 seeded failures, dates
  2026–2036)? [Measurability, Spec §SC-R02G1205-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature adds no device-only item beyond the round's device campaign? [Completeness,
  Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK001 failed at first reading; the spec was corrected before the item was judged.
