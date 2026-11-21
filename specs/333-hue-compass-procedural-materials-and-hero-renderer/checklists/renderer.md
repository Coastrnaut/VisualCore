# Requirements Quality Checklist: R02-G04-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 333 (scene mapping of bearings, bands and fog, materials and
palette, non-colour cues, quality tiers, CPU reference bounds, renderer purity and the hidden target, fallback, adapter
controls and digest, registration as candidate, device items)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts.

## Scene mapping

- [x] CHK001 Is the mapping from the kernel's bearings and bands to angles and radii stated exactly? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK002 Are the needle, ticks, wheel, fog, probe, selection and target marks described with geometry and colour, and
  do their radii not overlap? [Completeness, Spec §Clarifications Q1]
- [x] CHK003 Is the camera defined (direction, tilt, fit and margin) for every stated aspect? [Clarity, Spec §Edge Cases;
  Q1]

## Materials, colour and non-colour cues

- [x] CHK004 Is the palette given with exact values and roles, including the band colour formula? [Clarity, Spec
  §Clarifications Q1, Q3]
- [x] CHK005 Is every band distinguishable without colour (glyph shape and count) and fog shown by brightness alone?
  [Coverage, Spec §Edge Cases; Q1]
- [x] CHK006 Does each tier list exactly what changes and what must stay identical? [Consistency, Spec §FR-R02G0403-004;
  Q2]

## Verification

- [x] CHK007 Are frame-check bounds stated in pixels and colour distances with the render size, at sample points that no
  other element covers? [Measurability, Spec §Clarifications Q3] — corrected: glyphs sit in the segment's outer edge,
  the wheel is unlit, and the colour is sampled at radius 0.85.
- [x] CHK008 Is renderer purity stated as a measurable check, including that no playing snapshot carries the target?
  [Measurability, Spec §SC-R02G0403-002; Q4]
- [x] CHK009 Are bounds on generated geometry and uniforms stated for extreme settings? [Edge Case, Spec §SC-R02G0403-003]

## Adapter and registration

- [x] CHK010 Are every control's arguments and refusals, the digest and the snapshot schema defined? [Completeness, Spec
  §Clarifications Q5]
- [x] CHK011 Is the candidate's registration content (tiers, palette, content facts, availability) defined?
  [Completeness, Spec §Clarifications Q5; FR-R02G0403-008]
- [x] CHK012 Is the change to the app's unregistered-candidate example stated? [Consistency, Spec §Clarifications Q5]

## Fallback, layout and device

- [x] CHK013 Is the shader-failure fallback defined with what is kept and logged? [Edge Case, Spec §Clarifications Q4]
- [x] CHK014 Are small views, rotation and the aspect range defined for iPhone and iPad layouts? [Coverage, Spec §Edge
  Cases]
- [x] CHK015 Are device-only measurements separated as {device} after ImplementationLock-100? [Scope, Spec
  §SC-R02G0403-006]

## Notes

- `/speckit-implement` reads these markers and does not change them.
