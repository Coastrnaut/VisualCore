# Validation Requirements Quality Checklist: Simulation Lab — Phase 05

**Purpose**: Unit tests for the requirements of A16-P05 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK004).

## Completeness and clarity

- [x] CHK001 Are the runs behind every reported difference defined (grid, speed, frames, step counts)? [Clarifications Q1] — yes.
- [x] CHK002 Are the tolerances stated per family? [Clarifications Q1, FR-A16-501] — yes (0 and 0.01).
- [x] CHK003 Are the stability-limit runs and their pass condition quantified? [Clarifications Q2, FR-A16-502] — yes.
- [x] CHK004 Is the behaviour defined when the committed report is out of date? [FR-A16-501] — failed (not stated); FR-A16-501 now fails the test with the regeneration sentence.
- [x] CHK005 Are the memory bound and its expected value stated? [Clarifications Q3, SC-A16-503] — yes.

## Privacy

- [x] CHK006 Is it stated that the phase adds no data, permission or network use? [Negative Requirements, plan V–VIII] — yes.

## Architecture ownership

- [x] CHK007 Is the measurement required to use the host's context and existing ledger types, with no VisualCore change? [plan Technical Context] — yes.

## iOS lifecycle

- [x] CHK008 Are a canvas size change and a context recreation distinguished, with what each does to the targets? [Clarifications Q5, FR-A16-504] — yes.

## Testability and performance

- [x] CHK009 Is timing excluded from assertions and from the report comparison? [Clarifications Q4–Q5] — yes.
- [x] CHK010 Is the per-frame bound stated with its cap? [FR-A16-503] — yes (128).
- [x] CHK011 Is the total test time bounded? [SC-A16-505, plan Performance] — yes.

## Release constraints

- [x] CHK012 Are device claims from simulator figures excluded, with the label stated? [Clarifications Q4, Negative Requirements] — yes.
- [x] CHK013 Is the runtime coverage stated, including what waits for X-A16 and the device campaign? [Canonical overrides] — yes.

## Notes

`/speckit-implement` reads this checklist and does not change its markers.
