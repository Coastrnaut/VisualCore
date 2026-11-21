# Requirements Quality Checklist: R02-G04-02 level generator and solver witness

**Purpose**: Unit tests for the requirements of feature 332 (player impact, construction from seeds, solver depth and work
bound, band profiles and difficulty, witness contents and counterexamples, digest and progression, refusals, test time,
device evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is "deducible" defined from the player's knowledge (public facts, not the target) so a level is never won
  by luck? [Clarity, Spec §US1; Assumptions; Clarifications Q2]

## Construction

- [x] CHK002 Is the seed derivation of each candidate stated exactly (manifest seed, candidate index, draw order)?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Are tolerances, clear-fog share and smallest-probe range defined per band? [Completeness, Spec
  §Clarifications Q1]
- [x] CHK004 Is the allowance's relation to the probes and selection stated? [Consistency, Spec §Clarifications Q1] —
  corrected: budgets 8 … 19 always exceed at most 2 probes plus the selection.
- [x] CHK005 Is the candidate limit and the refusal when it is exhausted named? [Edge Case, Spec §Edge Cases; Q1]

## Solver

- [x] CHK006 Are the candidate set, the settling condition and the depth and work bounds given exactly, the bounds as
  numbers derived by arithmetic? [Measurability, Spec §Clarifications Q2]
- [x] CHK007 Are the tie rules for the probe set and the selection stated? [Clarity, Spec §Clarifications Q2]
- [x] CHK008 Is the solver's result checked against an independent method on stated samples? [Measurability, Spec
  §SC-R02G0402-002]

## Difficulty and catalog

- [x] CHK009 Are the difficulty fields and the progression rule (numbers) stated? [Completeness, Spec §Clarifications Q3]
- [x] CHK010 Is the catalog digest's identity and pinning defined? [Clarity, Spec §Clarifications Q5]

## Witness

- [x] CHK011 Are every witness field and both counterexamples defined, including how each is chosen for one- and
  two-probe levels? [Completeness, Spec §Clarifications Q4; Edge Cases]
- [x] CHK012 Is the regeneration opt-in and the byte comparison defined? [Clarity, Spec §Clarifications Q4]
- [x] CHK013 Are damaged, newer and edited witness refusals named? [Edge Case, Spec §FR-R02G0402-004; SC-005]

## Licence, graphics, layout

- [x] CHK014 Is the manifest's provenance (the project's own archived design) and the absence of drawing stated?
  [Consistency, Spec §Assumptions; Excluded scope]

## Non-functional and evidence

- [x] CHK015 Is the per-test time bound stated with how it is measured (locally, not asserted on CI)? [Measurability,
  Spec §SC-R02G0402-006; Q5]
- [x] CHK016 Are device-only and owner-only items stated as none? [Scope, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
