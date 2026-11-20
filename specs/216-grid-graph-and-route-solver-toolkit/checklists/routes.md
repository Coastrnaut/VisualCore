# Requirements Quality Checklist: R02-F16 route solvers and certificates

**Purpose**: Unit tests for the requirements of feature 216 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player-visible promise (puzzles always solvable or honestly impossible, hints along real routes) tied
  to measurable outcomes? [Measurability, Spec §SC-R02F16-001…005]

## Deterministic invariants

- [x] CHK002 Are tie rules stated for both searches so routes are unique? [Clarity, Spec §Clarifications Q2]
- [x] CHK003 Are costs integer with stated bounds so results agree on every device? [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Is placement order defined? [Clarity, Spec §Clarifications Q4]

## Empty and error states

- [x] CHK005 Do empty graphs, limits, bad nodes, negative costs, blocked endpoints, schedules, patterns, budgets, rejected
  certificates, newer and damaged forms each have a reason code? [Coverage, Spec §Clarifications Q5]
- [x] CHK006 Is a budget running out distinguished from "unreachable"? [Edge Case, Spec §Edge Cases]
- [x] CHK007 Is it consistent which answers are independently checkable? [Consistency, Spec §FR-R02F16-006] — corrected:
  FR-R02F16-006 now names the two claims proved by tests (earliest-ness, exhaustive no-placement).

## Source licence and code-only graphics

- [x] CHK008 Are the algorithms named as textbook methods, with no assets or GPU work? [Consistency, research R3–R8;
  Spec §Negative Requirements]

## iPad/iPhone layout

- [x] CHK009 Is it stated that hint display, layout and accessibility belong to the consuming experiences?
  [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK010 Is the regression on the simulators required although nothing renders? [Consistency, plan Testing; Spec
  §SC-R02F16-006]

## Future D1/D2/D3 evidence

- [x] CHK011 Is it stated that no device item exists in this slice and solve times are measured by the consumers after
  ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
