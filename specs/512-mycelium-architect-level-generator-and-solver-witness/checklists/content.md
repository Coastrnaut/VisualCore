# Requirements Quality Checklist: R02-G22-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 512 (sites, generator, solver, minimality proof, difficulty,
witness, digest, progression, test split)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 502's checklist; every item
but CHK006 and CHK007 passed at first reading; both were fixed in the spec the same day.

## Sites extension

- [x] CHK001 Are the site count, emptiness rule, order, refusals and their position in the refusal order stated?
  [Completeness, Spec §Clarifications Q1]
- [x] CHK002 Is it stated that a level without sites keeps feature 511's stored form and fingerprint? [Consistency,
  Spec §FR-R02G2202-009]
- [x] CHK003 Is the play's and the puzzle's treatment of off-site placements defined? [Clarity, Spec §Clarifications Q1]

## Generator

- [x] CHK004 Is the candidate draw order fixed and every drawn value's range given by band? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK005 Are the skip reasons and the candidate bound with its refusal defined? [Completeness, Spec §Clarifications
  Q2; Edge Cases]
- [x] CHK006 Is the starting-seed count range well formed when the plan uses every seed? [Clarity, Spec §Clarifications
  Q2] (fixed 2026-11-27)
- [x] CHK007 Can a terminal never coincide with a site, so the level's shared-cell rules hold? [Consistency, Spec
  §Clarifications Q1–Q2] (fixed 2026-11-27)
- [x] CHK008 Is "genuinely different from adjacent seeds" made measurable (fingerprint and board)? [Measurability, Spec
  §FR-R02G2202-007]

## Solver and proof

- [x] CHK009 Are the search order, loss, reachability rule, depth bound and work bound defined? [Clarity, Spec
  §Clarifications Q3]
- [x] CHK010 Is the minimality proof defined as the per-depth counts with none winning, and its independent check
  described? [Measurability, Spec §SC-R02G2202-002; Clarifications Q5]
- [x] CHK011 Is it stated that every plan is replayed through the play? [Completeness, Spec §FR-R02G2202-002]

## Difficulty, witness and catalog

- [x] CHK012 Are the difficulty fields and the progression rule stated? [Completeness, Spec §Clarifications Q4]
- [x] CHK013 Is the witness layout (fields, digests, report, counterexample) and its refusals defined? [Completeness,
  Spec §Clarifications Q5]
- [x] CHK014 Is the truth metric mapped to witness fields? [Traceability, Spec §FR-R02G2202-004]
- [x] CHK015 Is the catalog digest's input and pinning stated? [Clarity, Spec §Clarifications Q5]

## Tests and scope

- [x] CHK016 Is the certification split and its time budget stated without a CI wall-clock assertion? [Measurability,
  Spec §Clarifications Q5]
- [x] CHK017 Are INV-06 and INV-12 given named tests? [Traceability, Spec §FR-R02G2202-008]
- [x] CHK018 Are the manifest's required concepts and excluded phrases mapped to rules? [Coverage, Spec §Assumptions]
- [x] CHK019 Are excluded items listed and is the absence of device items stated? [Completeness, Spec §Excluded scope]

## Notes

- `/speckit-implement` reads these markers and does not change them.
