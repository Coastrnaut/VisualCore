# Requirements Quality Checklist: R02-G06-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 353 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a player sees (field, tracks, stars, targets, history ribbons, hold and collision marks)
  and how each drawn element maps to a rule value? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; tier, time and failures never change state, digest or verdict)?
  [Completeness, Spec §FR-R02G0603-003; SC-R02G0603-002]
- [x] CHK003 Is every placement (cell size, node height and radius, track width, ring radius, ribbon rise per tick, camera
  pitch and fit) given in numbers? [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Does the camera bound include the ribbons' full height, not only the grid footprint? [Consistency, Spec
  §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to ribbon length, segments and glow, with positions identical at every tier, and does the
  snapshot carry enough history for the richest tier (24 ticks)? [Consistency, Spec §FR-R02G0603-004; Clarifications Q2,
  Q4]

## Empty and error states

- [x] CHK006 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined? [Coverage,
  Spec §Edge Cases; Clarifications Q4]
- [x] CHK007 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]
- [x] CHK008 Is a collision shown distinctly (mark on the cell, both stars named)? [Edge Case, Spec §Edge Cases;
  Clarifications Q1]

## Accessibility (colour independence)

- [x] CHK009 Does every star have a non-colour shape, repeated on its target, with holds and collisions marked by shape?
  [Coverage, Spec §Edge Cases; Clarifications Q1]

## Source licence and code-only graphics

- [x] CHK010 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G0603-001; Assumptions]

## iPad/iPhone layout

- [x] CHK011 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK012 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec §Clarifications
  Q3; SC-R02G0603-001]

## Future D1/D2/D3 evidence

- [x] CHK013 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100? [Completeness,
  Spec §SC-R02G0603-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
