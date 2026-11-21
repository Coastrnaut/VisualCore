# Requirements Quality Checklist: R02-G04-05 progression and player teaching

**Purpose**: Unit tests for the requirements of feature 335 (tutorial, hints, failure text, progress and stars, daily and
practice modes, schema migration, accessibility)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Teaching

- [x] CHK001 Are the tutorial's steps, their texts and what advances each stated, and is dismissal defined? [Clarity,
  Spec §Clarifications Q2]
- [x] CHK002 Is the hint defined from what the player has seen (never the hidden target), with all three levels' content
  and tie rules? [Clarity, Spec §Clarifications Q1; Assumption]
- [x] CHK003 Is the hint's behaviour on the last unit defined so it never suggests a probe that fails the level? [Edge
  Case, Spec §Edge Cases; Q1]
- [x] CHK004 Is each failure's text defined with the values it names, and is retry (not undo) offered consistently with
  the kernel's undo rules? [Consistency, Spec §FR-R02G0405-003; Q5]

## Progress and modes

- [x] CHK005 Are unlock, star thresholds and the level selection refusal defined with numbers and codes? [Clarity, Spec
  §Clarifications Q3]
- [x] CHK006 Is the daily formula exact, with its date input and refusal, and is a locked daily level's play defined?
  [Edge Case, Spec §Clarifications Q4; Edge Cases] — corrected: a locked daily level is playable without opening it.
- [x] CHK007 Are practice's allowance, star and unlock rules stated, and does the tutorial apply in every mode? [Coverage,
  Spec §Clarifications Q4; Edge Cases] — corrected: the tutorial shows on levels 1 … 3 in every mode.

## Versioning and evidence

- [x] CHK008 Is the snapshot schema 2 content and its migration from 1 defined, including what is digested? [Completeness,
  Spec §Clarifications Q5]
- [x] CHK009 Are the hint, failure and progress criteria measurable over stated samples? [Measurability, Spec
  §SC-R02G0405-001 … 004]
- [x] CHK010 Is it stated that no level needs payment, ads, accounts or network? [Scope, Spec §FR-R02G0405-006]

## Notes

- `/speckit-implement` reads these markers and does not change them.
