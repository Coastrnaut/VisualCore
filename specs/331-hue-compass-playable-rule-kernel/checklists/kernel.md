# Requirements Quality Checklist: R02-G04-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 331 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (select a bearing and hue band within both tolerances) and what each clue tells
  stated plainly? [Clarity, Spec §US1; Clarifications Q2, Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (bearings, bands, tolerances, allowance,
  densities)? [Clarity, Spec §Clarifications Q1, Q3]
- [x] CHK003 Is a direction exactly on a sector boundary assigned to exactly one sector? [Edge Case, Spec §Clarifications
  Q1]
- [x] CHK004 Is the arc used for the fog depth fixed when both arcs are equally long? [Edge Case, Spec §Clarifications Q2]
- [x] CHK005 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  stated? [Completeness, Spec §FR-R02G0401-006; Clarifications Q4, Q5]
- [x] CHK006 Is it excluded that a level starts already solved? [Consistency, Spec §FR-R02G0401-001] — corrected: the
  start bearing may not lie within the bearing tolerance of the target.

## Empty and error states

- [x] CHK007 Are refusals named for out-of-range actions, wrong stage, staleness and allowance, and failures named for a
  wrong selection and an exhausting probe? [Coverage, Spec §Edge Cases; Clarifications Q3, Q5]

## Accessibility (clue independence)

- [x] CHK008 Is it required that the clue has a full non-colour channel? [Coverage, Spec §FR-R02G0401-011]

## Source licence and code-only graphics

- [x] CHK009 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK010 Is it stated that layout belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK011 Are host-test sizes and the brute-force and independent-angle cross-checks stated? [Measurability, Spec
  §SC-R02G0401-001 … 003]

## Future D1/D2/D3 evidence

- [x] CHK012 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
