# Requirements Quality Checklist: A06-P01 audio source and permission shell

**Purpose**: Unit tests for the requirements of feature 047 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md)

Ownership: `[x]` means the reviewer judged the requirement-quality criterion satisfied, not that code is done. Under the
owner's standing delegation the lead evaluated every item on 2026-11-14; evaluations are recorded inline.

## Completeness

- [x] CHK001 Are all three source kinds specified with their start conditions? [Spec §FR-A06-101–104] — yes.
- [x] CHK002 Is the behaviour for every permission state specified? [Spec §US2, FR-A06-104] — yes (four states).
- [x] CHK003 Is the effect on other apps' audio playback specified? [Gap] — FAILED at first; corrected: FR-A06-107 (mixes with others; demo/file silent).
- [x] CHK004 Are the decodable formats and the refusal path specified? [Spec §FR-A06-103, Clarifications Q4] — yes.

## Privacy

- [x] CHK005 Is it stated that audio is never stored or sent? [Spec §FR-A06-105, Negative Requirements] — yes.
- [x] CHK006 Is the usage string's content specified? [Spec §FR-A06-106] — yes.
- [x] CHK007 Is a path without any permission required? [Spec §US1, FR-A06-102] — yes (demo and file).

## Architecture Ownership

- [x] CHK008 Is the split between VisualCore products and the experience specified? [Spec overrides, Clarifications] — yes.
- [x] CHK009 Is the package location consistent with the package map? [Clarifications facts] — yes (corrected to ExperiencesCreative).

## iOS Lifecycle

- [x] CHK010 Are source start/stop and microphone release on leave and switch specified? [Spec §FR-A06-105, Edge Cases] — yes.
- [x] CHK011 Is permission re-checking on return specified? [Spec §Edge Cases] — yes.

## Testability and Performance

- [x] CHK012 Is the sine fixture quantified (frequencies, size, tolerance, dominance)? [Spec §SC-A06-101] — yes.
- [x] CHK013 Is the writer's no-wait/no-allocation property specified measurably? [Spec §FR-A06-110, SC-A06-103] — yes.
- [x] CHK014 Is the untestable live-microphone part assigned to the device campaign? [Spec §Assumptions] — yes.
- [x] CHK015 Is memory for long files bounded by requirement? [Spec §Edge Cases] — yes (chunked decoding).

## Release

- [x] CHK016 Is the short-test bound and the public-API baseline required? [Spec §SC-A06-106] — yes.

## Notes

- 16 items, 1 failed and corrected in the spec before continuing; `/speckit-implement` reads this state but does not
  change it.
