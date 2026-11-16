# Release Requirements Quality Checklist: Simulation Lab — Phase 06

**Purpose**: Unit tests for the requirements of A16-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK009).

## Completeness

- [x] CHK001 Are the refused source uses listed exactly? [Clarifications Q3, FR-A16-601] — yes.
- [x] CHK002 Are the stored items, their places and deletion required in the privacy document? [FR-A16-603, research D1] — yes.
- [x] CHK003 Is a license inventory required for every bundled preset, palette and shader? [FR-A16-603, Clarifications Q5] — yes.
- [x] CHK004 Are the release checklist statuses defined? [Clarifications Q1, FR-A16-620] — yes.

## Privacy

- [x] CHK005 Is it stated how a capture can leave the device (only through the share sheet the person opens)? [User Story 1] — yes.
- [x] CHK006 Is the app's privacy answer required unchanged? [FR-A16-602] — yes.

## Data and recovery

- [x] CHK007 Are the sample files and their expected answers enumerated? [Clarifications Q5, FR-A16-611] — yes.
- [x] CHK008 Is the absence of older schemas stated rather than left implicit? [Clarifications Q5] — yes.

## Testability

- [x] CHK009 Are the interface journeys bounded so that no system prompt or share sheet appears? [FR-A16-630] — failed (only the journeys were named); FR-A16-630 now forbids prompts and the share sheet and bounds each to 60 s.
- [x] CHK010 Are the claims required to name existing tests? [FR-A16-621] — yes.

## Release constraints

- [x] CHK011 Are owner-only steps and device items kept out of this phase with their statuses? [Edge Cases, Clarifications Q1] — yes.
- [x] CHK012 Are forbidden claim words listed, with the justified exception ("exact")? [Clarifications Q2] — yes.
- [x] CHK013 Is the method-and-limits label required in every experiment? [FR-A16-622] — yes.

## Notes

`/speckit-implement` reads this checklist and does not change its markers.
