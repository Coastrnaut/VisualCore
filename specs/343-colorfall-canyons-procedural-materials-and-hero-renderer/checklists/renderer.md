# Requirements Quality Checklist: R02-G05-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 343 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.

## Player impact

- [x] CHK001 Is it stated what a player sees (terrain, springs, basins, fluid and falls) and how each drawn element maps to
  a rule value? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; tier, time and failures never change state, digest or verdict)?
  [Completeness, Spec §FR-R02G0503-003; SC-R02G0503-002]
- [x] CHK003 Is every placement (cell size, heights, sheet thickness, emitter height, camera) given in numbers? [Clarity,
  Spec §Clarifications Q1]
- [x] CHK004 Does the camera bound include the tallest elements, not only the grid footprint? [Consistency, Spec
  §Clarifications Q1; Edge Cases] — corrected: the bounding sphere now reaches the farthest corner of the tallest element
  and the edge case states the 5 % margin.
- [x] CHK005 Are tiers limited to subdivision, flow bands and glow, with positions identical at every tier? [Consistency,
  Spec §FR-R02G0503-004; Clarifications Q2]

## Empty and error states

- [x] CHK006 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined? [Coverage,
  Spec §Edge Cases; Clarifications Q4]
- [x] CHK007 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]

## Accessibility (colour independence)

- [x] CHK008 Does every fluid colour have a non-colour pattern, also on the basin targets? [Coverage, Spec §Edge Cases;
  Clarifications Q1]

## Source licence and code-only graphics

- [x] CHK009 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G0503-001; Assumptions]

## iPad/iPhone layout

- [x] CHK010 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK011 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec §Clarifications
  Q3; SC-R02G0503-001]

## Future D1/D2/D3 evidence

- [x] CHK012 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100? [Completeness,
  Spec §SC-R02G0503-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
