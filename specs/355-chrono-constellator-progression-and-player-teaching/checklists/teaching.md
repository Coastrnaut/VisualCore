# Requirements Quality Checklist: R02-G06-05 progression and player teaching

**Purpose**: Unit tests for the requirements of feature 355 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the tutorial's three instructions, their wording and their advance conditions stated? [Clarity, Spec
  §Clarifications Q2; FR-R02G0605-001]
- [x] CHK002 Is each hint level's text stated for every plan kind (run, rewind, hold removal, phase change, stuck)?
  [Completeness, Spec §Clarifications Q1]

## Deterministic invariants

- [x] CHK003 Is the hint plan defined from the current state alone, with its order of preference and the budget check?
  [Clarity, Spec §FR-R02G0605-002; Clarifications Q1]
- [x] CHK004 Are the star thresholds, the unlock rule and the daily formula stated numerically, and is the date the only
  clock input? [Measurability, Spec §Clarifications Q3, Q4; FR-R02G0605-005]
- [x] CHK005 Is it stated which state enters the digest (progress, mode) and which does not (tutorial step, hint level)?
  [Clarity, Spec §Clarifications Q5]

## Empty and error states

- [x] CHK006 Are a won play, a failed play, a replay in progress and an unreachable win covered for hints? [Coverage,
  Spec §Edge Cases; Clarifications Q1]
- [x] CHK007 Are locked levels, impossible dates and older saved states covered with named outcomes? [Coverage, Spec
  §Edge Cases; Clarifications Q3–Q5]
- [x] CHK008 Is the failure text defined for both failure kinds with the exact fields named? [Completeness, Spec
  §FR-R02G0605-003; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK009 Are all text and rules original, with no new art, model or shader? [Consistency, Spec §Negative
  Requirements]

## iPad/iPhone layout

- [x] CHK010 Is the placement of tutorial, hint and failure text stated for iPhone and iPad (panel, never over the sky)?
  [Coverage, Spec §Assumptions]

## Simulator proof

- [x] CHK011 Are host sample sizes (100 levels, 200 states, 500 failures, the 2026 … 2036 dates) and a simulator check of
  the panel required? [Measurability, Spec §SC-R02G0605-001 … 004; Plan quickstart]

## Future D1/D2/D3 evidence

- [x] CHK012 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
