# Requirements Quality Checklist: R02-G03-01 playable rule kernel

**Purpose**: Unit tests for the requirements of feature 321 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-20
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-20; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the player's goal (match the target crossings and writhe) and what stops a move stated plainly?
  [Clarity, Spec §US1; Clarifications Q2, Q3]

## Deterministic invariants

- [x] CHK002 Is every rule decided in exact integers with stated bounds (coordinates, points, allowance)? [Clarity,
  Spec §Clarifications Q1, Q4]
- [x] CHK003 Is the legality of a move defined so the strands adjacent to the moving ones are not refused for touching
  at their shared vertex? [Consistency, Spec §Clarifications Q2] — corrected: contact only at a shared vertex is allowed.
- [x] CHK004 Are degenerate projections defined and their effect on winning fixed? [Edge Case, Spec §Clarifications Q3]
- [x] CHK005 Are fingerprints, records and replay defined so a trace reproduces every state? [Completeness, Spec
  §FR-R02G0301-005; Clarifications Q5]

## Empty and error states

- [x] CHK006 Are refusals named for out-of-bounds, coinciding points, crossings outside gates, tension, stage, staleness
  and allowance? [Coverage, Spec §Edge Cases; Clarifications Q2, Q4, Q5]

## Source licence and code-only graphics

- [x] CHK007 Is it stated that the design is the project's own and nothing is drawn in this feature? [Consistency, Spec
  §Assumptions; Excluded scope]

## iPad/iPhone layout

- [x] CHK008 Is it stated that layout belongs to later features? [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK009 Are host-test sizes and the brute-force cross-check stated? [Measurability, Spec §SC-R02G0301-001 … 003]

## Future D1/D2/D3 evidence

- [x] CHK010 Is it stated that this feature has no device-only item? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
