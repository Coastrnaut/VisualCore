# Requirements Quality Checklist: R02-F17 heightfield transport

**Purpose**: Unit tests for the requirements of feature 217 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the promise (no water or colour from nothing, none vanishing, nothing exploding) stated as exact ledgers
  and bounds? [Measurability, Spec §SC-R02F17-001, 003]

## Deterministic invariants

- [x] CHK002 Is the representation that makes conservation exact defined (integer quanta, whole-quantum transfers)?
  [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the transfer order defined so results do not depend on cell visiting order? [Clarity, research R3]
- [x] CHK004 Are the settle and erosion outcomes measurable with stated sizes and step counts? [Measurability, Spec
  §SC-R02F17-002, 004] — corrected: SC-R02F17-003 and 004 now state their cases, sizes and step counts.

## Empty and error states

- [x] CHK005 Are a dry cell, over-asked outflow, zero, negative and non-finite times, the sub-step limit, the floor and
  bad grid sizes each given an outcome? [Coverage, Spec §Edge Cases; Clarifications Q3, Q5]

## Source licence and code-only graphics

- [x] CHK006 Are the published models named and re-implemented, with no assets, and drawing through existing passes?
  [Consistency, research R2, R6, R7; Spec §FR-R02F17-008]

## iPad/iPhone layout

- [x] CHK007 Is it stated that brushes, colours, layout and accessibility belong to the consuming experiences?
  [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK008 Is the regression on the simulators required although nothing renders? [Consistency, plan Testing; Spec
  §SC-R02F17-006]

## Future D1/D2/D3 evidence

- [x] CHK009 Is it stated that no device item exists in this slice and frame cost is measured by the consumers after
  ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
