# Requirements Quality Checklist: R02-G05-05 progression and player teaching

**Purpose**: Unit tests for the requirements of feature 345 (tutorial, hints, failure text, progress and stars, daily and
practice modes, schema migration, layout, evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Teaching

- [x] CHK001 Are the tutorial's steps, their texts and what advances each stated, and is dismissal defined? [Clarity,
  Spec §Clarifications Q2]
- [x] CHK002 Is the hint defined from the visible state only (heights, fluid, valves, tick, actions left), with all three
  levels' content and the search order that breaks ties? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the hint defined in every stage (playing, paused, failed, won) so a player is never left without an
  answer? [Edge Case, Spec §Clarifications Q1; Edge Cases] — corrected: playing and paused give the plan's hint, failed
  gives the undo-or-retry text, won gives none.
- [x] CHK004 Is each failure's text defined with the values it names, and are undo and retry offered consistently with the
  kernel's undo rules (every action, including the failing one, can be undone)? [Consistency, Spec §FR-R02G0505-003; Q5]

## Progress and modes

- [x] CHK005 Are unlock, star thresholds and the level selection refusal defined with numbers and codes? [Clarity, Spec
  §Clarifications Q3]
- [x] CHK006 Is the daily formula exact, with its date input and refusal, and is a locked daily level's play defined?
  [Edge Case, Spec §Clarifications Q4; Edge Cases]
- [x] CHK007 Are practice's budget, star and unlock rules stated, and does the tutorial apply in every mode? [Coverage,
  Spec §Clarifications Q4; Edge Cases]

## Versioning, layout and evidence

- [x] CHK008 Is the snapshot schema 2 content and its migration from 1 defined, including what is digested? [Completeness,
  Spec §Clarifications Q5]
- [x] CHK009 Are the hint, failure and progress criteria measurable over stated samples that fit the 10-second test rule?
  [Measurability, Spec §SC-R02G0505-001 … 004] — corrected: 200 seeded states (research R3).
- [x] CHK010 Is it stated that no level needs payment, ads, accounts or network, and that all content is original and
  code-only (no new art or shader)? [Scope, Spec §FR-R02G0505-006; Negative Requirements] — corrected: originality and
  no new visuals stated.
- [x] CHK011 Is where the tutorial, hint and failure text appear defined for iPhone and iPad (in the panel, wrapping,
  never covering the canyon)? [Gap, Spec §Assumptions] — corrected.
- [x] CHK012 Is the evidence split stated: host and simulator here, nothing on devices (no device-only item)? [Coverage,
  Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
