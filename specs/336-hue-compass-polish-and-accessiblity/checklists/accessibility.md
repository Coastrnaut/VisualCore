# Requirements Quality Checklist: R02-G04-06 polish and accessibility

**Purpose**: Unit tests for the requirements of feature 336 (VoiceOver labels, summary and announcements, refusal
wording, haptic mapping and rate limits, Reduce Flashing fades and their measure, Reduce Motion, Dynamic Type and
contrast on iPhone and iPad, the ambient sound lifecycle, code-only feasibility, the presentation-only guarantee,
device-only deferrals)
**Created**: 2026-11-21
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it says nothing about the code.
Evaluated by the lead under the owner's standing delegation on 2026-11-21; failures were corrected in the artifacts
(noted per item).

## VoiceOver

- [x] CHK001 Is every native control that needs a label and value enumerated? [Completeness, Spec §FR-R02G0406-001]
- [x] CHK002 Are the announcement texts given exactly for turns, probes, band picks, undo, redo, wins, failures, level
  changes and each refusal code? [Clarity, Spec §Clarifications Q1]
- [x] CHK003 Is the announcement kind of each change stated? [Consistency, Spec §FR-R02G0406-002]
- [x] CHK004 Is the behaviour for a burst of quick turns and for a swipe preview stated? [Edge Case, Spec §Edge Cases]
- [x] CHK005 Is the empty state (no clue yet) worded for the summary element? [Edge Case, Spec §Clarifications Q5]
  (the summary text, with "No clues yet.", was made explicit in Q5 during this review)
- [x] CHK006 Is panel-only completion of a level measurable with the accessibility operations? [Measurability, Spec
  §SC-R02G0406-001]
- [x] CHK007 Is the refusal wording shared by the announcement and the panel, so the two cannot disagree? [Consistency,
  Spec §Clarifications Q1]
- [x] CHK008 Is every clue spoken as numbers, so play needs no colour vision? [Coverage, Spec §User Story 1]

## Haptics

- [x] CHK009 Is the mapping of each outcome to a haptic kind stated, including what plays none? [Clarity, Spec
  §Clarifications Q2]
- [x] CHK010 Is the rule that an outcome is never dropped behind a selection haptic stated, including the probe that
  spends the last unit? [Edge Case, Spec §Clarifications Q2]
- [x] CHK011 Is the person's haptics switch honoured, and VoiceOver off covered? [Coverage, Spec §Edge Cases]

## Comfort settings

- [x] CHK012 Are the eased elements (probe marks, selection mark, target ring, win glow), their targets and both
  durations stated numerically? [Clarity, Spec §Clarifications Q3]
- [x] CHK013 Is it defined how a mark that disappears (a retry or level change) fades rather than vanishing, with
  code-only geometry? [Completeness, Feasibility, Plan §Research R4]
- [x] CHK014 Is the flash-rate measure (sampling rate, threshold, minimum fade, adversarial input) defined so it can be
  computed? [Measurability, Spec §SC-R02G0406-003]
- [x] CHK015 Is the fog drift rate stated against the 3-per-second limit, and Reduce Motion's effect measurable?
  [Measurability, Spec §FR-R02G0406-004, SC-R02G0406-003]
- [x] CHK016 Is the win glow bounded by the existing Reduce Flashing cap? [Consistency, Plan §Research R5]
- [x] CHK017 Are Dynamic Type, Increase Contrast, wrapping, the smallest iPhone and the iPad width stated? [Completeness,
  Spec §Clarifications Q5, Edge Cases]

## Sound

- [x] CHK018 Is the recipe a stated pure function of the last clue and the stage, with the no-clue case? [Clarity, Spec
  §Clarifications Q4]
- [x] CHK019 Are the conditions for playing and the rebuild moments stated? [Completeness, Spec §Clarifications Q4]
- [x] CHK020 Are an unavailable or interrupted audio session and the sound-off case covered? [Exception Flow, Spec §Edge
  Cases]

## Guarantees and scope

- [x] CHK021 Is it stated that nothing here changes the state, the digest or the snapshot? [Consistency, Spec
  §FR-R02G0406-004, 007; Assumptions]
- [x] CHK022 Are hardware observations deferred to D1–D3 after ImplementationLock-100, with simulator proof named?
  [Traceability, Spec §Canonical overrides; Plan §Testing]
- [x] CHK023 Are originality of text and synthesized sound (source licence) stated? [Completeness, Spec §Assumptions]
- [x] CHK024 Are test duration limits and the regression stated? [Non-Functional, Spec §SC-R02G0406-005]

## Notes

- `/speckit-implement` reads checklist state but does not modify markers.
