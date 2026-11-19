# Requirements Quality Checklist: R02-F07 emissive pass and mobile-safe bloom

**Purpose**: Unit tests for the requirements of feature 207 (completeness, compatibility, GPU lifecycle, testability,
performance, accessibility)
**Created**: 2026-11-19
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-19; failures were corrected in the artifacts.

## Requirement Completeness

- [x] CHK001 Are all five deliverables mapped to requirements? [Traceability, Spec §Traceability]
- [x] CHK002 Is every parameter given a range and default? [Completeness, Clarifications Q1]
- [x] CHK003 Are the three draws and their target sizes and formats stated? [Completeness, Clarifications Q2]
- [x] CHK004 Is the minimum blur-target size defined for very small outputs? [Gap → corrected: Spec §Edge Cases]

## Requirement Clarity

- [x] CHK005 Are the tone-mapping formulas written out? [Clarity, Clarifications Q1]
- [x] CHK006 Is the soft knee's shape defined? [Clarity, research R2]
- [x] CHK007 Is "reduced range" on standard precision quantified (glow limited to 1)? [Clarity, Clarifications Q3]

## Compatibility

- [x] CHK008 Is it stated that existing passes and graphs keep their output byte for byte? [Compatibility, Spec §FR-R02F07-007]
- [x] CHK009 Is the limiter change opt-in for graphs with the new pass only? [Compatibility, Clarifications Q4]
- [x] CHK010 Is the composite mode range change backward compatible? [Compatibility, Clarifications Q4]

## GPU Lifecycle

- [x] CHK011 Are pooled targets returned every frame and counted? [Lifecycle, Spec §SC-R02F07-003]
- [x] CHK012 Is behaviour after a context rebuild defined? [Lifecycle, Spec §Edge Cases]

## Testability

- [x] CHK013 Is a CPU reference required and are tolerances stated per precision path? [Measurability, Spec §SC-R02F07-001]
- [x] CHK014 Is the standard-precision path testable without a device (a forced switch)? [Testability, Clarifications Q3]

## Performance

- [x] CHK015 Is cost bounded by arithmetic (draw count, target pixel fraction) rather than a clock? [Performance, plan Technical Context]
- [x] CHK016 Are device timing measurements deferred to the campaign? [Performance, Spec §Canonical overrides]

## Accessibility

- [x] CHK017 Is the glow bounded when flashing is reduced, with a measurable rate? [Accessibility, Spec §SC-R02F07-005]
- [x] CHK018 Is brightness for the limiter measured in linear light for the new pass? [Accessibility, Spec §FR-R02F07-005]

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
