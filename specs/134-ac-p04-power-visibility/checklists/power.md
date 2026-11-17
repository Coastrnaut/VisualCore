# Power Requirements Quality Checklist: Ambient Clock — Phase 04

**Purpose**: Unit tests for the requirements of A18-P04 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-16
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-16 (depth standard, audience reviewer). One item failed and was corrected
before this record (CHK009).

## Completeness

- [x] CHK001 Are the night modes, the schedule's boundary rules (wrap, empty window) and the dim range specified? [Clarification Q2, Spec §Edge Cases] — yes.
- [x] CHK002 Are the drift's amplitude, periods, rate bound and reduced-motion rule specified in numbers? [Clarification Q3, Spec §FR-A18-405] — yes (8 points, 600 s and 840 s, 6 points per minute).
- [x] CHK003 Are the idle-dim interval, factor and restore rule specified? [Spec §FR-A18-406, Clarification Q3] — yes.

## Architecture ownership

- [x] CHK004 Is the frame cap's placement in VisualCoreExperienceHost additive, with the default unchanged for every other experience and the floor kept? [Clarification Q1, Spec §FR-A18-404] — yes.
- [x] CHK005 Is the idle-timer use confined to one named file and made testable through a port? [Clarification Q4, Spec §FR-A18-407] — yes.

## iOS lifecycle

- [x] CHK006 Are the visibility events that set and release keep-awake listed (setup, became active, resign active, background, teardown, setting off)? [Clarification Q4] — yes.
- [x] CHK007 Is the resume regression fixture described with inputs and the expected text before any frame? [Clarification Q5, Spec §FR-A18-408] — yes.

## Consistency

- [x] CHK008 Do the spec, data model and contract agree on the drift rate bound? [Spec §FR-A18-405, US3, contracts/power.md] — yes (6 points per minute after the clarification).

## Privacy and release constraints

- [x] CHK009 Is the disclosure of keep-awake on the privacy page assigned to a phase? [Gap] — failed (nothing said where it is stated); the Assumptions now assign the privacy page to A18-P06 with the one named file.
- [x] CHK010 Are the brightness prohibition and the no-default keep-awake stated as negative requirements? [Spec §Negative Requirements] — yes.

## Testability and performance

- [x] CHK011 Is every success criterion runnable under 10 seconds with fixed clocks (drift over a sampled day, not real time)? [SC-A18-401–405] — yes.
- [x] CHK012 Is the frame cap's expected value measurable for both the clock and another experience? [SC-A18-403, contracts/power.md] — yes.
- [x] CHK013 Is the migration from schema 2 specified with defaults and registered examples? [Clarification Q5] — yes.

## Notes

- `/speckit-implement` reads these markers and does not change them.
