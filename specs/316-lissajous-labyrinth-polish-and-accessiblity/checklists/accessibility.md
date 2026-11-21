# Requirements Quality Checklist: R02-G02-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 316 (VoiceOver labels and announcements, haptic mapping and rate
limits, Reduce Flashing fades and their measure, Reduce Motion, Dynamic Type and contrast, the ambient sound lifecycle,
the presentation-only guarantee, device-only deferrals)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts
(noted per item).

## VoiceOver

- [x] CHK001 Is every native control that needs a label and value enumerated? [Completeness, Spec §FR-R02G0206-001]
- [x] CHK002 Are the announcement texts given exactly for actions, undo, redo, wins, failures, level changes and each
  refusal code? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the announcement kind of each change stated? [Consistency, Spec §FR-R02G0206-002]
- [x] CHK004 Is the behaviour for a burst (an Apply of several values) and for a gesture preview stated? [Edge Case, Spec
  §Edge Cases] (added during this review)
- [x] CHK005 Is panel-only completion of a level measurable with the accessibility operations? [Measurability, Spec
  §SC-R02G0206-001]

## Haptics

- [x] CHK006 Is the mapping of each outcome to a haptic kind stated, including what plays none? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK007 Is the rule that an outcome is never dropped behind a selection stated? [Edge Case, Spec §Clarifications Q2]
- [x] CHK008 Is the person's haptics switch honoured, and VoiceOver off covered? [Coverage, Spec §Edge Cases]

## Comfort settings

- [x] CHK009 Are the eased elements, their targets and both durations stated numerically? [Clarity, Spec
  §Clarifications Q3]
- [x] CHK010 Is the flash-rate measure (sampling rate, threshold, minimum fade) defined so it can be computed? [Measurability,
  Spec §SC-R02G0206-003]
- [x] CHK011 Is Reduce Motion's effect stated and measurable? [Measurability, Spec §FR-R02G0206-004, SC-R02G0206-003]
- [x] CHK012 Are Dynamic Type, Increase Contrast, wrapping and the iPad width stated? [Completeness, Spec §Clarifications
  Q5]

## Sound

- [x] CHK013 Is the recipe a stated pure function of the dials and stage? [Clarity, Spec §Clarifications Q4]
- [x] CHK014 Are the conditions for playing and the rebuild moments stated? [Completeness, Spec §Clarifications Q4]
- [x] CHK015 Are an unavailable or interrupted audio session and the sound-off case covered? [Exception Flow, Spec §Edge
  Cases]

## Guarantees and scope

- [x] CHK016 Is it stated that nothing here changes the state, the digest or the snapshot? [Consistency, Spec
  §FR-R02G0206-004, 007; Assumptions]
- [x] CHK017 Are hardware observations deferred to D1–D3 after ImplementationLock-100? [Traceability, Spec §Canonical
  overrides; Assumptions]
- [x] CHK018 Are originality of text and synthesized sound stated? [Completeness, Spec §Assumptions]
- [x] CHK019 Are test duration limits and the regression stated? [Non-Functional, Spec §SC-R02G0206-005]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
