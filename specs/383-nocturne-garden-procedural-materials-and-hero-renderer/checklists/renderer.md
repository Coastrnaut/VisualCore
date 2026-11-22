# Requirements Quality Checklist: R02-G09-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 383 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a player sees (mist bed, black shadow cells, gold target rim, coral forbidden hatch,
  grown blooms, lantern, move gauge) and how each drawn element maps to a kernel value (mask, target and forbidden
  cells, blooms, sun, moves and budget)? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; the shadow drawn is the kernel's mask; tier, time and failures
  never change state, digest or verdict)? [Completeness, Spec §FR-R02G0903-003; SC-R02G0903-002]
- [x] CHK003 Is every placement (cell size u = 2 / W, row 0 at the bottom, bloom depth 0.35 and extrusion, lantern
  height by elevation, gauge row, ground height, camera pitch and fit) given in numbers? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK004 Does the camera bound include every bloom head a level can show, not only the bed? [Consistency, Spec
  §Clarifications Q1; Edge Cases] — corrected 2026-11-22: the fit now widens the bed by the largest head at any anchor
  (6·s·u above, s·u left, 2·s·u right) and stays fixed while a level is played.
- [x] CHK005 Are tiers limited to mist layers, stem depth, shadow feather and glow, with cells and positions identical
  at every tier? [Consistency, Spec §FR-R02G0903-004; Clarifications Q2]
- [x] CHK006 Is the shadow defined from the kernel's cells (not a GPU shadow), so frame checks can name exact cells?
  [Clarity, Spec §US2; research R2]

## Empty and error states

- [x] CHK007 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK008 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]
- [x] CHK009 Is a leak failure shown distinctly (crossed leaking cells, the action named)? [Edge Case, Spec §Edge
  Cases; Clarifications Q4]
- [x] CHK010 Is the empty bed (no bloom) defined? [Edge Case, Spec §Edge Cases]
- [x] CHK011 Are cells hidden behind a bloom excluded from the frame checks by a stated rule? [Measurability, Spec
  §Clarifications Q3 — cell centres inside any bloom's screen box are skipped]

## Accessibility (colour independence)

- [x] CHK012 Do the target, forbidden cells, leaks, shadow and gauge each have a non-colour cue? [Coverage, Spec §Edge
  Cases; research R4]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G0903-001; Assumptions]
- [x] CHK014 Is the triangle budget of the largest scene (768 cells, 12 blooms at level-0) bounded so code-only
  geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK015 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK016 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec
  §Clarifications Q3; SC-R02G0903-001]

## Future D1/D2/D3 evidence

- [x] CHK017 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G0903-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK004 failed at first reading; the spec's camera fit was corrected before the items were judged.
