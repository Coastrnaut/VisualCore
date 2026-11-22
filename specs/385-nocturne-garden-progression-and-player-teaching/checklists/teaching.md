# Requirements Quality Checklist: R02-G09-05 progression and player teaching

**Purpose**: Unit tests for the requirements of feature 385 (player impact, deterministic invariants, empty and error
states, accessibility, licence, layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the three tutorial instructions, their order and when each advances stated in words? [Clarity, Spec
  §Clarifications Q2; FR-R02G0905-001]
- [x] CHK002 Are the three hint levels stated with example wording for plants, sun moves and removals? [Clarity, Spec
  §Clarifications Q1]

## Deterministic invariants

- [x] CHK003 Is the hint search defined (from the current blooms and sun, plants then a sun move then one removal, the
  fewest moves within the moves and supply left, the solver's bound) so that following exact hints wins? [Completeness,
  Spec §FR-R02G0905-002; Clarifications Q1]
- [x] CHK004 Are the star thresholds, the best-result rule and the unlock rule stated in numbers? [Measurability, Spec
  §Clarifications Q3]
- [x] CHK005 Is the daily level a stated function of the date (× 71 from 2026-01-01, wrapped), with no clock in the
  core? [Clarity, Spec §Clarifications Q4]
- [x] CHK006 Is it stated what a daily win records (the level's best result and stars) and that it opens nothing?
  [Consistency, Spec §Clarifications Q4] — corrected 2026-11-22: the daily record rule was made explicit.

## Empty and error states

- [x] CHK007 Are hints on won, failed and unwinnable states defined? [Coverage, Spec §Edge Cases; Clarifications Q1]
- [x] CHK008 Are refusals named for a locked level and an impossible date? [Coverage, Spec §Clarifications Q3, Q4]
- [x] CHK009 Are both failure explanations (leak, budget) given with their exact wording and the undo/retry offer?
  [Completeness, Spec §FR-R02G0905-003; Clarifications Q5]

## Accessibility

- [x] CHK010 Is it stated that tutorial, hint and failure text appear as wrapping text in the panel, never over the
  garden? [Coverage, Spec §Assumptions]

## Licence and free content

- [x] CHK011 Is it stated that all 100 levels are free, with no advertising, accounts or network? [Completeness, Spec
  §FR-R02G0905-006]

## Versioning

- [x] CHK012 Is the schema 2 payload and its migration from schema 1 defined? [Completeness, Spec §FR-R02G0905-007;
  Clarifications Q5]

## Simulator proof

- [x] CHK013 Are the host proofs sized (all 100 levels by hints, 200 seeded states, 500 seeded failures, dates
  2026–2036)? [Measurability, Spec §SC-R02G0905-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK014 Is it stated that this feature adds no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK006 failed at first reading; the spec's daily rule was corrected before the items were judged.
