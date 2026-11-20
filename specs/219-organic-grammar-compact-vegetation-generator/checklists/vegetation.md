# Requirements Quality Checklist: R02-F19 vegetation

**Purpose**: Unit tests for the requirements of feature 219 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the promise (organic variety, identical on reopening) stated as measurable repetition and seed
  sensitivity? [Measurability, Spec §SC-R02F19-001, 004] — corrected: the seed-sensitivity count now applies only to
  grammars with weighted rules, since a grammar without chance cannot differ by seed.

## Deterministic invariants

- [x] CHK002 Is the draw order of chance defined (one stream, reading order, one draw per weighted symbol)? [Clarity,
  Spec §Clarifications Q2]
- [x] CHK003 Are the turtle's symbols, start frame and re-orthonormalisation defined? [Clarity, Spec §Clarifications Q1,
  Q2]
- [x] CHK004 Is the scatter's candidate order and per-instance draw order defined? [Clarity, Spec §Clarifications Q4]

## Empty and error states

- [x] CHK005 Are missing rules, unbalanced brackets, bad weights, zero generations, tiny or empty areas and out-of-range
  parameters each given an outcome and code? [Coverage, Spec §Edge Cases; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK006 Are the published methods named and every shape built from formulas, with no image? [Consistency,
  research R1–R5; Spec §Negative Requirements]

## iPad/iPhone layout

- [x] CHK007 Is it stated that garden editing, colours, layout and accessibility belong to the consuming experiences?
  [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK008 Is the regression on the simulators required although nothing new renders? [Consistency, plan Testing;
  Spec §SC-R02F19-006]

## Future D1/D2/D3 evidence

- [x] CHK009 Is the device-only item (frame cost of a dense instanced garden) named and deferred to after
  ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
