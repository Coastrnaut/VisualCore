# Release Requirements Checklist: Digital Zen Garden — Phase 06

**Purpose**: Unit tests for the Phase 06 requirements (completeness, privacy, ownership, lifecycle, testability,
performance and release constraints)
**Created**: 2026-11-17
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer (the lead, under the owner's standing delegation) judged the requirement's quality
satisfied; it does not mean the work is done.

## Requirement Completeness

- [x] CHK001 Are all stored data kinds (snapshot, named gardens, index, calm switches, temporary still) listed for the privacy page? [Completeness, Spec §FR-A20-601]
- [x] CHK002 Is the only permission (add-only Photos) and the moment it is asked specified? [Completeness, Spec §FR-A20-601]
- [x] CHK003 Are the release documents and the shared known-limitations entry required? [Completeness, Spec §FR-A20-606] — corrected: the known-limitations A20 section was only in the plan and is now in FR-A20-606
- [x] CHK004 Is the source scan's refused API list enumerated? [Completeness, Spec §Clarifications Q3]

## Requirement Clarity

- [x] CHK005 Are the refused copy words listed exactly, with the whole-word, case-insensitive rule? [Clarity, Spec §Clarifications Q2]
- [x] CHK006 Is every sample file named with its expected outcome (opens, refused, read-only, unreadable code)? [Clarity, Spec §Clarifications Q4]
- [x] CHK007 Is the injected drawing failure defined as one-shot with a named error? [Clarity, Spec §Clarifications Q4]

## Requirement Consistency

- [x] CHK008 Do the refused words agree with what the experience truly does? [Consistency, Spec §Clarifications Q2] — corrected: "lossless" was refused although the still is a PNG; it is no longer refused
- [x] CHK009 Is the shared denylist's `audio`/`music`/`smooth` reconciled with the optional tones? [Consistency, Spec §Edge Cases]
- [x] CHK010 Do the device rows of the checklist match the campaign rows ZG-D1 … ZG-D8? [Consistency, Spec §FR-A20-606]

## Scenario and Edge Case Coverage

- [x] CHK011 Are recovery requirements defined for a failed draw with saved gardens present? [Coverage, Recovery, Spec §US2]
- [x] CHK012 Are newer and damaged files of each stored kind covered, with no deletion? [Edge Case, Spec §Edge Cases]
- [x] CHK013 Is the declined Photos prompt addressed without a promise about Photos? [Edge Case, Spec §Edge Cases]

## Non-Functional and Release Constraints

- [x] CHK014 Are test duration limits stated (unit under 10 s, interface under 60 s)? [Measurability, Spec §SC-A20-604]
- [x] CHK015 Is every measurement deferred to the device campaign with no number claimed? [Release, Spec §Negative Requirements]
- [x] CHK016 Are signing, archive and upload kept as owner actions? [Release, Spec §Overrides]

## Notes

- Two requirements were corrected during this review (CHK003, CHK008). `/speckit-implement` reads these markers and
  does not change them.
