# Requirements Quality Checklist: R02-F24 content catalogs

**Purpose**: Unit tests for the requirements of feature 224 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is "a gentle first level" defined measurably? [Clarity, Spec §Canonical overrides] — corrected: the first
  level is the easiest of the first stage (stages are ordered by difficulty).
- [x] CHK002 Are "steadily rising" difficulty and "no big jump" quantified? [Measurability, Spec §Clarifications Q2]
- [x] CHK003 Is "teaches one idea at a time" expressed as per-step completion conditions? [Clarity, Spec
  §Clarifications Q4]

## Deterministic invariants

- [x] CHK004 Is the seed per level candidate defined, and the digest's exact bytes? [Clarity, Spec §Clarifications Q1]
- [x] CHK005 Is the order within a stage defined without open ties? [Clarity, Spec §Clarifications Q1]
- [x] CHK006 Is the checker's issue order fixed? [Clarity, Spec §Clarifications Q3]

## Empty and error states

- [x] CHK007 Are an unfillable plan, an empty plan, duplicates, unmatched or late tutorial events and damaged, newer
  and edited forms each given an outcome, and is every refusal named? [Coverage, Spec §Edge Cases; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK008 Is all content produced from seeds and rules, with no authored art and only original code? [Consistency,
  plan Constitution Check X]

## iPad/iPhone layout and accessibility

- [x] CHK009 Is tutorial text a key localised by the experience, with layout and VoiceOver presentation assigned to it on
  both device families? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK010 Is the regression on the simulators required? [Consistency, plan Testing; Spec §SC-R02F24-005]

## Future D1/D2/D3 evidence

- [x] CHK011 Is the device-only item (tutorial use with VoiceOver) named and deferred, and is it stated why catalog
  building needs no device run? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
