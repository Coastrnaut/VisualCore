# Requirements Quality Checklist: R02-G03-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 322 (construction from seeds, solver depth and work bound, band
ranges and difficulty, witness contents and counterexamples, digest and progression, refusals, test time)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Construction

- [x] CHK001 Is the seed derivation of each candidate stated exactly (manifest seed, candidate index, generator)?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK002 Are the solved rope's parameters per band (points, radius, height, swaps) and its acceptance conditions
  stated? [Completeness, Spec §Clarifications Q1]
- [x] CHK003 Are gates, scramble length, tension bound and allowance defined per band? [Completeness, Spec §Clarifications
  Q1; data-model]
- [x] CHK004 Is the candidate limit and the refusal when it is exhausted named? [Edge Case, Spec §Edge Cases; Q1]

## Solver

- [x] CHK005 Is the search's depth bound and its work bound given as numbers derived by arithmetic? [Measurability, Spec
  §Clarifications Q2]
- [x] CHK006 Is the tie rule that picks one shortest solution stated? [Clarity, Spec §Clarifications Q2]
- [x] CHK007 Is the solver's result checked against an independent method on stated samples? [Measurability, Spec
  §SC-R02G0302-002]

## Difficulty and catalog

- [x] CHK008 Are the band ranges of the shortest solution stated, and is the allowance relation to them defined?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK009 Are the difficulty fields and the progression rule (numbers) stated? [Completeness, Spec §Clarifications Q3]
- [x] CHK010 Is the catalog digest's identity and pinning defined? [Clarity, Spec §Clarifications Q5]

## Witness

- [x] CHK011 Are every witness field and both counterexamples defined, including how each is chosen? [Completeness, Spec
  §Clarifications Q4]
- [x] CHK012 Is the regeneration opt-in and the byte comparison defined? [Clarity, Spec §Clarifications Q4]
- [x] CHK013 Are damaged, newer and edited witness refusals named? [Edge Case, Spec §FR-R02G0302-004; SC-005]

## Non-functional

- [x] CHK014 Is the per-test time bound stated with how it is measured (locally, not asserted on CI)? [Measurability, Spec
  §SC-R02G0302-006; Q5]
- [x] CHK015 Are device-only and owner-only items stated as none? [Scope, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
