# Requirements Quality Checklist: A06-P04 presets and recovery

**Purpose**: Unit tests for the Phase 04 requirements (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md)

`[x]` means the reviewer judged the requirement text satisfactory. Evaluated by the lead under the owner's standing
delegation (Canonical override); evaluations follow each item. `/speckit-implement` reads these markers and does not
change them.

## Requirement Completeness

- [x] CHK001 Are all four system events and the reaction to each specified? [Completeness, Spec §FR-A06-401, 402; Clarifications] — yes.
- [x] CHK002 Are the status texts and recovery buttons defined for every condition? [Completeness, Spec §Clarifications 5] — yes.
- [x] CHK003 Are preset fields, file format, built-ins and operations (save, apply, rename, delete) specified? [Completeness, Spec §FR-A06-411–413, Clarifications 4] — yes.
- [x] CHK004 Is the denied-permission usability fixture defined over every feature (scenes, editor, presets)? [Completeness, Spec §User Story 3, FR-A06-414] — yes.

## Requirement Clarity

- [x] CHK005 Is "consistent state" after event sequences defined? [Clarity → fixed, Spec §SC-A06-402] — failed first; now a per-event table.
- [x] CHK006 Is route loss limited to a specific reason? [Clarity, Spec §Clarifications 2] — "old device unavailable" only.
- [x] CHK007 Are preset name rules quantified? [Clarity, Spec §Edge Cases] — 60 characters, "Untitled", unique suffixes.

## Requirement Consistency

- [x] CHK008 Is "no new state field" consistent with the apply action changing scene and mappings? [Consistency, Spec §Overrides, FR-A06-413] — yes; the action edits existing fields.
- [x] CHK009 Do the preset fields agree with the manual's MusicPreset with the palette deferred? [Consistency, Spec §Overrides] — palette in Phase 05, format 2.

## Acceptance Criteria Quality

- [x] CHK010 Are event-mapping outcomes measurable for malformed input? [Measurability, Spec §SC-A06-401] — malformed → no event.
- [x] CHK011 Is the library's handling of bad files measurable? [Measurability, Spec §SC-A06-403] — counted, byte-identical.

## Scenario & Edge Case Coverage

- [x] CHK012 Are interruptions during demo/file, in the background and in rapid succession covered? [Coverage, Spec §Edge Cases] — yes.
- [x] CHK013 Are storage refusals and limits covered? [Coverage → fixed, Spec §Edge Cases] — quota bound added.
- [x] CHK014 Are built-in presets protected from rename/delete? [Exception, Spec §User Story 2 AC4] — yes.

## Architecture Ownership & Lifecycle

- [x] CHK015 Is session recovery owned by VisualCore and presets by the experience? [Constitution II, Plan §Summary] — yes.
- [x] CHK016 Is the monitor's lifetime tied to the source running? [Plan §Lifecycle] — yes.
- [x] CHK017 Is "at most one engine" stated as a requirement? [Spec §FR-A06-403] — yes.

## Non-Functional: Privacy, Accessibility, Release

- [x] CHK018 Is it stated that presets contain no audio and nothing leaves the device? [Spec §FR-A06-420] — yes.
- [x] CHK019 Are labels/identifiers required for every new control? [Spec §FR-A06-415] — yes.
- [x] CHK020 Is device-only verification of real interruptions stated as an assumption? [Spec §Assumptions] — yes.
- [x] CHK021 Are test durations bounded? [Spec §SC-A06-405] — < 10 s.

## Notes

- Two items failed on first evaluation (CHK005, CHK013); the spec was corrected the same day.
