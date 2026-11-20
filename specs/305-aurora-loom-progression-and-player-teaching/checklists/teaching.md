# Requirements Quality Checklist: R02-G01-05 progression and teaching

**Purpose**: Unit tests for the requirements of feature 305 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the three hint levels and what each reveals defined, and is it stated that hints never move anything?
  [Clarity, Spec §FR-R02G0105-002; Clarifications Q1]
- [x] CHK002 Is a failure explanation required to name the exact cause instead of a generic message? [Clarity, Spec
  §FR-R02G0105-003; Clarifications Q5]

## Deterministic invariants

- [x] CHK003 Are the star, unlock, daily-level and practice rules defined numerically? [Measurability, Spec
  §Clarifications Q3, Q4]
- [x] CHK004 Is it stated that the core never reads a clock and that progress is versioned with a migration? [Consistency,
  Spec §Clarifications Q4, Q5]

## Empty and error states

- [x] CHK005 Are hints with no solution in the moves left, hints after the end, locked levels and invalid dates given
  outcomes and codes? [Coverage, Spec §Edge Cases; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK006 Is the teaching text original and does the feature avoid assets? [Consistency, Spec §Assumptions]

## iPad/iPhone layout and accessibility

- [x] CHK007 Is it stated how the new texts reach VoiceOver and who owns the panel's large-text layout? [Completeness,
  Spec §Assumptions] — corrected: plain panel text now; layout polish R02-G01-06.

## Simulator proof

- [x] CHK008 Are host tests for the rules and a simulator test for the panel both required? [Consistency, plan Testing]

## Future D1/D2/D3 evidence

- [x] CHK009 Is it stated that the feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
