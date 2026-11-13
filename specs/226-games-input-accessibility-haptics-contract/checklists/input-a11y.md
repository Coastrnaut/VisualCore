# Requirements Quality Checklist: R02-F26 — games input, accessibility and haptics

**Purpose**: Unit tests for the requirements of R02-F26
**Created**: 2026-11-13
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement text adequate. Evaluated 2026-11-13 by the lead under the
owner's standing delegation; failed items were corrected in the specification first and the correction is named.

## Completeness
- [x] CHK001 Is each purpose of the source (gesture arbitration, VoiceOver mirrors, colour independence, Reduce Motion/Flashing) mapped to requirements? [Spec §FR-R02F26-001…050]
- [x] CHK002 Are haptics requirements present, including an off switch and its storage? [Spec §FR-R02F26-040…042]
- [x] CHK003 Is the non-gesture alternative for every gesture required and checkable? [Spec §FR-R02F26-010]
- [x] CHK004 Are the cancellation and background paths of touches specified? [Spec §FR-R02F26-003, Edge Cases]

## Clarity
- [x] CHK005 Are the announcement and haptic rate limits quantified? [Spec §FR-R02F26-020/040] — failed first; corrected: 0.5 s per announcement (merge to newest), 0.05 s per feedback (drop extras).
- [x] CHK006 Is the winner rule of the arbiter defined (priority, pointer count, first to leave possible)? [Clarifications, Plan R1]
- [x] CHK007 Is "colour independence" defined measurably (distinct non-colour sign per state)? [Spec §FR-R02F26-030]

## Consistency
- [x] CHK008 Is reuse of the existing Reduce Motion/Flashing contract consistent with UA-F04 and with section 13 "extend"? [Spec §FR-R02F26-050, Overrides]
- [x] CHK009 Do the module placements respect the dependency directions? [Clarifications]

## Acceptance criteria
- [x] CHK010 Does every success criterion carry counts and a planted-defect case where a check exists? [Spec §SC-R02F26-001…007]
- [x] CHK011 Is it stated that haptics cannot change the state digest, with a criterion? [Spec §FR-R02F26-041, SC-R02F26-005]

## Edge cases and recovery
- [x] CHK012 Are non-finite positions, excess pointers and bursts of changes addressed? [Spec §Edge Cases]
- [x] CHK013 Is the migration of stored preferences without the new switch defined? [Spec §FR-R02F26-042, Edge Cases]

## Accessibility, privacy, boundaries
- [x] CHK014 Are announcement texts required to be localizable rather than built from identifiers? [Spec §FR-R02F26-021] — failed first; corrected: texts come from a string catalog.
- [x] CHK015 Is it stated that no permission is asked and only one switch is stored? [Spec §FR-R02F26-060]
- [x] CHK016 Are the system accessibility audits explicitly moved to the device campaign? [Spec §FR-R02F26-061]
- [x] CHK017 Are device-only items (haptic feel and firing, manual VoiceOver) separated from simulator-verifiable plans? [Spec §Overrides, Assumptions]
- [x] CHK018 Is "public Apple APIs only" stated, with the APIs named in the plan? [Spec §FR-R02F26-060, Plan]

## Traceability
- [x] CHK019 Are the superseded source items listed with replacements? [Spec §Overrides]
- [x] CHK020 Is the impact on the sealed A01–A04 bounded to their declarations? [Spec §Assumptions]

## Notes
- `/speckit-implement` reads these markers and does not change them.
