# Requirements Quality Checklist: R02-F12 convex solid clipping

**Purpose**: Unit tests for the requirements of feature 212 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it stated what a cut gives the player's game (kept part, removed part, cap, volumes) and that pieces are
  whole and clean? [Completeness, Spec §FR-R02F12-002, US1]
- [x] CHK002 Is the promise that removed amounts add up stated as a measurable balance? [Measurability, Spec
  §FR-R02F12-005, SC-R02F12-002]

## Deterministic invariants

- [x] CHK003 Are identical results across runs required, with the ordering rules that make them so? [Completeness, Spec
  §FR-R02F12-009; research R5]
- [x] CHK004 Is scale invariance stated as a number rather than "identical up to the scale"? [Clarity, Spec
  §SC-R02F12-004] — corrected: counts equal and vertices within 1e-12 relative after rescaling.
- [x] CHK005 Is the tolerance a stated formula tied to the solid's size? [Clarity, Spec §FR-R02F12-003]

## Empty and error states

- [x] CHK006 Are a missing cut, a cut taking everything, a sliver part and a vertex on the plane given outcomes? [Edge
  Case, Spec §Edge Cases, US1]
- [x] CHK007 Are every refusal and its reason code listed? [Completeness, Spec §Clarifications Q5]
- [x] CHK008 Is the behaviour at each limit (vertices, faces, corners, ledger entries) defined? [Gap → Spec §Edge Cases]
  — corrected: a ledger past 65,536 entries refuses the next cut and stays unchanged.

## Source licence and code-only graphics

- [x] CHK009 Are the algorithm sources cited? [Completeness, research R2, R3]
- [x] CHK010 Is it stated that there is no GPU code, so no shader or asset is involved? [Consistency, Spec §Negative
  Requirements]

## iPad/iPhone layout

- [x] CHK011 Is it stated that layout, Dynamic Type and VoiceOver belong to the consuming experiences? [Completeness,
  Spec §Assumptions]

## Simulator proof

- [x] CHK012 Is the regression on the simulators (rendering, experiences, reference) required although nothing renders?
  [Consistency, Spec §SC-R02F12-006; plan Testing]

## Future D1/D2/D3 evidence

- [x] CHK013 Is the device-only item named (cut time of the largest solid) and deferred to after ImplementationLock-100?
  [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
