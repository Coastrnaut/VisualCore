# Requirements Quality Checklist: R02-G07-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 363 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a player sees (shell wedges, openings, wall fins, blocked wedges, pearl, exit arrow) and
  how each drawn element maps to a rule value (shell, sector, offset, pocket)? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; tier, time and failures never change state, digest or verdict)?
  [Completeness, Spec §FR-R02G0703-003; SC-R02G0703-002]
- [x] CHK003 Is every placement (shell radii and width, wedge heights and inset, fin size, pearl radius and height, exit
  arrow radius, camera pitch and fit) given in numbers? [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Does the camera bound include the exit arrow outside the outer shell, not only the crystal? [Consistency,
  Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to bevel segments, highlight layers and glow, with positions identical at every tier?
  [Consistency, Spec §FR-R02G0703-004; Clarifications Q2]

## Empty and error states

- [x] CHK006 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined? [Coverage,
  Spec §Edge Cases; Clarifications Q4]
- [x] CHK007 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]
- [x] CHK008 Is a failure in a blocked wedge shown distinctly (tinted wedge, shell and sector named)? [Edge Case, Spec
  §Edge Cases; Clarifications Q4]
- [x] CHK009 Is the pearl's drawn position defined after a win, when it no longer occupies a pocket? [Gap, Spec §Edge
  Cases — added 2026-11-22: drawn on the exit arrow's centre]

## Accessibility (colour independence)

- [x] CHK010 Do openings, walls, blocked wedges, the exit and the pearl each have a non-colour shape cue? [Coverage, Spec
  §Edge Cases; research R3]

## Source licence and code-only graphics

- [x] CHK011 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G0703-001; Assumptions]
- [x] CHK012 Is the triangle budget of the largest level (5 × 12 wedges at level-0) bounded so code-only geometry is
  feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK013 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK014 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec §Clarifications
  Q3; SC-R02G0703-001]

## Future D1/D2/D3 evidence

- [x] CHK015 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G0703-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK009 failed at first reading; the spec's Edge Cases were corrected before the items were judged.
