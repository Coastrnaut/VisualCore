# Requirements Quality Checklist: R02-F18 terrain and sky

**Purpose**: Unit tests for the requirements of feature 218 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is the promise (no holes between pieces, no popping seams, a sky without pictures) stated as measurable
  edge equality, level rules and colour error? [Measurability, Spec §SC-R02F18-001, 002, 004]

## Deterministic invariants

- [x] CHK002 Are level choice, neighbour balancing and budget coarsening defined with tie rules? [Clarity, Spec
  §Clarifications Q1, Q2]
- [x] CHK003 Is crack-freedom defined exactly (even points bit-identical, odd points at the mean)? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK004 Are the mask formulas and the D8 visiting and tie order defined? [Clarity, Spec §Clarifications Q3]
- [x] CHK005 Is the sky formula given term by term, with stated default values? [Clarity, Spec §Clarifications Q4] —
  corrected: default colours and sun settings added to data-model.md.

## Empty and error states

- [x] CHK006 Are a far viewpoint, a too-small budget, a one-piece terrain, the sun below, at and above the horizon, flat
  and pit terrains, and out-of-range values given outcomes? [Coverage, Spec §Edge Cases; Clarifications Q5]

## Source licence and code-only graphics

- [x] CHK007 Are the methods named as textbook ones with no image anywhere, the sky drawn by code alone? [Consistency,
  research R1–R6; Spec §Negative Requirements]

## iPad/iPhone layout

- [x] CHK008 Is it stated that camera controls, layout and accessibility belong to the consuming experiences?
  [Completeness, Spec §Assumptions]

## Simulator proof

- [x] CHK009 Are the GPU proofs (sky against its reference, renderer state and leaks, the include compiled alone)
  required on both simulator runtimes? [Consistency, plan Testing; Spec §SC-R02F18-004, 005]

## Future D1/D2/D3 evidence

- [x] CHK010 Is the device-only item (frame cost of terrain and sky on D1–D3) named and deferred to after
  ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
