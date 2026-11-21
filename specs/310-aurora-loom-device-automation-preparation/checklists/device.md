# Requirements Quality Checklist: R02-G01-10 device automation preparation

**Purpose**: Unit tests for the requirements of feature 310 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated which player-facing promises each device row will finally prove (sound, haptics, touch feel,
  progress, journeys, pacing, memory)? [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is the non-gating status of the manual VoiceOver row stated with its source? [Clarity, Spec §Q1; P-08]

## Deterministic invariants

- [x] CHK003 Is the device scenario set enumerated exactly, with why the other scenarios stay simulator-only?
  [Completeness, Spec §Clarifications Q2]
- [x] CHK004 Is the definition's shape defined field by field with its schema version? [Clarity, Spec §Q3; data-model]
- [x] CHK005 Is the coverage rule exact (which items must each be covered, from which sources)? [Measurability, Spec §Q4;
  research R2]

## Empty and error states

- [x] CHK006 Are the check's failures defined for a missing scenario, a missing field, an uncovered item and a missing or
  unreadable definition? [Edge Case, Spec §Edge Cases; SC-R02G0110-002] (definition errors added during this review)
- [x] CHK007 Is the handling of owner-needed device states defined without waiting for input? [Coverage, Spec §Edge
  Cases] (added during this review)

## Source licence and code-only graphics

- [x] CHK008 Is it stated that the feature adds no asset, no code to the app and no device identifier? [Consistency,
  Plan §Constitution]

## iPad/iPhone layout

- [x] CHK009 Do the rows cover both the iPhone (D1) and the two iPads (D2, D3) in the fixed order? [Coverage, Spec §Q1]
- [x] CHK010 Is D3's iPadOS 26.5 rule stated? [Clarity, Spec §Edge Cases]

## Simulator proof

- [x] CHK011 Is it stated what the check proves without any device (shape, manifest, ledger, coverage)? [Measurability,
  Spec §FR-R02G0110-004]

## Future D1/D2/D3 evidence

- [x] CHK012 Are pass conditions tied to the app's proposed budgets or stated as "recorded" or an observation, with 200
  samples where a percentage is used? [Clarity, Spec §Q5]
- [x] CHK013 Is it stated that no row may carry a result until the campaign runs? [Consistency, Spec §Q4; Edge Cases]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
