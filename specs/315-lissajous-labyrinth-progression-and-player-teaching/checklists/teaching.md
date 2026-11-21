# Requirements Quality Checklist: R02-G02-05 progression and player teaching

**Purpose**: Unit tests for the requirements of feature 315 (hint correctness and progression, tutorial steps, failure
explanations, stars and unlocking, daily and practice modes, snapshot versioning and migration, panel text accessibility,
determinism and a clock-free core, no monetisation pressure)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts
(noted per item).

## Hints

- [x] CHK001 Is the source of a hint (shortest remaining solution from the current dials) and each level's content
  stated? [Clarity, Spec §Clarifications Q1; FR-R02G0205-002]
- [x] CHK002 Is the hint's behaviour when no solution fits the actions left, and when play has ended, specified?
  [Edge Case, Spec §Edge Cases; Clarifications Q1]
- [x] CHK003 Is it stated that hints are unlimited, change nothing and do not affect stars, and when the revealed level
  resets? [Completeness, Spec §FR-R02G0205-002]
- [x] CHK004 Is the hint's correctness measurable over all levels and many states? [Measurability, Spec §SC-R02G0205-002]

## Tutorial

- [x] CHK005 Are the instruction texts, their order and their advance triggers stated? [Clarity, Spec §Clarifications Q2]
- [x] CHK006 Is it stated where and when the tutorial appears (levels, mode, per opening)? [Coverage, Spec §Edge Cases]
  (added during this review)
- [x] CHK007 Is the tutorial's relation to undo stated? [Consistency, Spec §Clarifications Q2, Q5]

## Failure explanations

- [x] CHK008 Are both verdict kinds given an exact text, with the numbering and lap-position formula? [Clarity, Spec
  §Clarifications Q5; FR-R02G0205-003]
- [x] CHK009 Is the follow-up offered (undo, retry) specified? [Completeness, Spec §Clarifications Q5]

## Stars, unlocking and modes

- [x] CHK010 Are the star thresholds and the replacement rule for a better result stated numerically? [Clarity, Spec
  §Clarifications Q3]
- [x] CHK011 Are the unlocking rule, the select refusal and `level.next` with no next open level specified? [Coverage,
  Spec §Clarifications Q3]
- [x] CHK012 Is the daily formula stated for every date, including dates before 2026 and impossible dates? [Edge Case,
  Spec §Clarifications Q4]
- [x] CHK013 Is it stated whether daily wins record results and open levels? [Consistency, Spec §Edge Cases] (added
  during this review)
- [x] CHK014 Are practice rules and the return to campaign specified? [Completeness, Spec §Edge Cases] (added during this
  review)

## Versioning and determinism

- [x] CHK015 Are the snapshot schema 2 fields, digest membership and the schema-1 migration specified? [Completeness,
  Spec §Clarifications Q5; FR-R02G0205-007]
- [x] CHK016 Is the behaviour for a damaged or newer payload stated? [Exception Flow, Spec §Edge Cases] (added during
  this review)
- [x] CHK017 Is the core declared clock-free with the date entering as an action? [Consistency, Spec §Clarifications Q4]

## Accessibility, scope and money

- [x] CHK018 Is every new text required to be plain panel text read by VoiceOver, with polish deferred to R02-G02-06?
  [Coverage, Spec §Assumptions]
- [x] CHK019 Is it stated that every level is free, with no purchase prompt, advertising, account, network, streak
  pressure or timed challenge? [Completeness, Spec §FR-R02G0205-006; Negative Requirements]
- [x] CHK020 Are test duration limits and the regression stated? [Non-Functional, Spec §SC-R02G0205-005]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
