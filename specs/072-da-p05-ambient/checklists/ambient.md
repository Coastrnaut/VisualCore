# Ambient Requirements Quality Checklist: Digital Aquarium — Phase 05

**Purpose**: Unit tests for the requirements of A09-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); three items failed and were
corrected in the spec before this record (CHK005, CHK012, CHK017).

## Completeness

- [x] CHK001 Are both manual Phase 05 gates (persistent configurations with safe restore; bounded long run) required with acceptance scenarios? [Spec §US1, US3, FR-A09-501, 502, 530] — yes.
- [x] CHK002 Is the content of a saved aquarium enumerated, including what is not saved? [Clarifications Q1, FR-A09-501] — yes.
- [x] CHK003 Are all four ambient effects stated (particles, speed, dimming, selection by Low Power and Reduce Motion)? [Spec §FR-A09-510–512] — yes.
- [x] CHK004 Are the quality levels' budgets enumerated? [Spec §FR-A09-520] — yes.
- [x] CHK005 Are the refusals of a save (limit, storage quota) specified? [Spec §FR-A09-501] — failed (quota missing); corrected.

## Clarity and measurability

- [x] CHK006 Are the idle interval, fade and dim level quantified? [Spec §FR-A09-511] — yes (60 s, 2 s, 60 %).
- [x] CHK007 Is the ambient speed quantified? [Spec §FR-A09-510] — yes (0.6).
- [x] CHK008 Are the long-run bounds measurable within the short-test rule? [Spec §SC-A09-504, Clarifications Q5] — yes.
- [x] CHK009 Is "memory bounded" made measurable? [Spec §SC-A09-504] — yes (resource count after reopenings).

## Consistency

- [x] CHK010 Is it consistent that Low Power Mode and Reduce Motion never change the state while ambient mode does? [Spec §FR-A09-510, 512] — yes.
- [x] CHK011 Are quality levels and ambient combined by one rule? [Clarifications Q4] — yes (smaller budget).
- [x] CHK012 Are the edge cases consistent with the configuration format (no state migration for configurations)? [Spec §Edge Cases] — failed (said "migrated like a restored state"); corrected to "newer files counted".

## Edge cases and recovery

- [x] CHK013 Are empty and long names, duplicates, ambient while paused, touches during dimming and Low Power changes covered? [Spec §Edge Cases] — yes.
- [x] CHK014 Are damaged, foreign and newer files handled without deletion? [Spec §FR-A09-502] — yes.
- [x] CHK015 Is it stated that a refused save changes no file? [Spec §FR-A09-501] — yes (after the CHK005 correction).

## Architecture, lifecycle and privacy

- [x] CHK016 Does the phase keep files on the device and add no permission or network? [Spec §Assumptions, Negative Requirements] — yes.
- [x] CHK017 Is ambient mode perceivable without sight (description and announcements)? [Gap] — failed; corrected in FR-A09-512.
- [x] CHK018 Is the system screen brightness and idle timer excluded? [Spec §FR-A09-511, Negative Requirements] — yes.
- [x] CHK019 Is graphics-context ownership kept in the host? [Spec §Canonical overrides] — yes.

## Performance and release

- [x] CHK020 Is the declared tier count tied to the registration? [Spec §FR-A09-520, Canonical overrides] — yes.
- [x] CHK021 Are device measurements planned and explicitly deferred to after ImplementationLock-100? [Spec §FR-A09-540] — yes.
- [x] CHK022 Are measured performance claims excluded before the device campaign? [Spec §Negative Requirements] — yes.
- [x] CHK023 Are test durations bounded? [Spec §SC-A09-506] — yes.

## Notes

- `/speckit-implement` reads this checklist's state and does not change its markers.
