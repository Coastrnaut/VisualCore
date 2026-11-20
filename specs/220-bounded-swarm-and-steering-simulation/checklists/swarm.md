# Requirements Quality Checklist: R02-F20 swarm

**Purpose**: Unit tests for the requirements of feature 220 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the promise (thousands of particles schooling, swirling and glowing the same way on every replay) stated
  as measurable equivalence, repetition and bounds? [Measurability, Spec §SC-R02F20-001…004]

## Deterministic invariants

- [x] CHK002 Is grid equivalence defined as equality with the existing search, order included? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK003 Is the integration order (forces from the start-of-step state, field rotation, speed cap, edges) defined?
  [Clarity, Spec §Clarifications Q3]
- [x] CHK004 Are the field and pole formulas and the pole bound stated exactly? [Clarity, Spec §Clarifications Q4]
- [x] CHK005 Is the grid's lack of bounds consistent across the story and the clarification? [Consistency, Spec §US1,
  Clarifications Q2] — corrected: User Story 1 no longer speaks of grid bounds.

## Empty and error states

- [x] CHK006 Are empty swarms, stacked agents, agents on a pole, non-finite agents and oversize requests each given an
  outcome and code? [Coverage, Spec §Edge Cases; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK007 Are the methods named as textbook ones, with density drawn through existing passes and no image?
  [Consistency, research R1–R6; Spec §FR-R02F20-004]

## iPad/iPhone layout

- [x] CHK008 Is it stated that controls, colours, layout and accessibility belong to the consuming experiences?
  [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK009 Is the regression on the simulators required, Digital Aquarium included? [Consistency, plan Testing; Spec
  §SC-R02F20-006]

## Future D1/D2/D3 evidence

- [x] CHK010 Is the device-only item (frame cost of a large swarm) named and deferred to after ImplementationLock-100?
  [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
