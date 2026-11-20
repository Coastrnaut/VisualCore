# Requirements Quality Checklist: R02-G02-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 313 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the hero scene described concretely (path, head, trail, checkpoints, obstacles, palette) so a reviewer
  can tell what a player sees? [Completeness, Spec §US1; Clarifications Q1]
- [x] CHK002 Are the checkpoint states (unvisited, visited in order, next) and the obstacle contact state defined?
  [Clarity, Spec §FR-R02G0203-002; Clarifications Q1]

## Deterministic invariants

- [x] CHK003 Is it required that no tier, time, frame or failure can change the digest or verdict, with a measurable
  check? [Measurability, Spec §FR-R02G0203-003; §SC-R02G0203-002]
- [x] CHK004 Are the tiers' differences quantified and coordinates fixed across tiers? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK005 Is the digest's content stated so undo restores the earlier digest? [Consistency, Spec §Clarifications Q5]

## Empty and error states

- [x] CHK006 Are shader failure, zero-size views, aspect ratios 0.4 … 2.5, extreme dials, memory warnings, Reduce Motion
  and Reduce Flashing each given an outcome? [Coverage, Spec §Edge Cases; Clarifications Q4]

## Source licence and code-only graphics

- [x] CHK007 Is it stated that all geometry and shading are original code with no image assets? [Consistency, Spec
  §FR-R02G0203-001; Assumptions]

## iPad/iPhone layout

- [x] CHK008 Is the camera's fit defined for every supported aspect ratio with a margin? [Clarity, Spec §Edge Cases;
  Clarifications Q1]

## Simulator proof

- [x] CHK009 Are the frame-check bounds (pixel distance, luminance, colour tolerances, frame size) numeric? [Measurability,
  Spec §Clarifications Q3; §SC-R02G0203-001]
- [x] CHK010 Is the registration (content facts, manifest, availability) specified so the shared checks can pass?
  [Completeness, Spec §FR-R02G0203-008; Clarifications Q5]

## Future D1/D2/D3 evidence

- [x] CHK011 Are device frame-time measurements tagged {device} and deferred to ImplementationLock-100? [Completeness,
  Spec §SC-R02G0203-006]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
