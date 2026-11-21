# Requirements Quality Checklist: R02-G03-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 326 (VoiceOver labels and announcements, refusal wording, haptic
mapping and rate limits, Reduce Flashing fades and their measure, Reduce Motion, Dynamic Type and contrast, the ambient
sound lifecycle, the presentation-only guarantee, device-only deferrals)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts
(noted per item).

## VoiceOver

- [x] CHK001 Is every native control that needs a label and value enumerated? [Completeness, Spec §FR-R02G0306-001]
- [x] CHK002 Are the announcement texts given exactly for moves, selections, undo, redo, wins, failures, level changes
  and each refusal code? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the announcement kind of each change stated? [Consistency, Spec §FR-R02G0306-002]
- [x] CHK004 Is the behaviour for a burst of quick moves and for a drag preview stated? [Edge Case, Spec §Edge Cases]
- [x] CHK005 Is the announcement for a degenerate projection (overlapping strands) stated? [Edge Case, Spec §Edge Cases,
  Clarifications Q1]
- [x] CHK006 Is panel-only completion of a level measurable with the accessibility operations? [Measurability, Spec
  §SC-R02G0306-001]
- [x] CHK007 Is the refusal wording shared by the announcement and the panel, so the two cannot disagree? [Consistency,
  Spec §Clarifications Q1]

## Haptics

- [x] CHK008 Is the mapping of each outcome to a haptic kind stated, including what plays none? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK009 Is the rule that an outcome is never dropped behind a selection stated? [Edge Case, Spec §Clarifications Q2]
- [x] CHK010 Is the person's haptics switch honoured, and VoiceOver off covered? [Coverage, Spec §Edge Cases]

## Comfort settings

- [x] CHK011 Are the eased elements (crossing marks, target match, win glow), their targets and both durations stated
  numerically? [Clarity, Spec §Clarifications Q3]
- [x] CHK012 Is it defined how a crossing mark that disappears after a move fades rather than vanishing? [Completeness,
  Plan §Research R4] (made explicit in research R4 during this review)
- [x] CHK013 Is the flash-rate measure (sampling rate, threshold, minimum fade, adversarial input) defined so it can be
  computed? [Measurability, Spec §SC-R02G0306-003]
- [x] CHK014 Is the caustic pulse rate stated against the 3-per-second limit, and Reduce Motion's effect measurable?
  [Measurability, Spec §FR-R02G0306-004, SC-R02G0306-003]
- [x] CHK015 Are Dynamic Type, Increase Contrast, wrapping and the iPad width stated? [Completeness, Spec §Clarifications
  Q5]

## Sound

- [x] CHK016 Is the recipe a stated pure function of the summary, the target and the stage? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK017 Are the conditions for playing and the rebuild moments stated? [Completeness, Spec §Clarifications Q4]
- [x] CHK018 Are an unavailable or interrupted audio session and the sound-off case covered? [Exception Flow, Spec §Edge
  Cases]

## Guarantees and scope

- [x] CHK019 Is it stated that nothing here changes the state, the digest or the snapshot? [Consistency, Spec
  §FR-R02G0306-004, 007; Assumptions]
- [x] CHK020 Are hardware observations deferred to D1–D3 after ImplementationLock-100? [Traceability, Spec §Canonical
  overrides; Assumptions]
- [x] CHK021 Are originality of text and synthesized sound stated? [Completeness, Spec §Assumptions]
- [x] CHK022 Are test duration limits and the regression stated? [Non-Functional, Spec §SC-R02G0306-005]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
