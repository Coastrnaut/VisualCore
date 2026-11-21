# Requirements Quality Checklist: R02-G05-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 341 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Are the player's goal (each target basin filled with its colour mix, none contaminated or overflowing,
  within the tick limit) and the player's two levers (carving, valves) stated plainly? [Clarity, Spec §US1;
  Clarifications Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (grid, heights, release, supply, capacity,
  shares, tolerances, flow rate, budget, tick limit)? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the downhill neighbour defined uniquely, including ties and flat ground? [Edge Case, Spec
  §Clarifications Q2; Edge Cases]
- [x] CHK004 Is the order of a tick's sub-steps and the synchronous update fixed, so the result does not depend on cell
  order? [Clarity, Spec §FR-R02G0501-002; Clarifications Q2]
- [x] CHK005 Is the sharing of an outflow between colours defined so no unit is created or lost, and is conservation
  stated as an exact equality per colour? [Measurability, Spec §FR-R02G0501-003; SC-R02G0501-003]
- [x] CHK006 Is the precedence of contamination, overflow, win and time on one tick fixed, and is a win at tick 0
  excluded? [Consistency, Spec §FR-R02G0501-005; Clarifications Q3]
- [x] CHK007 Is it excluded that a level has no target to reach? [Consistency, Spec §Clarifications Q1] — corrected: at
  least one basin has a required fill above 0.
- [x] CHK008 Are fingerprints, records and replay defined so a trace reproduces every state, and is what undo covers
  (and that a won level is final) stated? [Completeness, Spec §FR-R02G0501-007; Clarifications Q4, Q5]

## Empty and error states

- [x] CHK009 Are refusals named for out-of-range actions, uncarvable cells, wrong stage, staleness and the budget, and
  failures named for contamination, overflow and time? [Coverage, Spec §Edge Cases; Clarifications Q3, Q5]
- [x] CHK010 Are a dry spring, a closed valve and a pool covered? [Edge Case, Spec §Edge Cases]

## Accessibility (colour independence)

- [x] CHK011 Is it required that every colour and every basin's mix is available in words and amounts? [Coverage, Spec
  §FR-R02G0501-013]

## Source licence and code-only graphics

- [x] CHK012 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK013 Is it stated that layout belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK014 Are host-test sizes, the brute-force cross-check and the boundary cases one unit either side of each limit
  stated? [Measurability, Spec §SC-R02G0501-001 … 004]

## Future D1/D2/D3 evidence

- [x] CHK015 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
