# Requirements Quality Checklist: R02-G08-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 373 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-22
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-22; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a player sees (opened bevelled pieces, ice-glass original faces, amber cut faces with a
  lattice, ruby preview plane, cut mark) and how each drawn element maps to a kernel value (piece, face plane, chosen
  direction and depth, cuts and budget)? [Clarity, Spec §US1; Clarifications Q1]

## Deterministic invariants

- [x] CHK002 Is renderer purity stated (snapshot only; tier, time and failures never change state, digest or verdict)?
  [Completeness, Spec §FR-R02G0803-003; SC-R02G0803-002]
- [x] CHK003 Is every placement (world mapping by centroid and R, bevel inset, opening distance and easing, mark row,
  ground height, camera pitch and fit) given in numbers? [Clarity, Spec §Clarifications Q1]
- [x] CHK004 Does the camera bound include the opened pieces (won opening 0.2) and the cut mark, not only the crystal?
  [Consistency, Spec §Clarifications Q1; Edge Cases]
- [x] CHK005 Are tiers limited to bevel segments, dispersion layers and glow, with positions identical at every tier?
  [Consistency, Spec §FR-R02G0803-004; Clarifications Q2]
- [x] CHK006 Is the cut-face rule exact (a face whose plane is not one of the crystal's half-spaces) rather than a
  floating-point test? [Clarity, Spec §Clarifications Q1; research R3]

## Empty and error states

- [x] CHK007 Are shader failure, zero size, resize, memory warning, Reduce Motion and Reduce Flashing defined?
  [Coverage, Spec §Edge Cases; Clarifications Q4]
- [x] CHK008 Are adapter refusals defined for out-of-range and out-of-stage actions, and restore refusals? [Coverage,
  Spec §Clarifications Q5]
- [x] CHK009 Is a sliver failure shown distinctly (marked piece, piece and cut named)? [Edge Case, Spec §Edge Cases;
  Clarifications Q4]
- [x] CHK010 Is the preview plane defined when the chosen plane misses the chosen piece? [Edge Case, Spec
  §Clarifications Q1 — drawn only when it crosses]
- [x] CHK011 Is the opening of a piece centred on the crystal's centre (the uncut crystal) defined? [Gap, Spec §Edge
  Cases — added 2026-11-22: not moved; the uncut crystal is drawn whole]

## Accessibility (colour independence)

- [x] CHK012 Do cut faces, original faces, the preview plane, a sliver piece and the cut mark each have a non-colour
  cue? [Coverage, Spec §Edge Cases; research R4]

## Source licence and code-only graphics

- [x] CHK013 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G0803-001; Assumptions]
- [x] CHK014 Is the triangle budget of the largest play (20 pieces of up to 34 faces at level-0) bounded so code-only
  geometry is feasible? [Measurability, Plan §Performance]

## iPad/iPhone layout

- [x] CHK015 Are aspect ratios 0.4 … 2.5 covered by the camera fit? [Coverage, Spec §Edge Cases]

## Simulator proof

- [x] CHK016 Are frame-check positions, colours and tolerances stated numerically? [Measurability, Spec
  §Clarifications Q3; SC-R02G0803-001]

## Future D1/D2/D3 evidence

- [x] CHK017 Is the device-only frame-time measurement tagged and deferred to after ImplementationLock-100?
  [Completeness, Spec §SC-R02G0803-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
- CHK011 failed at first reading; the spec's Edge Cases were corrected before the items were judged.
