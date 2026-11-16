# Accessibility and offline content checklist: Interactive Anatomy — Phase 04

**Purpose**: unit tests for the requirements of gestures, labels, signs, announcements, the content pack and
provenance (feature 127).
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement's quality sufficient; it does not mean the work is done.
Evaluated by the lead under the owner's standing delegation on 2026-11-16. Failing items were corrected in the
artifacts before they were ticked.

## Requirement Completeness

- [x] CHK001 Are the drag and pinch thresholds, step sizes, priorities and the per-event cap quantified? [Spec §FR-A17-401, Q1]
- [x] CHK002 Are the label layout's inputs, order, culling, overlap rule and budget all specified? [Spec §FR-A17-402, Q2]
- [x] CHK003 Are the three signs, their words and the check they must pass named? [Spec §FR-A17-404, Q3]
- [x] CHK004 Are the announcement texts, rate and the always-last rule specified, and when they are spoken? [Spec §FR-A17-405, Q3; corrected: only while VoiceOver runs]
- [x] CHK005 Are the pack's kind, schema, migration, cap, digest and refusals specified? [Spec §FR-A17-407, Q4]
- [x] CHK006 Are the provenance fields and the failing check specified? [Spec §FR-A17-408, Q5]

## Requirement Clarity and Consistency

- [x] CHK007 Is "not colour alone" made measurable by VisualCore's sign check? [Spec §FR-A17-404, SC-A17-403]
- [x] CHK008 Do the gesture steps and limits agree with the button steps of A17-P02? [Spec §FR-A17-401]
- [x] CHK009 Do labels follow the solid set of A17-P03, so hidden and ghosted parts carry none? [Spec §Story 2, Q2]
- [x] CHK010 Is the A14/A15 boundary of the promotion stated (unchanged)? [Spec §FR-A17-403, research D1]

## Scenario and Edge Case Coverage

- [x] CHK011 Are tap-versus-drag, pinch-with-drag, crowded labels, canvas edges and a tiny canvas covered? [Spec §Edge Cases; corrected: the tiny canvas was added]
- [x] CHK012 Are damaged, oversized, newer and older packs covered? [Spec §Story 4]

## Architecture, Privacy and Release

- [x] CHK013 Is the label drawing kept in the host's overlay, with no graphics code in the experience? [Spec §Traceability; plan §Lifecycle]
- [x] CHK014 Is "no network" made checkable by a source scan? [Spec §FR-A17-407, Q5]
- [x] CHK015 Is the VisualCore addition's documentation, API baseline and reference regression timing stated? [Spec §FR-A17-403; plan II-a]
- [x] CHK016 Are test limits and the runtime stated, and is the audit deferred to the device campaign? [Spec §SC-A17-405, Negative Requirements]

## Notes

- `/speckit-implement` reads this checklist's state; it does not change the markers.
