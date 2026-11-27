# Requirements Quality Checklist: R02-G22-03 procedural materials and hero renderer

**Purpose**: Unit tests for the requirements of feature 513 (scene mapping, painter's order, tiers, purity, frame
checks, palette, fallback, accessibility, registration, adapter)
**Created**: 2026-11-27
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-27, following feature 503's checklist; every item
but CHK017 passed at first reading; it was fixed in the spec the same day.

## Scene and mapping

- [x] CHK001 Is the board-to-space fit rule stated exactly and independent of player actions? [Clarity, Spec
  §Clarifications Q1]
- [x] CHK002 Are every drawn element, its size relative to the cell and its colour listed? [Completeness, Spec
  §Clarifications Q1, Q3]
- [x] CHK003 Is the painter's order with depth testing off stated? [Clarity, Spec §Clarifications Q1; research R4]
- [x] CHK004 Is the shown pulse's range, default and reset behaviour defined, and kept out of the digest? [Clarity, Spec
  §Clarifications Q1, Q5]
- [x] CHK005 Is the camera with its fitted box and aspect range defined? [Measurability, Spec §Clarifications Q1]

## Purity and tiers

- [x] CHK006 Is it stated that drawn segments and terminal states are the kernel's values up to the shown pulse?
  [Consistency, Spec §FR-R02G2203-003]
- [x] CHK007 Are the tiers' differences enumerated and the invariant elements listed? [Completeness, Spec
  §Clarifications Q2]
- [x] CHK008 Is the equality of the Core's tier names and the presenter's levels required? [Consistency, Spec
  §Clarifications Q2]

## Frame checks and palette

- [x] CHK009 Are the checked points, thresholds and render size stated? [Measurability, Spec §Clarifications Q3]
- [x] CHK010 Is the palette complete and required to match between CPU and shader? [Consistency, Spec §Clarifications
  Q3, Q5]
- [x] CHK011 Are the fallback's check rules (flat colour within 0.1) stated? [Edge Case, Spec §Clarifications Q3]

## Failure, fallback and accessibility

- [x] CHK012 Is each failure kind's mark defined? [Completeness, Spec §Clarifications Q4]
- [x] CHK013 Is the shader-failure fallback (level-2 unlit, reason kept) defined? [Edge Case, Spec §Clarifications Q4]
- [x] CHK014 Is every element's non-colour twin stated? [Coverage, Spec §Edge Cases]
- [x] CHK015 Are Reduce Motion and Reduce Flashing behaviours defined? [Coverage, Spec §Clarifications Q4]

## Registration and adapter

- [x] CHK016 Are the registration fields (tiers, palette, manifest, content facts) and the candidate state defined?
  [Completeness, Spec §Clarifications Q5]
- [x] CHK017 Does FR-R02G2203-009 describe how the kernel's source scans stay unchanged in terms that match the
  scans' actual reach? [Consistency, Spec §FR-R02G2203-009] (fixed 2026-11-27)
- [x] CHK018 Are the adapter's controls, declared ranges and its own refusal for the shown pulse defined? [Clarity, Spec
  §Clarifications Q5]
- [x] CHK019 Are the vertex streams' material encoding and the shader limits stated? [Clarity, Spec §Clarifications Q5]

## Scope

- [x] CHK020 Are device-only items recorded as `{device}` and excluded items listed? [Completeness, Spec §Canonical
  overrides; Excluded scope]

## Notes

- `/speckit-implement` reads these markers and does not change them.
