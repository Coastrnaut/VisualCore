# Release Requirements Quality Checklist: Audio Odyssey — Phase 06

**Purpose**: Unit tests for the requirements of A07-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK003).

## Completeness

- [x] CHK001 Are all deliverables of the manual's Phase 06 (permission strings, accessibility, asset/credit review, data migration, device tests, crash recovery, build/archive instructions) mapped to requirements? [Spec §Traceability] — yes.
- [x] CHK002 Are the three gates (checklist and inventory; automated and device tests with results; no unsupported promises) required? [Spec overrides, FR-A07-620–632] — yes.
- [x] CHK003 Does every user-facing statement name this experience rather than the template it was adapted from? [Spec §US1 AC2] — failed at first (one acceptance scenario still said "Music Lab" across a line break); corrected to "Audio Odyssey".

## Privacy

- [x] CHK004 Is it stated that only the existing microphone string is used and no new permission is added? [Spec §FR-A07-601, 640] — yes.
- [x] CHK005 Is the stored data (journey presets only, in the experience's folder) and the absence of stored or sent audio specified? [Spec §FR-A07-604] — yes.

## Data migration and recovery

- [x] CHK006 Are the five preset fixtures and their expected outcomes specified, including byte-identical refused files? [Clarifications Q3, FR-A07-610] — yes.
- [x] CHK007 Is the recovery after a forced draw failure specified with reopen behaviour? [Spec §FR-A07-611] — yes.

## Release constraints and copy

- [x] CHK008 Is the copy allow list limited to real features with every measured-claim pattern still refused? [Clarifications Q1] — yes.
- [x] CHK009 Are comfort and motion-sickness claims excluded from copy? [Spec §Negative Requirements] — yes.
- [x] CHK010 Are owner-only steps recorded as blocked with exact steps, not performed? [Spec overrides, FR-A07-640] — yes.

## Testability and performance

- [x] CHK011 Are the interface chunk's journeys and time limit specified? [Spec §US4, Clarifications Q2] — yes.
- [x] CHK012 Are device-only measurements (frame time, segment generation, thermal, comfort review, accessibility audits) planned with device and pass criterion and not claimed? [Spec §FR-A07-622, 623] — yes.
- [x] CHK013 Is every success criterion tied to a runnable check? [SC-A07-601–606, quickstart] — yes.

## Architecture ownership and lifecycle

- [x] CHK014 Is a VisualCore change excluded unless proven needed? [Spec §FR-A07-640] — yes.
- [x] CHK015 Are the snapshot schema 1 and 2 migration examples part of the data-migration evidence? [Clarifications Q3] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK003 corrected in spec.md before marking. `/speckit-implement` reads these markers
  and does not change them.
