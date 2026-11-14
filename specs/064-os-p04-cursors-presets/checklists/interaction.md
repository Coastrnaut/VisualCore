# Interaction Requirements Quality Checklist: Oscilloscope Studio — Phase 04

**Purpose**: Unit tests for the requirements of A08-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK006).

## Completeness

- [x] CHK001 Are all three manual gates (freeze/capture, cursors and touch zoom; no clipping or false precision; context in the host) required? [Spec overrides, FR-A08-401–404] — yes.
- [x] CHK002 Is the meaning of "capture" pinned down, with what stays out (image export)? [Assumptions, research D1] — yes.
- [x] CHK003 Are presets' content, storage, built-ins and failure handling (damaged, newer, unwritable) specified? [FR-A08-410, Clarifications Q4, Edge Cases] — yes.

## Clarity

- [x] CHK004 Is the pinch-to-timebase mapping (one step per doubling, clamped, spectrum ignored) defined? [FR-A08-403, Clarifications Q2] — yes.
- [x] CHK005 Are the readout precision rules quantified for time, frequency and level? [FR-A08-404, Clarifications Q3] — yes.

## Consistency

- [x] CHK006 Do story 4's example readout and the precision rule agree? [Story 4 AC1, Clarifications Q3] — failed at first (the story showed "0.021 ms" while the rule switches to µs below 0.1 ms); corrected to "1 sample, 20.8 µs".
- [x] CHK007 Do the frozen-state behaviours (gain, timebase, source change, restore) agree between the story, edge cases and clarifications? [Story 2 AC3, Edge Cases, Clarifications Q1, Q5] — yes.

## Architecture ownership

- [x] CHK008 Is it stated that no VisualCore change is needed and which shared pieces are reused (pinch, storage, store pattern)? [Spec overrides, Plan Constitution Check II] — yes.

## iOS lifecycle and persistence

- [x] CHK009 Are the saved state (schema 3), its migration and the restore of a frozen state specified? [FR-A08-411, Clarifications Q1] — yes.
- [x] CHK010 Is it stated what is not saved (the held window) and why? [Clarifications Q1] — yes.

## Privacy and release constraints

- [x] CHK011 Is it required that presets hold settings only (no source, audio or measurement)? [FR-A08-430, research D4] — yes.
- [x] CHK012 Are accessible labels for every new control and spoken readouts required, with slider alternatives to dragging? [FR-A08-412, Assumptions] — yes.

## Testability and performance

- [x] CHK013 Is every success criterion tied to a runnable check with numbers? [SC-A08-401–405, quickstart] — yes.
- [x] CHK014 Are bounds on names, cursor ranges and copies of frozen data stated? [Edge Cases, data-model, Plan Technical Context] — yes.
- [x] CHK015 Are the fixtures for freeze with cursors, zoom steps and a preset named? [FR-A08-420] — yes.

## Notes

- 15 items evaluated on 2026-11-14; CHK006 corrected in spec.md before marking. `/speckit-implement` reads these
  markers and does not change them.
