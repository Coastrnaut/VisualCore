# Acquisition Requirements Quality Checklist: Oscilloscope Studio — Phase 01

**Purpose**: Unit tests for the requirements of A08-P01 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); one item failed and was corrected
before this record (CHK011).

## Completeness

- [x] CHK001 Are all three manual gates (triggered waveform with gain and timebase; sine → periods and spectrum bin; context in the host) required? [Spec overrides, FR-A08-103, 110, 121, SC-A08-101, 102] — yes.
- [x] CHK002 Are the gaps built here (G-DEMOWAVES, G-STEREO test-signal and file paths, G-TRIGGER) and those deferred (G-DECIMATION, G-TRACESTRIP, microphone stereo) named? [Spec overrides, Assumptions, research D6] — yes.
- [x] CHK003 Is every source (test signal, file, microphone) specified with its channel count? [FR-A08-102, Clarifications Q2] — yes.

## Clarity

- [x] CHK004 Is the trigger rule (level, slope, hysteresis value, search range, auto vs normal) defined precisely enough to test? [Clarifications Q3, data-model] — yes.
- [x] CHK005 Are the timebase and gain choices, the division count and the window cap quantified? [Clarifications Q4] — yes.
- [x] CHK006 Are square and sweep waveforms defined (levels; logarithmic law, range and duration)? [Story 2, research D3] — yes.

## Architecture ownership

- [x] CHK007 Is the split between VisualCore (signals, buffer, trigger, two-channel sources) and the experience (state, choices, UI) explicit, and are A06/A07 types left unchanged? [Plan Constitution Check II, Clarifications Q1] — yes.
- [x] CHK008 Are module, target, product and adapter type names consistent and free of collisions? [Plan Project Structure, contracts/api.md] — yes (adapter `ScopeCore`).
- [x] CHK009 Is drawing restricted to the host's existing renderer with no context of the experience's own? [FR-A08-121] — yes.

## iOS lifecycle

- [x] CHK010 Are suspend, resume, interruptions and the rule that no window spans a gap specified? [Edge Cases, Plan Lifecycle] — yes.

## Privacy and release constraints

- [x] CHK011 Are the file-choosing flow and the undecodable or moved file case specified? [Edge Cases] — failed at first (the spec named "a file they opened" without the picker or the failure case); corrected with the edge case "A file cannot be decoded or was moved" (system file picker, previous source kept).
- [x] CHK012 Are no recording, no storage, no monitoring, the shared microphone permission and dBFS-relative levels stated? [FR-A08-130, Story 2 AC4] — yes.
- [x] CHK013 Is the candidate (not available) registration specified? [FR-A08-120, Clarifications Q5] — yes.

## Testability and performance

- [x] CHK014 Is every success criterion tied to a runnable check with numeric tolerances? [SC-A08-101–105, quickstart] — yes.
- [x] CHK015 Are determinism requirements stated for signals, trigger and windows? [FR-A08-101, 104] — yes.
- [x] CHK016 Are resource bounds (window ≤ 4,096, buffer 16,384 frames, segments ≤ samples) stated without wall-clock assertions? [FR-A08-121, Clarifications Q4, Plan Technical Context] — yes.

## Notes

- 16 items evaluated on 2026-11-14; CHK011 corrected in spec.md before marking. `/speckit-implement` reads these
  markers and does not change them.
