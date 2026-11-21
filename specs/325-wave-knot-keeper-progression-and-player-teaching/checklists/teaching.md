# Requirements Quality Checklist: R02-G03-05 progression and player teaching

**Purpose**: Unit tests for the requirements of feature 325 (hints and search limit, tutorial steps, failure
explanations, progress and stars, daily and practice modes, schema migration, accessibility of texts)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Hints

- [x] CHK001 Are the three hint levels defined with their exact wording pattern? [Clarity, Spec §Clarifications Q1]
- [x] CHK002 Is the hint search depth stated, with the text shown when nothing is found within it or the moves left?
  [Edge Case, Spec §Clarifications Q1; Edge Cases]
- [x] CHK003 Is it stated that hints never change state or stars and reset after any change of the play? [Completeness,
  Spec §FR-R02G0305-002]
- [x] CHK004 Is the hint's correctness measurable (shortest remaining one shorter) over stated samples?
  [Measurability, Spec §SC-R02G0305-002]

## Tutorial and failures

- [x] CHK005 Are the tutorial steps, their order and their advance conditions defined, with dismissal? [Completeness,
  Spec §Clarifications Q2]
- [x] CHK006 Are the failure texts defined for both summary outcomes (signature mismatch, degenerate)? [Coverage, Spec
  §Clarifications Q5]

## Progress and modes

- [x] CHK007 Are star thresholds, unlocking and refusals (with codes) defined? [Clarity, Spec §Clarifications Q3]
- [x] CHK008 Is the daily formula exact, with the reason for its step and the date's source? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK009 Are practice rules (allowance, no stars, no unlocking) and the return to campaign defined? [Completeness,
  Spec §Clarifications Q4; Edge Cases]

## State and migration

- [x] CHK010 Is it stated which values are digested, snapshotted only, or presentation? [Consistency, Spec
  §Clarifications Q5]
- [x] CHK011 Is the schema-1 to schema-2 migration defined with its defaults, and damaged or newer payloads handled?
  [Edge Case, Spec §Clarifications Q5; Edge Cases]

## Accessibility and scope

- [x] CHK012 Are all teaching texts stated as plain panel text read by VoiceOver? [Accessibility, Spec §Assumptions]
- [x] CHK013 Is "premium content" stated as superseded (free, all levels)? [Scope, Spec §FR-R02G0305-006]

## Notes

- `/speckit-implement` reads these markers and does not change them.
