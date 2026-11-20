# Requirements Quality Checklist: R02-F13 shadows and silhouettes

**Purpose**: Unit tests for the requirements of feature 213 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated that the match score is computed on the CPU and equals what is drawn? [Clarity, Spec
  §FR-R02F13-005, SC-R02F13-003]
- [x] CHK002 Is the score defined at its boundaries (both empty, mismatched masks)? [Edge Case, Spec §Clarifications Q4]

## Deterministic invariants

- [x] CHK003 Is the plane basis fixed so the same scene gives the same 2D coordinates everywhere? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK004 Is the rasterisation rule exact (cell centres, half-open edges) so shared edges never double count?
  [Clarity, Spec §Clarifications Q3]
- [x] CHK005 Is replay identity (masks, digests, scores) a measurable criterion? [Measurability, Spec §SC-R02F13-004]

## Empty and error states

- [x] CHK006 Are a light on, below or parallel to the plane, geometry beyond the light and edge-on faces given outcomes?
  [Coverage, Spec §Edge Cases, Clarifications Q2]
- [x] CHK007 Is the outcome defined when the GPU target cannot be made, and is it stated that no decision depends on it?
  [Gap → Spec §Edge Cases] — corrected.
- [x] CHK008 Is behaviour after a context rebuild stated? [Gap → Spec §Edge Cases] — corrected.

## Source licence and code-only graphics

- [x] CHK009 Are the projection and hull sources cited? [Completeness, research R1, R3]
- [x] CHK010 Is the drawing required to use the existing renderer with no stencil buffer or new context? [Consistency,
  Spec §Negative Requirements, Clarifications Q5]

## iPad/iPhone layout

- [x] CHK011 Is it stated that layout and the spoken score belong to the consuming experiences? [Completeness, Spec
  §Assumptions]

## Simulator proof

- [x] CHK012 Are the GPU parity rule (uniform 3 × 3 neighbourhoods), single darkening, both runtimes and zero leaks
  named? [Measurability, Spec §SC-R02F13-003]

## Future D1/D2/D3 evidence

- [x] CHK013 Is the device-only item (shadow drawing cost) named and deferred to after ImplementationLock-100?
  [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
