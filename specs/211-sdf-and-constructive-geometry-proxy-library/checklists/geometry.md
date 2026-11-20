# Requirements Quality Checklist: R02-F11 SDF and constructive geometry proxies

**Purpose**: Unit tests for the requirements of feature 211 (player impact, deterministic invariants, empty and error
states, source licence, code-only graphics, iPad/iPhone layout, simulator proof, future D1/D2/D3 evidence)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Player impact

- [x] CHK001 Is it required that every decision (hit, inside, contact) comes from the same description that is drawn, so
  what the player sees and what the game decides agree? [Clarity, Spec §FR-R02F11-008]
- [x] CHK002 Is the guarantee of the conservative march (never skips a surface) stated with a measurable proof (thin
  shell, 100 rays)? [Measurability, Spec §SC-R02F11-002]

## Deterministic invariants

- [x] CHK003 Are distance, normal, march and volume results required to be identical across runs, with a digest for the
  volume? [Completeness, Spec §FR-R02F11-005, SC-R02F11-004]
- [x] CHK004 Are the march constants (ω, tolerance, step budget, maximum distance) fixed numbers? [Clarity, Spec
  §Clarifications Q3]
- [x] CHK005 Is the distance-bound property (|∇d| ≤ 1) stated and are the transforms that would break it excluded?
  [Consistency, Spec §Clarifications Q2, Edge Cases]

## Empty and error states

- [x] CHK006 Are invalid sizes, directions, rotations, smoothing radii and limits each given a reason code? [Coverage,
  Spec §FR-R02F11-006]
- [x] CHK007 Are underflow and overflow addressed with a range (|p| ≤ 1e6, sizes ≥ 1e-6) rather than "stay finite"?
  [Gap → Spec §Edge Cases] — corrected.
- [x] CHK008 Are a ray starting inside, a point on the surface and an exhausted budget given defined outcomes? [Edge
  Case, Spec §Edge Cases, FR-R02F11-004]
- [x] CHK009 Are an unknown newer stored form and malformed data refused rather than trapped? [Edge Case, Spec
  §FR-R02F11-007]

## Source licence and code-only graphics

- [x] CHK010 Are the formula sources required to be cited with licences? [Completeness, Spec §FR-R02F11-009; research
  R2, R4]
- [x] CHK011 Is the drawing required to be generated shader code on the existing renderer, with no texture-based field
  or asset? [Consistency, Spec §Negative Requirements]

## iPad/iPhone layout

- [x] CHK012 Is it stated whether layout, Dynamic Type and VoiceOver apply to this library? [Gap → Spec §Negative
  Requirements] — corrected: no interface here; the consuming experiences carry them.

## Simulator proof

- [x] CHK013 Are shader–CPU tolerances, the silhouette exclusion and both runtimes named? [Measurability, Spec
  §SC-R02F11-003, Clarifications Q5]
- [x] CHK014 Is GPU memory returning to baseline after the parity draws required? [Gap → Spec §SC-R02F11-003] —
  corrected.

## Future D1/D2/D3 evidence

- [x] CHK015 Is the device-only item named (march cost of the largest shape on D1–D3) and deferred to after
  ImplementationLock-100? [Completeness, Spec §Canonical overrides]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
