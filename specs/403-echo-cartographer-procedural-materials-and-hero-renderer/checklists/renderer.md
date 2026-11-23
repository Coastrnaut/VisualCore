# Requirements Quality Checklist: R02-G11-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 403 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-23
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-23; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a player sees (opal floor tiles, sonar-mint wireframe walls that flare in the expanding
  cyan pulse, the entry diamond, marker rings, rays, echo rings, beacon pillars, energy gauge) and how each drawn element
  maps to a kernel value (knowledge, entry, markers, the last echo report, located beacons, energy)? [Clarity, Spec §US1;
  Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; nothing hidden drawn; tier, time and failures never change state,
  digest or verdict)? [Completeness, Spec §FR-R02G1103-003; SC-R02G1103-002]
- [x] CHK003 Is every placement (cell centres, tile, diamond, ring, ray, block and edge sizes, pillar size, ground,
  gauge row and bars, camera box) given in numbers? [Clarity, Spec §Clarifications Q1] — corrected 2026-11-23: the
  gauge's x extent and bar width were added.
- [x] CHK004 Does the camera box include everything a level can show (the chamber within ±0.9, blocks to 0.5 and
  pillars to 0.8 high, the gauge at z = 1.0)? [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to rings, flare trails and glow, with cells and positions identical at every tier?
  [Consistency, Spec §FR-R02G1103-004; Clarifications Q2]
- [x] CHK006 Is it stated that unknown walls and unlocated beacons are never drawn, so the picture can never solve the
  puzzle? [Clarity, Spec §US2; research R2]
- [x] CHK007 Is the drawing order and depth use stated (opaque floor, blocks and pillars depth-tested; rings, rays and
  glow additive and last)? [Consistency, Spec §Clarifications Q1]

## Empty and error states

- [x] CHK008 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK009 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]
- [x] CHK010 Is an energy failure shown distinctly (the empty gauge, the action named)? [Edge Case, Spec §Edge Cases;
  Clarifications Q4]
- [x] CHK011 Are points near other elements excluded from the frame checks by a stated rule? [Measurability, Spec
  §Clarifications Q3]

## Accessibility (colour independence)

- [x] CHK012 Do walls, floor, entry, markers, beacons and the gauge each have a non-colour cue? [Coverage, Spec §Edge
  Cases; research R5]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G1103-001; Assumptions]
- [x] CHK014 Is the triangle budget of the largest scene (16 × 16 cells at level-0) bounded so code-only geometry is
  feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK015 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK016 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec
  §Clarifications Q3; SC-R02G1103-001]

## Future D1/D2/D3 evidence

- [x] CHK017 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G1103-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK003 failed at first reading; the spec was corrected before the item was judged.
