# Requirements Quality Checklist: R02-G03-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 323 (scene mapping and fidelity of crossings, materials and
palette, quality tiers, CPU reference bounds, renderer purity and fallback, adapter controls and digest, registration as
candidate, device items)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Scene mapping

- [x] CHK001 Is the mapping from kernel units to world units stated with its scale? [Clarity, Spec §Clarifications Q1]
- [x] CHK002 Is it required, with a reason, that the drawn crossings equal the rules' crossings (polygon with rounded
  corners, not a free spline)? [Consistency, Spec §Clarifications Q1; research R1]
- [x] CHK003 Are handles, selection and gates described with their geometry and colours? [Completeness, Spec
  §Clarifications Q1]
- [x] CHK004 Is the camera defined (direction, tilt, fit and margin) for every stated aspect? [Clarity, Spec §Edge Cases;
  Q1]

## Materials and tiers

- [x] CHK005 Is the palette given with exact values and roles? [Clarity, Spec §Clarifications Q3]
- [x] CHK006 Are the caustic pulses defined (where, frequency, Reduce Motion behaviour)? [Completeness, Spec
  §Clarifications Q1, Q4]
- [x] CHK007 Does each tier list exactly what changes and what must stay identical? [Consistency, Spec §FR-R02G0303-004;
  Q2]

## Verification

- [x] CHK008 Are frame-check bounds stated in pixels and colour distances with the render size? [Measurability, Spec
  §Clarifications Q3; SC-R02G0303-001]
- [x] CHK009 Is renderer purity stated as a measurable check over seeded snapshots, tiers, times and failures?
  [Measurability, Spec §SC-R02G0303-002]
- [x] CHK010 Are bounds on generated geometry and uniforms stated for extreme ropes? [Edge Case, Spec §Edge Cases;
  SC-R02G0303-003]

## Adapter and registration

- [x] CHK011 Are every control's arguments and refusals, the digest and the snapshot schema defined? [Completeness, Spec
  §Clarifications Q5]
- [x] CHK012 Is the candidate's registration content (tiers, palette, content facts, availability) defined? [Completeness,
  Spec §Clarifications Q5; FR-R02G0303-008]
- [x] CHK013 Is the change to the app's unregistered-candidate example stated? [Consistency, Spec §Clarifications Q5]

## Fallback and device

- [x] CHK014 Is the shader-failure fallback defined with what is kept and logged? [Edge Case, Spec §Clarifications Q4]
- [x] CHK015 Are device-only measurements separated as {device} after ImplementationLock-100? [Scope, Spec
  §SC-R02G0303-006]

## Notes

- `/speckit-implement` reads these markers and does not change them.
