# Requirements Quality Checklist: R02-F23 puzzle contract

**Purpose**: Unit tests for the requirements of feature 223 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the promise (only solvable levels, the promised solution when uniqueness is claimed, neither trivial nor
  overlong, the same per seed) stated as measurable outcomes? [Measurability, Spec §SC-R02F23-001…004]

## Deterministic invariants

- [x] CHK002 Is the level identity defined over exact bytes, with what it excludes? [Clarity, Spec §Clarifications Q2]
- [x] CHK003 Is the order of validation checks fixed, with the first failure reported? [Clarity, Spec §Clarifications Q3]
- [x] CHK004 Are both uniqueness modes defined in terms that can be decided within a bound? [Clarity, Spec
  §Clarifications Q2, Q3]
- [x] CHK005 Is the generator's dependence on the seed alone stated, including the candidate maker? [Gap, Spec
  §Assumptions] — corrected: the maker draws only from the given generator and keeps no state.

## Empty and error states

- [x] CHK006 Are an already-solved start, illegal moves, an exhausted search, a failing generator, damaged, newer and
  edited records and oversize inputs each given an outcome, and is every refusal named? [Coverage, Spec §Edge Cases;
  Clarifications Q5]
- [x] CHK007 Is an exhausted search kept distinct from uniqueness for every promise? [Consistency, Spec §Clarifications
  Q3; Edge Cases]

## Source licence and code-only graphics

- [x] CHK008 Are the methods textbook and the test puzzles original or public-domain mechanics, with no graphics in this
  slice? [Consistency, research R1–R5; plan Constitution Check X]

## iPad/iPhone layout

- [x] CHK009 Is it stated that level presentation belongs to the consuming experiences on both device families?
  [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK010 Is the regression on the simulators required? [Consistency, plan Testing; Spec §SC-R02F23-005]

## Future D1/D2/D3 evidence

- [x] CHK011 Is the device-only item (generation time of a batch) named and deferred to after ImplementationLock-100?
  [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
