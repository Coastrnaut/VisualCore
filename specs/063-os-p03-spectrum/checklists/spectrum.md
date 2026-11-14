# Spectrum Requirements Quality Checklist: Oscilloscope Studio — Phase 03

**Purpose**: Unit tests for the requirements of A08-P03 (completeness, privacy, architecture ownership, iOS lifecycle,
testability, performance, release constraints)
**Created**: 2026-11-14
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

`[x]` means the reviewer judged the requirement's quality satisfied, not that work is done. Evaluated by the lead under
the owner's standing delegation on 2026-11-14 (depth standard, audience reviewer); no item failed (story 2's point
count was aligned with FR-A08-302 during clarification).

## Completeness

- [x] CHK001 Are all three manual gates (spectrum with dB-style annotation where valid; mono-XY fixture; context in the host) required? [Spec overrides, FR-A08-301–303, 310] — yes.
- [x] CHK002 Are the analysed samples (frame size, channel, filling rule, no gain, not triggered) specified? [Clarifications Q2, FR-A08-301] — yes.
- [x] CHK003 Are all reasons for a missing readout (no signal, clipping, filling) named with their wording? [FR-A08-303, contracts] — yes.

## Clarity

- [x] CHK004 Are the readout's rounding and tolerances (one bin; 1.5 dB) quantified and justified? [SC-A08-301, research D1] — yes.
- [x] CHK005 Is the frequency axis mapping (log from 20 Hz to Nyquist, strongest bin per column) defined? [Clarifications Q4] — yes.
- [x] CHK006 Are the level axis range and marks (0 to −100 dBFS, every 20 dB) and the decade marks defined? [FR-A08-303] — yes.

## Consistency

- [x] CHK007 Do the point-count statements of story 2, FR-A08-302 and SC-A08-303 agree? [Story 2 AC1, FR-A08-302, SC-A08-303] — yes (at most two points per column; one per non-empty column in practice).
- [x] CHK008 Is the display state change consistent with snapshots saved by A08-P02 (no migration needed)? [FR-A08-304, Clarifications Q1] — yes.

## Architecture ownership

- [x] CHK009 Is it stated that no VisualCore change is needed and what happens if one proves missing? [Spec overrides, Plan Constitution Check II-a] — yes.
- [x] CHK010 Are the labels' place (grid lines on the canvas, values in text and speech) defined given the renderer draws no text? [Clarifications Q5] — yes.

## Privacy, truthfulness and release constraints

- [x] CHK011 Is "dBFS, relative to full scale" required everywhere and SPL, volts, calibrated and certified wording forbidden? [FR-A08-320, contracts, Negative Requirements] — yes.
- [x] CHK012 Are accessibility needs (spoken readout, no colour-only cue, no flashing peak marks) covered? [FR-A08-305, Edge Cases] — yes.

## Testability and performance

- [x] CHK013 Is every success criterion tied to a runnable check with numbers? [SC-A08-301–305, quickstart] — yes.
- [x] CHK014 Is the per-frame cost bounded (one 4,096-point transform, ≤ 4,096 columns) without wall-clock assertions? [Plan Technical Context] — yes.
- [x] CHK015 Are non-48 kHz rates covered by the requirements (44.1 kHz marks and readouts)? [Edge Cases, SC-A08-301] — yes.

## Notes

- 15 items evaluated on 2026-11-14; none failed after clarification. `/speckit-implement` reads these markers and does
  not change them.
