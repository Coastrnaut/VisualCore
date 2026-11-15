# Release Requirements Quality Checklist: Neon Arcade — Phase 06

**Purpose**: Unit tests for the requirements of A10-P06 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected in
the spec before this record (CHK011).

## Completeness

- [x] CHK001 Are all three manual Phase 06 gates required (checklist and inventory; results attached or pending rows; unsupported promises removed)? [Spec §Canonical overrides, FR-A10-620–623] — yes.
- [x] CHK002 Are privacy requirements complete (permission, scan, manifest, note with deletion)? [Spec §FR-A10-601–604] — yes.
- [x] CHK003 Are local data migration and crash recovery required for the high-score file and the saved states? [Spec §FR-A10-610–612] — yes.
- [x] CHK004 Are build and archive instructions referenced? [Spec §FR-A10-640, plan release.json requiredDocs] — yes (shared build-and-archive document).
- [x] CHK005 Is accessibility required with its proved facts and its pending audits? [Spec §FR-A10-623] — yes.

## Clarity and measurability

- [x] CHK006 Are the scanned uses enumerated, including recording uses? [Clarifications Q3] — yes.
- [x] CHK007 Are the refused skill and ranking words enumerated? [Clarifications Q2] — yes.
- [x] CHK008 Are the checklist statuses those the checker accepts? [Clarifications Q1] — yes.
- [x] CHK009 Are the sample high-score files and their expected outcomes enumerated? [Clarifications Q4] — yes.
- [x] CHK010 Are the interface journeys and the time limit stated? [Clarifications Q5, SC-A10-604] — yes.

## Consistency

- [x] CHK011 Do story 4's journeys match the interface tests the clarification names? [Spec §US4, Clarifications Q5] — failed at first (story 4 promised "game over with the best score" through the interface; the tests reach only the best-score text); the story now names the best-score text and says the game-over screen is proved by the A10-P04 session tests.
- [x] CHK012 Is the one-app rule (no per-app listing or pricing) consistent across stories and scope? [Spec §Canonical overrides, Out of Scope] — yes.
- [x] CHK013 Are device items consistently deferred to after ImplementationLock-100 and owner steps never done? [Spec §FR-A10-622, 640, 641] — yes.

## Edge cases

- [x] CHK014 Are a pending device row, an undone owner step, an untraced claim, a future high-score file and the silent switch covered? [Spec §Edge Cases] — yes.

## Privacy, performance and release

- [x] CHK015 Is "no measured claim" enforced by a check? [Spec §FR-A10-621] — yes (shared copy check).
- [x] CHK016 Are test durations bounded (10 s package, 60 s interface)? [Spec §SC-A10-604, 605] — yes.
- [x] CHK017 Does the phase add no permission or network? [Spec §FR-A10-601, 602] — yes.

## Notes

- 17 items evaluated on 2026-11-15; CHK011 corrected in spec.md before marking. `/speckit-implement` reads this
  checklist's state and does not change its markers.
