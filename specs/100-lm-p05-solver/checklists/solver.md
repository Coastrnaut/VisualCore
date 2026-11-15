# Solver Requirements Quality Checklist: Light Maze — Phase 05

**Purpose**: Unit tests for the requirements of A13-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-15
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-15 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK007).

## Completeness

- [x] CHK001 Are all three Phase 05 gates (glow cues kept, drawn beam matches the tracer, host owns the context) required with measurable outcomes? [Spec §Canonical overrides, FR-A13-520, SC-A13-504] — yes.
- [x] CHK002 Is the search's space, order and minimality fully stated? [FR-A13-501, Clarifications Q1, research D1–D2] — yes.
- [x] CHK003 Are all five QA checks named with their order? [FR-A13-511, Clarifications Q4, data model] — yes.
- [x] CHK004 Are damaged-level fixtures defined for every QA check? [Clarifications Q4] — yes.

## Architecture ownership

- [x] CHK005 Is the search kept app-local, pure and out of the run-time experience? [Clarifications Q3, plan] — yes.
- [x] CHK006 Is no VisualCore change required and the gap's owner recorded? [Plan Constitution II, contract G-SOLVER] — yes.

## Clarity and consistency

- [x] CHK007 Do the refusal codes agree between the spec and the contract (`invalid-board`, `too-many-tiles`)? [FR-A13-502, contracts/solver.md] — failed (the contract had enum cases without their codes); contract corrected with `code`.
- [x] CHK008 Is "turn" defined so that fewest turns and recorded turns are comparable? [Clarifications Q1, contract] — yes.
- [x] CHK009 Is the limit quantified (16 tiles, 65,536 sets) with its edge cases (16 searched, 17 refused)? [FR-A13-502, Edge Cases] — yes.

## iOS lifecycle and recovery

- [x] CHK010 Is it stated that nothing changes at run time (no lifecycle, no persisted data, no migration)? [Plan Lifecycle, Migration] — yes.
- [x] CHK011 Is rollback stated? [Plan Rollback] — yes.

## Accessibility and privacy

- [x] CHK012 Is it stated that no control, word or drawing changes for people? [Negative Requirements, Clarifications Q3] — yes.
- [x] CHK013 Are no data, accounts or network stated? [Negative Requirements] — yes.

## Testability and performance

- [x] CHK014 Can every success criterion be checked without a device? [SC-A13-501–505, quickstart] — yes.
- [x] CHK015 Is the search's cost bounded by arithmetic rather than a wall-clock assertion? [Plan Technical Context, research D3] — yes.
- [x] CHK016 Is the committed QA table's regeneration and comparison stated? [Plan, research D4, quickstart] — yes.

## Notes

- 16 items evaluated on 2026-11-15; one corrected. `/speckit-implement` reads these markers and does not change them.
