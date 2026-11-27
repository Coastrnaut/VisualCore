# Requirements Quality Checklist: R02-G22-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 511 (lattice, field, scoring, tie-breaks, branching, weights,
judge order, actions, stored form, words, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 501's checklist; every item
but CHK005, CHK008 and CHK012 passed at first reading; those three were fixed in the spec the same day.

## Player impact

- [x] CHK001 Are the player's goal (every terminal joined to the root within the weight limit) and the four failure
  reasons stated in words a player understands? [Clarity, Spec §User Stories 1–2]
- [x] CHK002 Is it stated that a failed run can be undone and the arrangement rearranged? [Completeness, Spec §US2/AC2]

## Lattice and field

- [x] CHK003 Are the board size, cell naming, direction numbering and distance defined exactly? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK004 Are the nutrient field's formula, its strength and reach ranges and its bound stated? [Completeness, Spec
  §Clarifications Q1; Plan §Numbers]
- [x] CHK005 Does FR-R02G2201-003 name the field rule rather than "a fixed distance rule"? [Clarity, Spec
  §FR-R02G2201-003] (fixed 2026-11-27)
- [x] CHK006 Is it defined which cells are obstacles (rocks, blockers, outside the board) and that toxins are not?
  [Clarity, Spec §Clarifications Q1–Q2]

## Scoring, tie-breaks and branching

- [x] CHK007 Are the score, the turn measure and the penalty ranges defined as whole numbers? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK008 Do FR-R02G2201-004 and the clarification agree on the tie-breaks and the branching rule (a new tip a
  quarter turn clockwise)? [Consistency, Spec §FR-R02G2201-004] (fixed 2026-11-27)
- [x] CHK009 Are admissibility (on the board, not obstacle, not grown, no corner cut) and dormancy defined? [Coverage,
  Spec §Clarifications Q2; Edge Cases]
- [x] CHK010 Is the order of tips within a pulse, including tips born during the pulse, defined? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK011 Is it defined whether a consumed nutrient still pulls and whether fixed nutrients branch like placed
  ones? [Edge Case, Spec §Clarifications Q2]

## Weights and judge order

- [x] CHK012 Does FR-R02G2201-006 state that the budget is checked before a step and toxin after it, so a step that
  is both fails `starved`? [Consistency, Spec §FR-R02G2201-006; Edge Cases] (fixed 2026-11-27)
- [x] CHK013 Are segment weights, budget and limit ranges and the 2048-node bound derived and stated? [Measurability,
  Spec §Clarifications Q3]
- [x] CHK014 Is the order after growth (lowest unreached terminal, then overweight) unambiguous? [Clarity, Spec
  §FR-R02G2201-006]
- [x] CHK015 Are budget and limit boundaries (exactly at, one above) specified? [Edge Case, Spec §Edge Cases;
  SC-R02G2201-004]

## Actions and play

- [x] CHK016 Are the five arrangement actions, their cells, counts and locks, and their refusal codes defined?
  [Completeness, Spec §Clarifications Q4]
- [x] CHK017 Is the validation order (.stage, .stale, .action, .budget) stated? [Clarity, Data model §Validation]
- [x] CHK018 Are the stages, undo from failed and the finality of a won level specified? [Coverage, Spec
  §Clarifications Q5; Data model §State transitions]

## Stored form and words

- [x] CHK019 Are the schema-1 fields, their order, the fingerprint and the decode refusal order defined? [Completeness,
  Spec §Clarifications Q5; Data model §Stored form]
- [x] CHK020 Are the words for cells, tips, terminals, steps and measures given with examples? [Clarity, Spec
  §FR-R02G2201-014; Clarifications Q5]
- [x] CHK021 Is the truth metric (connectivity, branch cost, forbidden-zone hits) mapped to report fields?
  [Traceability, Spec §FR-R02G2201-015]

## Scope and provenance

- [x] CHK022 Are excluded items (rendering, gestures, generator, certification, adapter, catalog, persistence) listed?
  [Completeness, Spec §Excluded scope]
- [x] CHK023 Is the design's provenance (the project's own archived design, original code, no third-party data)
  stated? [Assumption, Spec §Assumptions]

## Simulator proof

- [x] CHK024 Are host-test sizes, the independent recomputation and the boundary cases stated? [Measurability, Spec
  §SC-R02G2201-001 … 006; Plan]

## Future D1/D2/D3 evidence

- [x] CHK025 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads these markers and does not change them.
