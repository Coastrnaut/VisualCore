# Requirements Quality Checklist: R02-F21 nutrient field

**Purpose**: Unit tests for the requirements of feature 221 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the promise (nutrients spread, fade and feed a creeping network the same way on every replay, never
  exploding or flickering) stated as exact balance, non-negativity, a non-rising peak and repeatable growth?
  [Measurability, Spec §SC-R02F21-001, 002, 005]

## Deterministic invariants

- [x] CHK002 Is the diffusion rule, with its stability bound and sub-step count, stated exactly? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK003 Is "spread grows" defined measurably? [Clarity, Spec §US1, SC-R02F21-002] — corrected: spread is the
  amount-weighted mean squared distance from the spot, on a stated grid and run.
- [x] CHK004 Are the order within a sub-step and the place of growth in a frame defined? [Clarity, Spec §Clarifications
  Q3, Q4]
- [x] CHK005 Are candidate ranking and parent choice of growth defined without ties left open? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK006 Is the settle criterion given with its grid, decay and run length? [Measurability, Spec §SC-R02F21-003]

## Empty and error states

- [x] CHK007 Are an all-zero field, long frames, full cells, over-asking sinks, growth with nowhere to go and oversize
  requests each given an outcome, and is every refusal named? [Coverage, Spec §Edge Cases; Clarifications Q5]
- [x] CHK008 Do the edge cases agree with the clarification on full cells? [Consistency, Spec §Edge Cases,
  Clarifications Q3] — corrected: a source at the limit is capped and reported, not refused.

## Source licence and code-only graphics

- [x] CHK009 Are the methods named as textbook ones, with fields drawn through existing passes and no image?
  [Consistency, research R1–R7; plan Constitution Check X]

## iPad/iPhone layout

- [x] CHK010 Is it stated that controls, colours, layout and accessibility belong to the consuming experiences?
  [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK011 Is the regression on the simulators required? [Consistency, plan Testing; Spec §SC-R02F21-007]

## Future D1/D2/D3 evidence

- [x] CHK012 Is the device-only item (frame cost of a large field with growth) named and deferred to after
  ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
