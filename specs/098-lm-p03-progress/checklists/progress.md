# Progress Requirements Quality Checklist: Light Maze — Phase 03

**Purpose**: Unit tests for the requirements of A13-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK007).

## Completeness

- [x] CHK001 Are both Phase 03 gates (deterministic propagation kept; every shipping level verified) required with measurable outcomes? [Spec §Canonical overrides, SC-A13-304] — yes.
- [x] CHK002 Are progression rules (level 1 open, solving opens the next, best counts) fully stated? [FR-A13-301, Clarifications Q4] — yes.
- [x] CHK003 Are undo and restart defined with exact restoration and their refusals? [FR-A13-310, Clarifications Q3] — yes.
- [x] CHK004 Is the progress document's schema and validation enumerated? [Clarifications Q2, contract] — yes.

## Architecture ownership

- [x] CHK005 Is the choice of keeping progress outside the engine state stated with its effect on replays? [Clarifications Q1, research D1] — yes.
- [x] CHK006 Is reuse of experience storage with atomic writes required (no new upstream piece)? [Plan Constitution II] — yes.

## Clarity and consistency

- [x] CHK007 Do the refusal codes agree between the spec and the contract? [Clarifications Q2, contract] — failed (the contract named `too-large`, the spec folded size into `damaged`); spec corrected.
- [x] CHK008 Is "best count" defined (turns kept at the solve, at least 1)? [Assumptions, Clarifications Q4] — yes.
- [x] CHK009 Is the moves cap quantified (64, oldest dropped)? [Clarifications Q3] — yes.

## iOS lifecycle and recovery

- [x] CHK010 Are interrupted writes, damaged and newer files and app data reset addressed? [US3, Edge Cases] — yes.
- [x] CHK011 Is the session state migration (1 → 2) required with a stored example? [FR-A13-321, plan Migration] — yes.

## Accessibility and privacy

- [x] CHK012 Are lock states, Undo and Restart required with labels, values and words? [FR-A13-302, 311, Clarifications Q3] — yes.
- [x] CHK013 Are device-only storage and no accounts, sync or network stated? [Negative Requirements] — yes.

## Testability and performance

- [x] CHK014 Can every success criterion be checked without a device? [SC-A13-301–305, quickstart] — yes.
- [x] CHK015 Is the replay proof of all 20 levels through actions required? [FR-A13-330, Clarifications Q5] — yes.
- [x] CHK016 Are saves bounded (one per change, ≤ 16 KB) without timing claims? [Plan Technical Context] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
